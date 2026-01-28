#!/bin/bash
#SBATCH -J edger_ql_fungus
#SBATCH -p batch
#SBATCH -N 1
#SBATCH -n 4
#SBATCH --mem=16G
#SBATCH -t 04:00:00
#SBATCH -o logs/edger_ql.%j.out
#SBATCH -e logs/edger_ql.%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=rn92553@uga.edu

###############################################################################
# Step 08: Differential expression analysis using edgeR (QL framework)
# Organism: Aspergillus calidoustus (fungus-only RNA-seq)
# Input: Gene-level raw counts (featureCounts) + sample metadata
# Output:
#   - *.all.tsv : full DE results
#   - *.sig.tsv : significant genes
#   - GeneID-only filtered tables (used for plots & downstream analyses)
#
# edgeR version: via R 4.3.2
# Run date: October 30, 2025
###############################################################################

set -euo pipefail

############################
# USER CONFIG
############################
WORKDIR="/work/kd2lab/renuka/edger_ql_run"
COUNTS="${WORKDIR}/counts_fungus.tsv"
SAMPLES="${WORKDIR}/samples.tsv"
RSCRIPT="${WORKDIR}/00_edger_ql.R"

# Optional (for provenance / checksums)
GTF_PATH="/work/kd2lab/renuka/refs/Aspergillus.KZJ39.gtf"
GENOME_PATH="/work/kd2lab/renuka/refs/Aspergillus_assembly.fa"

############################
# ENVIRONMENT
############################
echo "== edgeR QL job starting @ $(date)"

mkdir -p "${WORKDIR}/logs" \
         "${WORKDIR}/edgeR_results" \
         "${WORKDIR}/provenance"

cd "${WORKDIR}"

module purge
module load R/4.3.2

############################
# RECORD TOOL VERSIONS
############################
echo "== Tool versions" | tee provenance/VERSIONS.txt
echo "R: $(R --version | head -n1)" | tee -a provenance/VERSIONS.txt
echo "Loaded modules:" | tee -a provenance/VERSIONS.txt
module list 2>&1 | tee -a provenance/VERSIONS.txt

############################
# INPUT VALIDATION
############################
echo "== Checking required inputs"
for f in "$COUNTS" "$SAMPLES" "$RSCRIPT"; do
  if [[ ! -s "$f" ]]; then
    echo "ERROR: Missing or empty file: $f" >&2
    exit 2
  fi
done

echo "== Preview samples.tsv"
head -n 5 "$SAMPLES" | sed 's/^/  /'

echo "== Preview counts matrix (first 8 columns)"
head -n 5 "$COUNTS" | cut -f1-8 | sed 's/^/  /'

############################
# CHECKSUMS (METHODS / REPRODUCIBILITY)
############################
echo "== Computing checksums"
{
  [[ -s "$GENOME_PATH" ]] && md5sum "$GENOME_PATH" || true
  [[ -s "$GTF_PATH"    ]] && md5sum "$GTF_PATH"    || true
  md5sum "$COUNTS"
  md5sum "$SAMPLES"
} > provenance/REF_CHECKSUMS.txt

############################
# RUN edgeR (QL)
############################
echo "== Running edgeR QL analysis"
Rscript --vanilla "$RSCRIPT"

############################
# CAPTURE SESSION INFO
############################
if [[ ! -s edgeR_results/sessionInfo.txt ]]; then
  echo "== Writing R sessionInfo"
  Rscript - <<'RS'
sink("edgeR_results/sessionInfo.txt")
sessionInfo()
sink()
RS
fi

############################
# SUMMARY
############################
echo "== edgeR output files"
ls -lh edgeR_results | sed 's/^/  /'

echo "== Significant gene counts per contrast"
for f in edgeR_results/*.sig.tsv; do
  [[ -f "$f" ]] || continue
  n=$(( $(wc -l < "$f") - 1 ))
  echo "  $(basename "$f") : $n genes"
done

echo "== edgeR QL job finished @ $(date)"
