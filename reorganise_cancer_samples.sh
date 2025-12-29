#!/bin/bash

# Check if source directory is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <source_directory>"
    echo "Example: $0 /path/to/results"
    exit 1
fi

# Store source directory
SOURCE_DIR="$1"
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory '$SOURCE_DIR' does not exist."
    exit 1
fi

# Get current date in YYYY-MM-DD format
CURRENT_DATE=$(date +"%Y-%m-%d")

# Create the main directory
mkdir -p Cancer_samples_analysis

# Define sample types and analysis types
SAMPLE_TYPES=("normal" "tumor" "junction")
ANALYSIS_TYPES=("ascat" "cnvkit" "manta" "msisensorpro" "mutect2" "strelka")
REPORT_TYPES=("bcftools" "fastp" "fastqc" "markduplicates" "mosdepth" "samtools" "vcftools")

# Find all samples by looking at preprocessing directory
echo "Identifying samples from directory structure..."
SAMPLES=()

# Find all sample IDs from the preprocessing/markduplicates directory
if [ -d "$SOURCE_DIR/preprocessing/markduplicates" ]; then
    for dir in "$SOURCE_DIR/preprocessing/markduplicates"/*; do
        if [ -d "$dir" ]; then
            # Extract sample IDs from directory names
            basename=$(basename "$dir")
            sample_id=$(echo "$basename" | sed -E 's/^(normal|tumor|junction)_//')
            
            # Add to samples array if not already there
            if [[ ! " ${SAMPLES[@]} " =~ " ${sample_id} " ]]; then
                SAMPLES+=("$sample_id")
            fi
        fi
    done
else
    echo "Warning: preprocessing/markduplicates directory not found in $SOURCE_DIR"
    # Fallback to finding samples in variant_calling directory
    if [ -d "$SOURCE_DIR/variant_calling/mutect2" ]; then
        for dir in "$SOURCE_DIR/variant_calling/mutect2"/*; do
            if [ -d "$dir" ]; then
                basename=$(basename "$dir")
                # Handle both individual samples and paired analyses
                if [[ "$basename" == *"_vs_"* ]]; then
                    sample_id=$(echo "$basename" | sed -E 's/^(normal|tumor|junction)_//' | sed -E 's/_vs_.*//')
                else
                    sample_id=$(echo "$basename" | sed -E 's/^(normal|tumor|junction)_//')
                fi
                
                if [[ ! " ${SAMPLES[@]} " =~ " ${sample_id} " ]] && [[ "$sample_id" != "" ]]; then
                    SAMPLES+=("$sample_id")
                fi
            fi
        done
    fi
fi

