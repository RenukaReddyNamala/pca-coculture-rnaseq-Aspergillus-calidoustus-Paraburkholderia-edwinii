#!/bin/bash
#SBATCH -J fastqc_raw
#SBATCH -A kd2lab
#SBATCH -p batch
#SBATCH -N 1
#SBATCH -n 8
#SBATCH --mem=16G
#SBATCH -t 04:00:00
#SBATCH -o logs/%x_%j.out
#SBATCH -e logs/%x_%j.err

set -euo pipefail

# Step 1: FastQC on raw reads + MultiQC
# Inputs: raw FASTQ/FQ files in READS_DIR (top-level)
# Outputs: qc/fastqc_raw/*_fastqc.html|zip and qc/multiqc/multiqc_report.html

PROJECT="/work/kd2lab/renuka/dual_rnaseq_KZJ39"
READS_DIR="/work/kd2lab/renuka/RNA-Seq Reads"

mkdir -p "$PROJECT/qc/fastqc_raw" "$PROJECT/qc/multiqc" "$PROJECT/logs"
cd "$PROJECT"

module purge
module load Perl
module load FastQC/0.11.9-Java-11
module load MultiQC/1.28-foss-2024a

find "$READS_DIR" -maxdepth 1 -type f \
  \( -iname "*.fastq.gz" -o -iname "*.fq.gz" -o -iname "*.fastq" -o -iname "*.fq" \) \
  ! -name "._*" \
  > logs/fastq_list.txt

echo "Found $(wc -l < logs/fastq_list.txt) FASTQs in: $READS_DIR"
head -n 20 logs/fastq_list.txt || true

while IFS= read -r fq; do
  [ -s "$fq" ] || { echo "[warn] Missing/empty: $fq"; continue; }
  base=$(basename "$fq")
  outzip="qc/fastqc_raw/${base%.*}_fastqc.zip"
  outhtml="qc/fastqc_raw/${base%.*}_fastqc.html"
  if [ -f "$outzip" ] || [ -f "$outhtml" ]; then
    echo "Skipping (already done): $base"
    continue
  fi
  echo "FastQC → $base"
  fastqc -t 4 -o qc/fastqc_raw "$fq"
done < logs/fastq_list.txt

multiqc -o qc/multiqc qc/fastqc_raw

echo "QC complete."
echo "Report: $PROJECT/qc/multiqc/multiqc_report.html"

