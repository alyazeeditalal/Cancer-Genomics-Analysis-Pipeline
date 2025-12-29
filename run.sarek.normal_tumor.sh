#!/bin/bash
#SBATCH --job-name=somatic_germline_mutations
#SBATCH --partition=all-cpu-nodes
#SBATCH --nodes=1               
#SBATCH --ntasks-per-node=64  
#SBATCH --cpus-per-task=1
#SBATCH --mem=0
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err

##load nf-core environemnt
source /mnt/h700/omixlab/workflows/alyazeedit/miniconda3/etc/profile.d/nf-core
conda activate nf-core

# Set Singularity cache directory
export SINGULARITY_CACHEDIR="/mnt/h700/omixlab/workflows/alyazeedit/tmp"
export NXF_SINGULARITY_CACHEDIR="/mnt/h700/omixlab/workflows/alyazeedit/tmp"

/mnt/h700/omixlab/workflows/alyazeedit/my_workflows/Epi2me/nextflow run nf-core/sarek \
  -profile singularity \
  --input samplesheet.csv \
  --wes \
  --intervals resources/hg38_Twist_ILMN_Exome_2.5_Panel_Combined_Mito.bed\
  --aligner bwa-mem2 \
  --genome GATK.GRCh38 \
  --tools mutect2,strelka,manta,ascat,cnvkit,msisensorpro \
  --outdir results \
  --save_output_as_bam 



