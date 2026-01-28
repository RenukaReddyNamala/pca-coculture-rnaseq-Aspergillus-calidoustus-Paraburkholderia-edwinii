#!/bin/bash
#SBATCH -J star_idx_comb
#SBATCH -A kd2lab
#SBATCH -p batch
#SBATCH -N 1
#SBATCH -n 24
#SBATCH -t 12:00:00
#SBATCH --mem=96G
#SBATCH -o logs/star_index_%j.out
#SBATCH -e logs/star_index_%j.err

set -euo pipefail
umask 0007

module purge
module load STAR

PROJECT="/work/kd2lab/renuka/dual_rnaseq_KZJ39"
mkdir -p "$PROJECT/logs"

# Combined references (fungus + bacterium)
GENOME_FA="/work/kd2lab/renuka/refs/combined/combined.fa"
GTF="/work/kd2lab/renuka/refs/combined/combined.gtf"

OUTDIR="/work/kd2lab/renuka/star_index_combined"
mkdir -p "$OUTDIR"

STAR --runThreadN 24 \
     --runMode genomeGenerate \
     --genomeDir "$OUTDIR" \
     --genomeFastaFiles "$GENOME_FA" \
     --sjdbGTFfile "$GTF" \
     --sjdbOverhang 99

echo "STAR combined genome index completed."
