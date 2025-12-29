#!/bin/bash
#SBATCH --job-name=fastqc_multiqc
#SBATCH --partition=all-cpu-nodes
#SBATCH --nodes=1               
#SBATCH --ntasks-per-node=64 
#SBATCH --cpus-per-task=1
#SBATCH --mem=0
#SBATCH --output=cluster_logs/%x_%j.out
#SBATCH --error=cluster_logs/%x_%j.err

#make cluster_logs in case it doesn't exist
mkdir -p cluster_logs

# Check if input arguments are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <input_fastq_directory> <output_subdirectory>"
    echo "Example: $0 /path/to/fastq_files Run1"
    echo "Output will be saved to: fastqc_results/<output_subdirectory>"
    exit 1
fi

# Assign input arguments to variables
INPUT_DIR=$1
OUTPUT_SUBDIR=$2

# base directory
BASE_OUTPUT_DIR="fastqc_results"

# Create the specific subdirectory for the run's results
FULL_OUTPUT_DIR="${BASE_OUTPUT_DIR}/${OUTPUT_SUBDIR}"
mkdir -p $FULL_OUTPUT_DIR

# Load environment
source /mnt/h700/omixlab/workflows/alyazeedit/miniconda3/etc/profile.d/conda.sh
conda activate cancer_qc

# Print some information
echo "Processing FASTQ files from: $INPUT_DIR"
echo "Results will be saved to: $FULL_OUTPUT_DIR"
echo "Starting FastQC analysis..."

# Find all fastq files (handles both .fastq and .fq extensions, compressed or not)
FASTQ_FILES=$(find $INPUT_DIR -type f \( -name "*.fastq" -o -name "*.fastq.gz" -o -name "*.fq" -o -name "*.fq.gz" \))

# Check if any FASTQ files were found
if [ -z "$FASTQ_FILES" ]; then
    echo "No FASTQ files found in $INPUT_DIR"
    exit 1
fi

# Count the number of files to process
NUM_FILES=$(echo "$FASTQ_FILES" | wc -l)
echo "Found $NUM_FILES FASTQ files to process"

# Silent citation handling
export PARALLEL_SHELL=/bin/bash
parallel --will-cite --silent true ::: 1

# Allocate 2 threads per FastQC instance for better performance
THREADS_PER_FASTQC=2

# Calculate how many FastQC instances we can run simultaneously
MAX_PARALLEL_JOBS=$((SLURM_NTASKS_PER_NODE / THREADS_PER_FASTQC))

echo "Running FastQC with GNU Parallel using $MAX_PARALLEL_JOBS concurrent jobs, $THREADS_PER_FASTQC threads per job..."

# Create a temporary file in the current directory
TEMP_FILE="fastq_files_list_$$.tmp"
echo "$FASTQ_FILES" > $TEMP_FILE

# Run FastQC in parallel without interactive elements
parallel --jobs $MAX_PARALLEL_JOBS --joblog parallel_fastqc_joblog.txt \
    "fastqc -t $THREADS_PER_FASTQC -o $FULL_OUTPUT_DIR {}" :::: $TEMP_FILE

# Remove the temporary file
rm -f $TEMP_FILE
echo "FastQC processing complete! Running MultiQC..."

# Run MultiQC to summarize the results
multiqc $FULL_OUTPUT_DIR -o $FULL_OUTPUT_DIR
echo "Analysis complete!"
echo "FastQC results are in: $FULL_OUTPUT_DIR"
echo "MultiQC report is in: $FULL_OUTPUT_DIR/multiqc_report.html"

# Deactivate conda environment
conda deactivate