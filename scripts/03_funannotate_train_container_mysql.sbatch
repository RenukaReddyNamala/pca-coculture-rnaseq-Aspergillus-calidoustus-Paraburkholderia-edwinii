#!/bin/bash
#SBATCH --job-name=acal_funannotate_train
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --mem=120G
#SBATCH --time=7-00:00:00
#SBATCH -D /work/kd2lab/renuka/dual_rnaseq_KZJ39/anno_acal
#SBATCH -o /home/rn92553/log.acal_funannotate_train.%j.out
#SBATCH -e /home/rn92553/log.acal_funannotate_train.%j.err
#SBATCH --mail-type=ALL
#SBATCH --mail-user=rn92553@uga.edu

set -euxo pipefail
echo "[$(date)] SLURM env ok: host=${HOSTNAME}, jobid=${SLURM_JOB_ID}, pwd=$(pwd)"

# Step 3 (Train): funannotate v1.8.17 training using containerized MySQL/PASA
# Inputs:
#   Genome (softmasked):  $WORK_ANNO/masked/Aspergillus_221014.HiFiASM.assembly.softmasked.fa
#   RNA-seq evidence:     $WORK_ANNO/training/single.fq.gz
# Outputs:
#   Staged results:       $WORK_ANNO/funannotate_train_run1_<JOBID>/

PROJ_ROOT="/work/kd2lab/renuka/dual_rnaseq_KZJ39"
WORK_ANNO="${PROJ_ROOT}/anno_acal"
GENOME_SRC="${WORK_ANNO}/masked/Aspergillus_221014.HiFiASM.assembly.softmasked.fa"
READS_SRC="${WORK_ANNO}/training/single.fq.gz"
IMG_DIR="/apps/singularity-images/funannotate-1.8.17-MySQL-PASA"

LOCK="${WORK_ANNO}/.funannotate_train.lock"
if [[ -d "${LOCK}" ]]; then
  if [[ -f "${LOCK}/JOBID" ]]; then
    PREV=$(<"${LOCK}/JOBID")
    if ! squeue -h -j "${PREV}" >/dev/null 2>&1; then
      echo "Stale lock from job ${PREV}; reclaiming."
      rmdir "${LOCK}" 2>/dev/null || true
    fi
  fi
fi
if ! mkdir "${LOCK}" 2>/dev/null; then
  echo "Another funannotate train is running; exiting."
  exit 1
fi
echo "${SLURM_JOB_ID:-manual}" > "${LOCK}/JOBID"

SCRATCH="${SLURM_TMPDIR:-/scratch/${USER}/${SLURM_JOB_ID}}"
RUNDIR="${SCRATCH}/acal_train_${SLURM_JOB_ID}"
OUTDIR="${RUNDIR}/funannotate_train_run1"
mkdir -p "${RUNDIR}" "${OUTDIR}"
export TMPDIR="${SCRATCH}"

STAGE="${WORK_ANNO}/funannotate_train_run1_${SLURM_JOB_ID}"
mkdir -p "${STAGE}"

[[ -s "${GENOME_SRC}" ]] || { echo "Missing genome: ${GENOME_SRC}"; exit 2; }
[[ -s "${READS_SRC}"  ]] || { echo "Missing reads:  ${READS_SRC}";  exit 2; }
zcat -t "${READS_SRC}"

SCRATCH_FREE_G=$(df --output=avail -BG "${SCRATCH}" | tail -n1 | tr -dc '0-9')
echo "[$(date)] Scratch free: ${SCRATCH_FREE_G}G at ${SCRATCH}"
if [[ "${SCRATCH_FREE_G}" -lt 150 ]]; then
  echo "Node scratch has <150G free (${SCRATCH_FREE_G}G). Aborting."
  exit 3
fi

echo "[$(date)] Copying inputs to scratch..."
cp -v "${GENOME_SRC}" "${RUNDIR}/"
cp -v "${READS_SRC}"  "${RUNDIR}/"

echo "[$(date)] Copying helper scripts and PASA conf..."
cp -v "${IMG_DIR}/"*.sh "${RUNDIR}/"
cp -av "${IMG_DIR}/pasa_conf" "${RUNDIR}/"

cd "${RUNDIR}"

cleanup() {
  set +e
  echo "[$(date)] Trap cleanup: stopping MySQL instance if running..."
  ./3_cleanup.sh || true
  rm -f "${LOCK}/JOBID"
  rmdir "${LOCK}" || true
}
trap cleanup EXIT

apptainer instance stop funannotate-mysql 2>/dev/null || true

echo "[$(date)] Starting containerized MySQL (PASA)..."
./1_init.sh

echo "[$(date)] Waiting for MySQL to become ready..."
for i in {1..120}; do
  if apptainer exec instance://funannotate-mysql bash -lc "mysqladmin ping --silent"; then
    echo "MySQL is up after $((i*5))s"
    break
  fi
  sleep 5
done
apptainer exec instance://funannotate-mysql bash -lc "mysqladmin ping --silent"

echo "[$(date)] Creating PASA user/db..."
./2_create_user_and_db.sh
sleep 5
apptainer exec instance://funannotate-mysql bash -lc \
  "mysql -u pasa_write -p'pasa_write_pwd' -e 'SHOW DATABASES;'"

apptainer exec instance://funannotate-mysql bash -lc \
  "source activate /opt/funannotate && funannotate check --show-versions"

SPECIES="Aspergillus calidoustus"
STRANDED="no"
MAX_INTRON=3000

echo "[$(date)] Launching funannotate train..."
apptainer exec instance://funannotate-mysql bash -lc "
  set -eo pipefail
  source activate /opt/funannotate
  export _JAVA_OPTIONS='-Xmx48g'
  export JAVA_TOOL_OPTIONS='-Xmx48g'
  export TRINITY_TMPDIR='${TMPDIR}'
  {
    date
    uname -a
    echo 'CPUS=' ${SLURM_CPUS_PER_TASK}
    funannotate train \
      --input '${RUNDIR}/Aspergillus_221014.HiFiASM.assembly.softmasked.fa' \
      --out '${OUTDIR}' \
      --single '${RUNDIR}/single.fq.gz' \
      --stranded ${STRANDED} \
      --jaccard_clip \
      --pasa_db mysql \
      --aligners minimap2 \
      --pasa_min_pct_aligned 90 \
      --pasa_min_avg_per_id 95 \
      --pasa_num_bp_splice 3 \
      --max_intronlen ${MAX_INTRON} \
      --species '${SPECIES}' \
      --cpus ${SLURM_CPUS_PER_TASK}
  } |& tee '${OUTDIR}/train.inner.log'
"

echo "[$(date)] Staging results back to ${STAGE} ..."
rsync -av --info=progress2 "${OUTDIR}/" "${STAGE}/"

mkdir -p "${STAGE}/_run_meta"
cp -v "${RUNDIR}/"*.sh "${STAGE}/_run_meta/" || true
cp -rv "${RUNDIR}/pasa_conf" "${STAGE}/_run_meta/" || true

echo "[$(date)] Done. Results in: ${STAGE}"

