#!/bin/bash
#SBATCH -J acal_annotate_rename
#SBATCH -p batch
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --cpus-per-task=24
#SBATCH --mem=32G
#SBATCH -t 02:00:00
#SBATCH -o /home/rn92553/log.acal_funannotate_annotate.%j.out
#SBATCH -e /home/rn92553/log.acal_funannotate_annotate.%j.err

set -eo pipefail

# Step 5 (Annotate): funannotate v1.8.17 annotate + rename IDs to KZJ39 prefix
# Input:  anno_acal/funannotate_predict_run1
# Output: annotated predict directory (in-place), with renamed gene IDs

PRED="/work/kd2lab/renuka/dual_rnaseq_KZJ39/anno_acal/funannotate_predict_run1"
IMG="/apps/singularity-images/funannotate-1.8.17-MySQL-PASA/funannotate-1.8.17-mysql-production.sif"

echo "[$(date)] Node: ${SLURMD_NODENAME:-$HOSTNAME}  ntasks=$SLURM_NTASKS  cpus=$SLURM_CPUS_PER_TASK"
echo "[$(date)] Running: funannotate annotate --rename KZJ39 ..."

apptainer exec "$IMG" bash -lc '
  set -eo pipefail
  set +u
  source activate /opt/funannotate
  set -u
  funannotate annotate \
    -i "'"$PRED"'" \
    --rename KZJ39 \
    --cpus "'"${SLURM_CPUS_PER_TASK:-24}"'"
'

echo "[$(date)] Done."
