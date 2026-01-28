#!/bin/bash
#SBATCH -J star_se
#SBATCH -A kd2lab
#SBATCH -p batch
#SBATCH -N 1
#SBATCH -n 24
#SBATCH -t 24:00:00
#SBATCH --mem=96G
#SBATCH -o logs/%x_%j.out
#SBATCH -e logs/%x_%j.err
#SBATCH --mail-user=rn92553@uga.edu
#SBATCH --mail-type=END,FAIL

set -euo pipefail
umask 0007

module purge
module load STAR
module load SAMtools

PROJECT="/work/kd2lab/renuka/dual_rnaseq_KZJ39"
mkdir -p "$PROJECT/logs"

IDX="/work/kd2lab/renuka/star_index_combined"
FASTQ_DIR="/work/kd2lab/renuka/RNA-Seq Reads"
OUT="/work/kd2lab/renuka/star_alignments_final"
mkdir -p "$OUT"

TMPROOT="$OUT/_tmp"
mkdir -p "$TMPROOT"
chmod 2770 "$TMPROOT" || true

shopt -s nullglob globstar
mapfile -d '' FASTQS < <(find "$FASTQ_DIR" -type f -name '*_R1_001*.fastq.gz' -not -name '._*' -print0)

if (( ${#FASTQS[@]} == 0 )); then
  echo "No FASTQs found under: $FASTQ_DIR" >&2
  exit 2
fi

ulimit -n 8192 || true

for fq in "${FASTQS[@]}"; do
  base="$(basename "$fq" .fastq.gz)"
  pref="$OUT/${base}."
  bam="${pref}Aligned.sortedByCoord.out.bam"

  # Skip if BAM already exists and non-zero
  if [[ -s "$bam" ]]; then
    echo ">>> Skipping (exists): $bam"
    continue
  fi

  short="$(echo "$base" | tr -cd '[:alnum:]_-' | cut -c1-20)"
  tmpd="$(mktemp -d "$TMPROOT/star_${short}_XXXXXX")" || { echo "mktemp failed"; exit 3; }

  echo ">>> Mapping: $fq"
  STAR --runThreadN 24 \
       --genomeDir "$IDX" \
       --readFilesIn "$fq" \
       --readFilesCommand zcat \
       --outSAMtype BAM SortedByCoordinate \
       --outFileNamePrefix "$pref" \
       --outTmpDir "$tmpd" \
       --limitBAMsortRAM 16000000000 \
       --outSAMstrandField intronMotif \
       --outFilterMultimapNmax 10 \
       --alignSJDBoverhangMin 1 \
       --outFilterMismatchNmax 10 \
       --alignIntronMax 10000 \
       --alignMatesGapMax 1000000

  samtools index -@ 8 "$bam"
  samtools flagstat -@ 8 "$bam" > "${pref}flagstat.txt"
  rm -rf "$tmpd" || true
done

echo "All done."
