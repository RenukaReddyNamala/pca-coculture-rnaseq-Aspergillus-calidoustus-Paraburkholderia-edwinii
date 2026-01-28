#!/bin/bash
#SBATCH -J acal_tab
#SBATCH -p batch
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --cpus-per-task=4
#SBATCH --mem=12G
#SBATCH -t 01:30:00
#SBATCH -o logs/%x_%j.out
#SBATCH -e logs/%x_%j.err

set -euo pipefail
echo "[$(date)] start on $(hostname)"

# Step 6: Build master annotation table (KZJ39) by merging GFF + FASTAs + funannotate annotations.txt

PRED="/work/kd2lab/renuka/dual_rnaseq_KZJ39/anno_acal/funannotate_predict_run1"

GFF="$PRED/predict_results/Aspergillus_calidoustus.gff3"
FAA="$PRED/predict_results/Aspergillus_calidoustus.KZJ39.proteins.faa"
MRNA="$PRED/annotate_results/Aspergillus_calidoustus.mrna-transcripts.fa"
CDS="$PRED/annotate_results/Aspergillus_calidoustus.cds-transcripts.fa"
ANN="$PRED/annotate_results/Aspergillus_calidoustus.annotations.txt"   # optional, if present

OUTDIR="$PRED/annotate_results"
OUT="$OUTDIR/Acal_master_KZJ39.tsv"

mkdir -p "$OUTDIR" logs

# Run exporter stored in repo
python3 scripts/export_funannotate_master_table.py "$GFF" "$FAA" "$MRNA" "$CDS" "$OUT" "$ANN"

echo "[$(date)] done -> $OUT"
