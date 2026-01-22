#!/bin/bash
#SBATCH -J fastp_all
#SBATCH -A kd2lab
#SBATCH -p batch
#SBATCH -N 1
#SBATCH -n 12
#SBATCH --mem=32G
#SBATCH -t 06:00:00
#SBATCH -o logs/%x_%j.out
#SBATCH -e logs/%x_%j.err

set -euo pipefail

# Step 2: fastp trimming (single-end) + FastQC on trimmed reads + MultiQC summary
# Tools:
#   fastp v0.23.4
#   FastQC v0.11.9 (Java 11)
#   MultiQC v1.28
#
# Inputs: raw FASTQs in RAW_DIR (top-level)
# Outputs:
#   Trimmed FASTQs:   $PROJECT/raw/trim/*.trim.fastq.gz
#   fastp reports:    $PROJECT/qc/fastqc_trim/*.fastp.html|json
#   FastQC trimmed:   $PROJECT/qc/fastqc_trim/*.trim_fastqc.html|zip
#   MultiQC report:   $PROJECT/qc/multiqc_trim_only/multiqc_report.html
#   Readcount table:  $PROJECT/logs/fastp_readcounts.tsv

PROJECT="/work/kd2lab/renuka/dual_rnaseq_KZJ39"
RAW_DIR="/work/kd2lab/renuka/RNA-Seq Reads"
TRIM_DIR="$PROJECT/raw/trim"
QCTRIM_DIR="$PROJECT/qc/fastqc_trim"
LOGS="$PROJECT/logs"

mkdir -p "$TRIM_DIR" "$QCTRIM_DIR" "$LOGS" "$PROJECT/qc/multiqc_trim_only"

module purge
module load fastp/0.23.4
module load Perl
module load FastQC/0.11.9-Java-11
module load MultiQC/1.28-foss-2024a

find "$RAW_DIR" -maxdepth 1 -type f \
  \( -iname "*.fastq.gz" -o -iname "*.fq.gz" -o -iname "*.fastq" -o -iname "*.fq" \) \
  ! -name "._*" | sort > "$LOGS/fastq_list_raw.txt"

echo "[info] Found $(wc -l < "$LOGS/fastq_list_raw.txt") raw FASTQ files"
head -n 20 "$LOGS/fastq_list_raw.txt" || true

# Process each file (treat as single-end; R1-only)
while IFS= read -r IN; do
  [ -s "$IN" ] || { echo "[warn] empty/missing: $IN"; continue; }
  base=$(basename "$IN")
  stem="${base%.fastq.gz}"; stem="${stem%.fq.gz}"; stem="${stem%.fastq}"; stem="${stem%.fq}"
  OUT="$TRIM_DIR/${stem}.trim.fastq.gz"
  HTML="$QCTRIM_DIR/${stem}.fastp.html"
  JSON="$QCTRIM_DIR/${stem}.fastp.json"

  if [ -s "$OUT" ]; then
    echo "[skip] already trimmed: $base"
  else
    echo "[fastp] $base -> $(basename "$OUT")"
    fastp \
      -i "$IN" \
      -o "$OUT" \
      -w 8 \
      --detect_adapter_for_pe \
      --cut_right --cut_right_window_size 4 --cut_right_mean_quality 20 \
      -h "$HTML" -j "$JSON"
  fi

  # FastQC on trimmed file
  if [ ! -s "$QCTRIM_DIR/${stem}.trim_fastqc.html" ]; then
    fastqc -t 4 -o "$QCTRIM_DIR" "$OUT"
  fi

  # Read counts summary (reads = lines/4)
  RAW_READS=$(zcat "$IN" | wc -l 2>/dev/null || echo 0); RAW_READS=$(( RAW_READS / 4 ))
  TRM_READS=$(zcat "$OUT" | wc -l 2>/dev/null || echo 0); TRM_READS=$(( TRM_READS / 4 ))
  echo -e "${stem}\traw=${RAW_READS}\ttrimmed=${TRM_READS}" >> "$LOGS/fastp_readcounts.tsv"

done < "$LOGS/fastq_list_raw.txt"

multiqc -o "$PROJECT/qc/multiqc_trim_only" "$QCTRIM_DIR"

echo "[done] Trimmed FASTQs: $TRIM_DIR"
echo "[done] Trimmed QC report: $PROJECT/qc/multiqc_trim_only/multiqc_report.html"
echo "[done] Read counts table: $LOGS/fastp_readcounts.tsv"
