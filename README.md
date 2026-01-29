
# PCA-Dependent Coculture RNA-seq Analysis

**Aspergillus calidoustus – Paraburkholderia edwinii**

This repository contains a reproducible bulk RNA-seq analysis pipeline used to study fungal transcriptional responses to coculture and phenazine carboxylic acid (PCA) stress, with a focus on *Aspergillus calidoustus*.

The workflow includes quality control, trimming, genome annotation, alignment, gene-level quantification, and differential expression analysis using edgeR.

---

## Experimental Design

Single-end Illumina RNA-seq libraries were generated for *Aspergillus calidoustus* grown under the following conditions:

- Monoculture vs coculture with *Paraburkholderia edwinii*
- PCA-treated vs untreated
- Biological replicates per condition

Differential expression analysis focuses on **fungal genes only**.

---

## Repository Structure

```text
scripts/
├── 01_fastqc_raw_multiqc.sbatch
├── 02_fastp_trim_and_qc.sbatch
├── 03_funannotate_train_container_mysql.sbatch
├── 04_funannotate_predict.sbatch
├── 05_funannotate_annotate_rename_KZJ39.sbatch
├── 06_build_Acal_master_table.sbatch
├── 07a_star_index_combined.sbatch
├── 07b_star_align_combined_se.sbatch
├── 08star_featureCounts_fungal.sbatch
├── 09_edger_ql_fungus.sbatch
└── export_funannotate_master_table.py

results/
├── edgeR_tables/
├── volcano_plots/
└── heatmaps/
```

---

## Pipeline Overview

1. Quality control of raw reads using FastQC and MultiQC  
2. Adapter trimming and filtering using fastp  
3. Genome annotation using Funannotate (training, prediction, annotation)  
4. STAR alignment to a combined fungal + bacterial genome  
5. Fungal gene-level quantification using featureCounts  
6. Differential expression analysis using edgeR (quasi-likelihood framework)  

---

## Author

**Renuka Reddy Namala**  
Bioinformatics & Computational Biology  
University of Georgia
