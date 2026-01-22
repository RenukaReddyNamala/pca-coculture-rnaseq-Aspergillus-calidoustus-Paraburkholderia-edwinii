#!/usr/bin/env bash
# Step 08: STAR alignment + gene-level quantification using featureCounts
# Organism: Aspergillus calidoustus (fungus-only RNA-seq)
# Counting: reverse-stranded (-s 2), exon-level, gene-level summarization
# Generated outputs:
#   fungal_gene_counts_se18.raw.txt
#   fungal_gene_counts_se18.raw.txt.summary
# Date executed: 2025-10-30

#SBATCH -J map_all
#SBATCH -p batch
#SBATCH --ntasks=1
#SBATCH -c 8
#SBATCH --mem=32G
#SBATCH -t 08:00:00
#SBATCH -o %x.%A_%a.out
#SBATCH -e %x.%A_%a.err

set -euo pipefail

####################
# Input definitions
####################
ROUTED="/work/kd2lab/renuka/star_alignments_fresh/manifest.routed.tsv"
# Columns: SAMPLE <TAB> FASTQ <TAB> route(acal|combined)

IDX_ACAL="/work/kd2lab/renuka/star_index_acal_fresh"
IDX_COMB="/work/kd2lab/renuka/star_index_combined_fresh"

ACAL_GTF="/work/kd2lab/renuka/annotations/Aspergillus_calidoustus.KZJ39.gtf"
COMB_GTF="/work/kd2lab/renuka/refs/combined/combined.gtf"

OUT="/work/kd2lab/renuka/star_alignments_fresh/alignments"
LOGD="$OUT/logs"
mkdir -p "$OUT" "$LOGD"

THREADS="${SLURM_CPUS_PER_TASK:-8}"

####################
# Load modules
####################
module purge || true
module load STAR/2.7.11b-GCC-13.3.0 || module load STAR
module load SAMtools/1.21-GCC-13.3.0 || module load SAMtools
module load Subread || true

####################
# Array job logic
####################
NLINES=$(wc -l < "$ROUTED")

if [[ -z "${SLURM_ARRAY_TASK_ID:-}" ]]; then
  echo "ERROR: run as an array job." >&2
  exit 2
fi

if (( SLURM_ARRAY_TASK_ID < 1 || SLURM_ARRAY_TASK_ID > NLINES )); then
  echo "ERROR: array index $SLURM_ARRAY_TASK_ID out of range (1..$NLINES)" >&2
  exit 2
fi

read -r SAMPLE FASTQ ROUTE < <(
  awk -v i="$SLURM_ARRAY_TASK_ID" 'NR==i{print $1,$2,$3}' "$ROUTED"
)

echo "SAMPLE=$SAMPLE"
echo "FASTQ=$FASTQ"
echo "ROUTE=$ROUTE"

####################
# Select genome + GTF
####################
if [[ "$ROUTE" == "acal" ]]; then
  IDX="$IDX_ACAL"
  GTF="$ACAL_GTF"
else
  IDX="$IDX_COMB"
  GTF="$COMB_GTF"
fi

####################
# Sanity checks
####################
for f in "$FASTQ" "$GTF"; do
  [[ -s "$f" ]] || { echo "Missing or empty: $f" >&2; exit 2; }
done

[[ -s "$IDX/Genome" ]] || { echo "STAR index missing at $IDX" >&2; exit 2; }

####################
# STAR alignment
####################
PREFIX="$OUT/${SAMPLE}_"
echo "Running STAR for $SAMPLE"

STAR \
  --genomeDir "$IDX" \
  --runThreadN "$THREADS" \
  --readFilesIn "$FASTQ" \
  --readFilesCommand zcat \
  --outSAMtype BAM SortedByCoordinate \
  --outFileNamePrefix "$PREFIX" \
  --outSAMattributes NH HI AS nM MD \
  --quantMode GeneCounts

####################
# Index BAM
####################
samtools index -@ "$THREADS" "${PREFIX}Aligned.sortedByCoord.out.bam"

####################
# featureCounts (fungus-only)
####################
featureCounts \
  -T "$THREADS" \
  -s 2 \
  -a "$GTF" \
  -o "${PREFIX}counts.txt" \
  "${PREFIX}Aligned.sortedByCoord.out.bam"

####################
# Tidy output
####################
awk 'NR==1{for(i=1;i<=NF;i++) if($i=="Geneid") g=i; next}
     NR>2{print $g "\t" $NF}' \
  "${PREFIX}counts.txt" > "${PREFIX}counts.tsv"

echo "DONE: $SAMPLE"
