# Cancer Genomics Analysis Pipeline

A comprehensive workflow for somatic and germline variant analysis using nf-core/Sarek, designed for whole exome sequencing (WES) data with quality control and automated sample organization.

## Overview

This pipeline is composed of a collection of scripts that provide an end-to-end solution for cancer genomics analysis, relaying on the popular [Sarek](https://github.com/nf-core/sarek) pipleine including:
- Quality control of raw sequencing data
- Somatic and germline variant calling
- Copy number variation analysis
- Microsatellite instability detection
- Structural variant identification
- Automated result organization by sample

### About Sarek

This pipeline leverages [nf-core/Sarek](https://github.com/nf-core/sarek), a workflow designed to detect variants on whole genome or targeted sequencing data. Sarek is built using Nextflow and can handle various sequencing data types including whole genome sequencing (WGS), whole exome sequencing (WES), and targeted panels.

**Key features of Sarek:**
- Preprocessing: Alignment with BWA-mem/BWA-mem2, marking duplicates, base quality score recalibration
- Variant Calling: Multiple callers for germline and somatic variants (GATK HaplotypeCaller, Mutect2, Strelka, Manta, etc.)
- Annotation: VEP (Variant Effect Predictor) and snpEff support
- Quality Control: Comprehensive QC metrics at every step
- Reproducibility: Containerized with Singularity/Docker, version-controlled

For comprehensive documentation, advanced configuration options, and the latest updates, visit:
- **Sarek GitHub:** https://github.com/nf-core/sarek
- **Sarek Documentation:** https://nf-co.re/sarek
- **Sarek Parameters:** https://nf-co.re/sarek/parameters

## Pipeline Components

### 1. Quality Control (`qc.sh`)
**Purpose:** Performs quality assessment of raw FASTQ sequencing files before proceeding with variant calling.

**What it does:**
- Automatically discovers all FASTQ files in the input directory
- Runs FastQC in parallel to assess read quality, GC content, adapter contamination, and other metrics
- Uses GNU Parallel to optimize processing across available CPU cores (2 threads per FastQC job)
- Aggregates all FastQC reports using MultiQC into a single comprehensive HTML report
- Outputs organized QC metrics in a timestamped directory structure

**Use case:** Run this first to identify potential sequencing quality issues before investing compute time in alignment and variant calling.

### 2. Variant Calling - Tumor-Normal Analysis (`run_sarek_normal_tumor.sh`)
**Purpose:** Identifies somatic mutations and structural variants by comparing tumor samples against matched normal tissue.

**What it does:**
- Aligns paired-end reads to the human reference genome (GRCh38) using BWA-mem2
- Marks PCR/optical duplicates and performs base quality score recalibration (BQSR)
- Calls somatic variants using multiple tools for high-confidence variant detection:
  - **Mutect2:** SNVs and small indels with statistical modeling
  - **Strelka:** Fast and accurate SNV/indel calling
  - **Manta:** Structural variant detection (deletions, inversions, translocations)
  - **ASCAT:** Allele-specific copy number analysis and tumor purity/ploidy estimation
  - **CNVkit:** Copy number variation detection optimized for exome data
  - **MSIsensorpro:** Microsatellite instability scoring for immunotherapy prediction
- Saves aligned BAM files for downstream analysis

**Use case:** Standard approach for cancer genomics when matched normal tissue is available. Provides the most accurate somatic variant calls by filtering out germline variants.

### 3. Variant Calling - Tumor-Only Analysis (`run_sarek_tumor_only.sh`)
**Purpose:** Identifies variants in tumor samples without matched normal tissue.

**What it does:**
- Performs the same alignment and preprocessing as tumor-normal mode
- Calls variants using a subset of tools suitable for tumor-only analysis:
  - **Mutect2:** Uses population databases (gnomAD) to filter likely germline variants
  - **Manta:** Structural variant detection
  - **CNVkit:** Copy number variation with flat reference or pooled normal reference
- Saves aligned BAM files

**Use case:** When matched normal tissue is unavailable (e.g., archived samples, liquid biopsies, cell lines). Note that distinguishing somatic from germline variants is more challenging without a matched normal.

### 4. Result Organization (`reorganise_cancer_samples.sh`)
**Purpose:** Transforms Sarek's tool-centric output into an intuitive sample-centric directory structure.

**What it does:**
- Automatically identifies all samples from the Sarek results directory
- Creates organized folders for each sample with subdirectories for:
  - **Preprocessing:** BAM files, duplicate metrics, recalibration tables
  - **Reports:** FastQC, Samtools stats, Mosdepth coverage, VCF statistics
  - **Analysis:** Variant calls organized by tool (Mutect2, Strelka, Manta, etc.)
- Separates single-sample analyses (normal, tumor, junction) from paired analyses (tumor_vs_normal)
- Preserves MultiQC and pipeline info with date stamps
- Generates a README documenting the reorganization

**Use case:** Run after Sarek completes to make results easier to navigate, especially when analyzing multiple samples. Essential for sharing results with collaborators or downstream analysis tools.

---

## Requirements

### System Requirements
- SLURM cluster environment
- Singularity container runtime
- Minimum 64 CPU cores recommended
- Sufficient storage for intermediate files

### Software Dependencies
- [Nextflow](https://www.nextflow.io/) (latest version)
- [nf-core/Sarek](https://nf-co.re/sarek) pipeline
- [Conda](https://docs.conda.io/)/[Miniconda](https://docs.conda.io/en/latest/miniconda.html)
- [Singularity](https://sylabs.io/singularity/)
- GNU Parallel

### Required Conda Environments
1. **nf-core environment**: For nf-core utility tools (NOT for Nextflow - see Installation section)
2. **cancer_qc environment**: For QC analysis (requires FastQC, MultiQC, GNU Parallel)

---

## Installation

### 1. Clone this repository
```bash
git clone https://github.com/yourusername/cancer-genomics-pipeline.git
cd cancer-genomics-pipeline
```

### 2. Install Nextflow

Nextflow should be installed following the official installation guide. **Do not install via Conda** as it may cause version compatibility issues.

**Follow the official Nextflow installation documentation:**
- **Installation Guide:** https://www.nextflow.io/docs/latest/getstarted.html#installation
- **Quick Install:**
  ```bash
  curl -s https://get.nextflow.io | bash
  # Move to a directory in your PATH
  sudo mv nextflow /usr/local/bin/
  # OR add to your local bin
  mkdir -p $HOME/bin
  mv nextflow $HOME/bin/
  ```

**Verify installation:**
```bash
nextflow -version
```

### 3. Set up Conda environments

#### Create nf-core environment (for nf-core tools, NOT Nextflow itself)
```bash
conda create -n nf-core nf-core
conda activate nf-core
```

#### Create QC environment
```bash
conda create -n cancer_qc -c bioconda -c conda-forge fastqc multiqc parallel
```

### 4. Configure Singularity cache
```bash
export SINGULARITY_CACHEDIR="/path/to/your/singularity/cache"
export NXF_SINGULARITY_CACHEDIR="/path/to/your/singularity/cache"
```

### 5. Update script paths
Edit the scripts to match your system paths:
- Conda installation path
- Singularity cache directory
- Nextflow executable location

---

## Usage

### Step 1: Quality Control

Run FastQC and MultiQC on your raw FASTQ files:

```bash
sbatch qc.sh /path/to/fastq/directory output_subdirectory_name
```

**Arguments:**
- `<input_fastq_directory>`: Directory containing FASTQ files
- `<output_subdirectory>`: Name for the output subdirectory (e.g., "Run1", "Batch1")

**Output:** Results saved to `fastqc_results/<output_subdirectory>/`

**Example:**
```bash
sbatch qc.sh /data/raw_fastq Run1
```

### Step 2: Prepare Sample Sheet

Create a CSV samplesheet for Sarek with the following format:

#### For Tumor-Normal Pairs:
```csv
patient,sample,lane,fastq_1,fastq_2,status
Patient1,normal_Patient1,L001,/path/to/normal_R1.fastq.gz,/path/to/normal_R2.fastq.gz,0
Patient1,tumor_Patient1,L001,/path/to/tumor_R1.fastq.gz,/path/to/tumor_R2.fastq.gz,1
```

#### For Tumor-Only Analysis:
```csv
patient,sample,lane,fastq_1,fastq_2,status
Patient1,tumor_Patient1,L001,/path/to/tumor_R1.fastq.gz,/path/to/tumor_R2.fastq.gz,1
```

**Status codes:**
- `0` = Normal sample
- `1` = Tumor sample

### Step 3: Prepare Intervals File

Ensure you have a BED file for your target regions:
```bash
resources/hg38_Twist_ILMN_Exome_2.5_Panel_Combined_Mito.bed
```

Or update the `--intervals` parameter in the run scripts to point to your BED file.

### Step 4: Run Variant Calling

#### For Tumor-Normal Paired Analysis:
```bash
sbatch run_sarek_normal_tumor.sh
```

**Tools used:**
- Mutect2 (somatic SNVs/indels)
- Strelka (somatic SNVs/indels)
- Manta (structural variants)
- ASCAT (copy number analysis)
- CNVkit (copy number analysis)
- MSIsensorpro (microsatellite instability)

#### For Tumor-Only Analysis:
```bash
sbatch run_sarek_tumor_only.sh
```

**Tools used:**
- Mutect2 (somatic SNVs/indels)
- Manta (structural variants)
- CNVkit (copy number analysis)

### Step 5: Organize Results

After Sarek completes, reorganize results into a sample-centric structure:

```bash
bash reorganise_cancer_samples.sh /path/to/sarek/results
```

**Arguments:**
- `<source_directory>`: Path to the Sarek results directory (default: `results/`)

**Example:**
```bash
bash reorganise_cancer_samples.sh results/
```

---

## Output Structure

### Quality Control Output
```
fastqc_results/
└── <output_subdirectory>/
    ├── *_fastqc.html
    ├── *_fastqc.zip
    └── multiqc_report.html
```

### Reorganized Sarek Output
```
Cancer_samples_analysis/
├── <SampleID>/
│   ├── normal/
│   │   ├── preprocessing/       # BAM files, duplicates marked
│   │   ├── reports/             # QC metrics (FastQC, samtools, etc.)
│   │   └── analysis/            # Variant calls (per tool)
│   ├── tumor/
│   │   ├── preprocessing/
│   │   ├── reports/
│   │   └── analysis/
│   ├── junction/                # If applicable
│   │   ├── preprocessing/
│   │   ├── reports/
│   │   └── analysis/
│   ├── tumor_vs_normal/         # Paired analysis
│   │   ├── analysis/
│   │   │   ├── mutect2/
│   │   │   ├── strelka/
│   │   │   ├── manta/
│   │   │   ├── ascat/
│   │   │   ├── cnvkit/
│   │   │   └── msisensorpro/
│   │   └── reports/
│   └── junction_vs_normal/      # If applicable
├── multiqc_<YYYY-MM-DD>/
├── pipeline_info_<YYYY-MM-DD>/
└── README.txt
```

---

## Key Features

### Quality Control Script
- Parallel processing using GNU Parallel
- Automatic detection of FASTQ files (handles .fastq, .fq, .gz)
- Optimized thread allocation (2 threads per FastQC instance)
- Integrated MultiQC reporting
- Job logging for troubleshooting

### Sarek Variant Calling
- BWA-mem2 alignment for improved speed
- GATK GRCh38 reference genome
- BAM output preservation
- Multiple variant calling tools for consensus
- Optimized for whole exome sequencing

### Result Organization
- Sample-centric directory structure
- Automatic sample detection
- Handles normal, tumor, and junction samples
- Preserves paired analysis results
- Timestamped QC and pipeline info
- Generates informative README

---

## Important Notes

### Before Running

1. **Update paths in scripts:**
   - Conda installation path (line: `source /path/to/miniconda3/etc/profile.d/conda.sh`)
   - Singularity cache directory
   - Nextflow executable location

2. **Verify reference files:**
   - Ensure the intervals BED file exists at the specified path
   - Verify GATK.GRCh38 genome is available in your Sarek installation

3. **Check sample naming:**
   - Sample names should follow the pattern: `<type>_<SampleID>`
   - Types: `normal`, `tumor`, or `junction`
   - Example: `normal_Patient001`, `tumor_Patient001`

### Troubleshooting

**Issue: Conda environment not found**
```bash
# Verify conda is initialized
conda init bash
# Restart terminal and try again
```

**Issue: Singularity cache errors**
```bash
# Create and set cache directory
mkdir -p /path/to/singularity/cache
export SINGULARITY_CACHEDIR="/path/to/singularity/cache"
export NXF_SINGULARITY_CACHEDIR="/path/to/singularity/cache"
```

**Issue: No samples found during reorganization**
```bash
# Check that Sarek completed successfully
# Verify the results directory structure matches expected format
ls -R results/preprocessing/markduplicates/
```

**Issue: SLURM job fails**
```bash
# Check error logs
cat somatic_germline_mutations_<JOBID>.err
# Check output logs
cat somatic_germline_mutations_<JOBID>.out
```

---

## Resource Allocation

### QC Script
- **Nodes:** 1
- **CPUs:** 64 (adjustable based on available resources)
- **Memory:** All available (mem=0)
- **Typical runtime:** 2-6 hours (depends on number of samples)

### Sarek Pipeline
- **Nodes:** 1
- **CPUs:** 64 (Nextflow will manage distribution)
- **Memory:** All available (mem=0)
- **Typical runtime:** 12-48 hours (varies by sample count and data size)

---

## Citation

If you use this pipeline, please cite:

**Sarek:**
> Garcia M, Juhos S, Larsson M et al. Sarek: A portable workflow for whole-genome sequencing analysis of germline and somatic variants [version 2; peer review: 2 approved]. F1000Research 2020, 9:63 (https://doi.org/10.12688/f1000research.16665.2)

**nf-core:**
> Ewels PA, Peltzer A, Fillinger S et al. The nf-core framework for community-curated bioinformatics pipelines. Nat Biotechnol. 2020 (https://doi.org/10.1038/s41587-020-0439-x)

**FastQC:**
> Andrews S. (2010). FastQC: a quality control tool for high throughput sequence data. Available online at: http://www.bioinformatics.babraham.ac.uk/projects/fastqc

**MultiQC:**
> Ewels P, Magnusson M, Lundin S, Käller M. MultiQC: summarize analysis results for multiple tools and samples in a single report. Bioinformatics. 2016 (https://doi.org/10.1093/bioinformatics/btw354)

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Contact: [your.email@institution.edu]

---

## Changelog

### Version 1.0.0
- Initial release
- QC pipeline with FastQC/MultiQC
- Sarek integration for tumor-normal and tumor-only analysis
- Automated result reorganization

---

## Acknowledgments

- nf-core community for the Sarek pipeline
- SLURM cluster administrators
- All contributors to the tools used in this pipeline