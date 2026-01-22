#!/bin/bash
#SBATCH --job-name=acal_funannotate_predict
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --mem=160G
#SBATCH --time=5-00:00:00
#SBATCH -o /home/rn92553/log.acal_funannotate_predict.%j.out
#SBATCH -e /home/rn92553/log.acal_funannotate_predict.%j.err
#SBATCH --mail-type=ALL
#SBATCH --mail-user=rn92553@uga.edu

set -euxo pipefail

# Step 4 (Predict): funannotate v1.8.17 gene prediction using RNA evidence + BUSCO
# Inputs:
#   Genome (softmasked):  anno_acal/masked/Aspergillus_221014.HiFiASM.assembly.softmasked.fa
#   Train output:         anno_acal/funannotate_train_run1_40944956/
# Outputs:
#   Predict output:       anno_acal/funannotate_predict_run1/

GENOME="/work/kd2lab/renuka/dual_rnaseq_KZJ39/anno_acal/masked/Aspergillus_221014.HiFiASM.assembly.softmasked.fa"
TRAIN="/work/kd2lab/renuka/dual_rnaseq_KZJ39/anno_acal/funannotate_train_run1_40944956"
OUTPRED="/work/kd2lab/renuka/dual_rnaseq_KZJ39/anno_acal/funannotate_predict_run1"

RNA_BAM="${TRAIN}/training/hisat2.coordSorted.bam"
PASA_GFF="${TRAIN}/training/funannotate_train.pasa.gff3"

[[ -s "$GENOME"   ]] || { echo "Missing genome: $GENOME"; exit 2; }
[[ -s "$RNA_BAM"  ]] || { echo "Missing RNA_BAM: $RNA_BAM"; exit 2; }
[[ -s "$PASA_GFF" ]] || { echo "Missing PASA_GFF: $PASA_GFF"; exit 2; }

IMG="/apps/singularity-images/funannotate-1.8.17-MySQL-PASA/funannotate-1.8.17-mysql-production.sif"

echo "[$(date)] Running funannotate predict..."
apptainer exec "$IMG" bash -lc '
  set -eo pipefail
  source activate /opt/funannotate
  funannotate check --show-versions

  funannotate predict \
    -i "'"$GENOME"'" \
    -o "'"$OUTPRED"'" \
    -s "Aspergillus calidoustus" \
    --rna_bam "'"$RNA_BAM"'" \
    --pasa_gff "'"$PASA_GFF"'" \
    --busco_db eurotiomycetes \
    --cpus '"${SLURM_CPUS_PER_TASK}"'
'
echo "[$(date)] Done."