if [ ${#SAMPLES[@]} -eq 0 ]; then
    echo "Error: No samples found in $SOURCE_DIR"
    exit 1
fi

echo "Found ${#SAMPLES[@]} samples: ${SAMPLES[*]}"

# Create the directory structure and copy files
for sample in "${SAMPLES[@]}"; do
    echo "Processing sample: $sample"
    # Create sample directory
    mkdir -p "Cancer_samples_analysis/$sample"
    
    # Create directories for each sample type if it exists
    for type in "${SAMPLE_TYPES[@]}"; do
        # Check if this sample-type combination exists
        if [ -d "$SOURCE_DIR/preprocessing/markduplicates/${type}_${sample}" ] || [ -d "$SOURCE_DIR/variant_calling/mutect2/${type}_${sample}" ]; then
            echo "  Creating structure for ${type}_${sample}"
            mkdir -p "Cancer_samples_analysis/$sample/$type"
            
            # Create analysis directories
            mkdir -p "Cancer_samples_analysis/$sample/$type/analysis"
            mkdir -p "Cancer_samples_analysis/$sample/$type/reports"
            mkdir -p "Cancer_samples_analysis/$sample/$type/preprocessing"
            
            # Copy preprocessing files
            if [ -d "$SOURCE_DIR/preprocessing/markduplicates/${type}_${sample}" ]; then
                cp -r "$SOURCE_DIR/preprocessing/markduplicates/${type}_${sample}"/* "Cancer_samples_analysis/$sample/$type/preprocessing/"
            fi
            if [ -d "$SOURCE_DIR/preprocessing/recalibrated/${type}_${sample}" ]; then
                cp -r "$SOURCE_DIR/preprocessing/recalibrated/${type}_${sample}"/* "Cancer_samples_analysis/$sample/$type/preprocessing/"
            fi
            if [ -d "$SOURCE_DIR/preprocessing/recal_table/${type}_${sample}" ]; then
                cp -r "$SOURCE_DIR/preprocessing/recal_table/${type}_${sample}"/* "Cancer_samples_analysis/$sample/$type/preprocessing/"
            fi
            
            # Copy report files
            for report in "${REPORT_TYPES[@]}"; do
                if [ -d "$SOURCE_DIR/reports/$report/${type}_${sample}" ]; then
                    mkdir -p "Cancer_samples_analysis/$sample/$type/reports/$report"
                    cp -r "$SOURCE_DIR/reports/$report/${type}_${sample}"/* "Cancer_samples_analysis/$sample/$type/reports/$report/"
                fi
            done
            
            # Copy analysis files (variants)
            for analysis in "${ANALYSIS_TYPES[@]}"; do
                if [ -d "$SOURCE_DIR/variant_calling/$analysis/${type}_${sample}" ]; then
                    mkdir -p "Cancer_samples_analysis/$sample/$type/analysis/$analysis"
                    cp -r "$SOURCE_DIR/variant_calling/$analysis/${type}_${sample}"/* "Cancer_samples_analysis/$sample/$type/analysis/$analysis/"
                fi
            done
        fi
    done

    # Handle the paired sample analyses (tumor vs normal or junction vs normal)
    for type in "tumor" "junction"; do
        paired_dir="${type}_${sample}_vs_normal_${sample}"
        if [ -d "$SOURCE_DIR/variant_calling/ascat/$paired_dir" ] || [ -d "$SOURCE_DIR/variant_calling/manta/$paired_dir" ]; then
            echo "  Creating structure for $paired_dir"
            mkdir -p "Cancer_samples_analysis/$sample/${type}_vs_normal/analysis"
            mkdir -p "Cancer_samples_analysis/$sample/${type}_vs_normal/reports"
            
            # Copy paired analysis files
            for analysis in "${ANALYSIS_TYPES[@]}"; do
                if [ -d "$SOURCE_DIR/variant_calling/$analysis/$paired_dir" ]; then
                    mkdir -p "Cancer_samples_analysis/$sample/${type}_vs_normal/analysis/$analysis"
                    cp -r "$SOURCE_DIR/variant_calling/$analysis/$paired_dir"/* "Cancer_samples_analysis/$sample/${type}_vs_normal/analysis/$analysis/"
                fi
            done
            
            # Copy paired report files
            for report in "${REPORT_TYPES[@]}"; do
                if [ -d "$SOURCE_DIR/reports/$report/$paired_dir" ]; then
                    mkdir -p "Cancer_samples_analysis/$sample/${type}_vs_normal/reports/$report"
                    cp -r "$SOURCE_DIR/reports/$report/$paired_dir"/* "Cancer_samples_analysis/$sample/${type}_vs_normal/reports/$report/"
                fi
            done
        fi
    done
done

# Copy multiqc directory with date
if [ -d "$SOURCE_DIR/multiqc" ]; then
    echo "Copying multiqc directory with date attachment..."
    mkdir -p "Cancer_samples_analysis/multiqc_${CURRENT_DATE}"
    cp -r "$SOURCE_DIR/multiqc"/* "Cancer_samples_analysis/multiqc_${CURRENT_DATE}/"
    echo "Created Cancer_samples_analysis/multiqc_${CURRENT_DATE}/"
fi

# Copy pipeline_info directory with date
if [ -d "$SOURCE_DIR/pipeline_info" ]; then
    echo "Copying pipeline_info directory with date attachment..."
    mkdir -p "Cancer_samples_analysis/pipeline_info_${CURRENT_DATE}"
    cp -r "$SOURCE_DIR/pipeline_info"/* "Cancer_samples_analysis/pipeline_info_${CURRENT_DATE}/"
    echo "Created Cancer_samples_analysis/pipeline_info_${CURRENT_DATE}/"
fi

# Create a README file with information about the reorganization
cat > "Cancer_samples_analysis/README.txt" << EOF
Cancer Samples Analysis
=======================

This directory contains the reorganized cancer analysis data.
Reorganization performed on: ${CURRENT_DATE}
Source directory: ${SOURCE_DIR}
Samples processed: ${SAMPLES[*]}

Directory structure:
- Each sample has its own directory
- Within each sample directory:
  - normal/, tumor/, and junction/ directories (if they exist)
  - tumor_vs_normal/ and junction_vs_normal/ directories for paired analyses
- multiqc_${CURRENT_DATE}/ contains the MultiQC reports
- pipeline_info_${CURRENT_DATE}/ contains the pipeline execution information

For questions about this structure, refer to the reorganization script.
EOF

echo "Reorganization complete. Files are now organized in Cancer_samples_analysis/"
echo "A README file has been created with information about the reorganization."