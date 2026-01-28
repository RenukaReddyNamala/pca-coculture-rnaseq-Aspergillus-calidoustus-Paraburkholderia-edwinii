\# PCA-Dependent Coculture RNA-seq Analysis  

\*\*Aspergillus calidoustus – Paraburkholderia edwinii\*\*



This repository contains a reproducible bulk RNA-seq analysis pipeline used to study

fungal transcriptional responses to coculture and phenazine carboxylic acid (PCA)

stress, with a focus on \*Aspergillus calidoustus\*.



The workflow includes quality control, trimming, genome annotation, alignment,

gene-level quantification, and differential expression analysis using edgeR.



---



\## Experimental Design



Single-end Illumina RNA-seq libraries were generated for \*Aspergillus calidoustus\*

grown under the following conditions:



\- Monoculture vs coculture with \*Paraburkholderia edwinii\*

\- PCA-treated vs untreated

\- Biological replicates per condition



Differential expression analysis focuses on \*\*fungal genes only\*\*.



---



\## Repository Structure



```text

scripts/

├── 01\_fastqc\_raw\_multiqc.sbatch

├── 02\_fastp\_trim\_and\_qc.sbatch

├── 03\_funannotate\_train\_container\_mysql.sbatch

├── 04\_funannotate\_predict.sbatch

├── 05\_funannotate\_annotate\_rename\_KZJ39.sbatch

├── 06\_build\_Acal\_master\_table.sbatch

├── 07a\_star\_index\_combined.sbatch

├── 07b\_star\_align\_combined\_se.sbatch

├── 08star\_featureCounts\_fungal.sbatch

├── 09\_edger\_ql\_fungus.sbatch

└── export\_funannotate\_master\_table.pyPipeline Overview



Quality control of raw reads using FastQC and MultiQC



Adapter trimming and filtering using fastp



Genome annotation using Funannotate (training, prediction, annotation)



STAR alignment to a combined fungal + bacterial genome



Fungal gene-level quantification using featureCounts



Differential expression analysis using edgeR (QL framework)



Differential Expression Analysis



Differential expression was performed using the edgeR quasi-likelihood framework.

Four biologically meaningful contrasts were tested:



Aspergillus\_NoPCA vs Coculture\_NoPCA



Aspergillus\_PCA vs Aspergillus\_NoPCA



Aspergillus\_PCA vs Coculture\_PCA



Coculture\_PCA vs Coculture\_NoPCA



Significant genes were defined using FDR ≤ 0.05.



Notes



Raw FASTQ files and large intermediate outputs are not included in this repository.



All scripts were executed on the University of Georgia GACRC (Sapelo2) HPC cluster.



File paths in scripts reflect the original HPC environment.



Author



Renuka Reddy Namala

Bioinformatics \& Computational Biology

University of Georgia





