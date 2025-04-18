#!/bin/bash

# Reference genome for minimap2
REFERENCE="mm39.fa"
# Number of cores to use
CORES=16

# Check if the minimap2 index exists, and create it if not
if [ ! -f "${REFERENCE}.mmi" ]; then
    echo "Index for ${REFERENCE} not found. Creating index..."
    minimap2 -d "${REFERENCE}.mmi" -x map-ont $REFERENCE
else
    echo "Index for ${REFERENCE} found."
fi

# Loop through all .bam files in the directory
for bam in *.bam; do
    # Extract the barcode from the filename (assuming the barcode is in the format barcodeXX)
    barcode=$(echo "$bam" | grep -o 'barcode[0-9]\+')

    # Check if there are multiple .bam files with the same barcode
    bam_files=($(ls *"$barcode"*.bam))
    if [ ${#bam_files[@]} -gt 1 ]; then
        # Merge the .bam files with the same barcode
        samtools merge -u -@ $CORES - "${bam_files[@]}" | \
        # Convert to fastq
        samtools fastq -T '*' -@ $CORES - | \
        # Align with minimap2 using the reference genome index
        minimap2 -a -t $CORES "${REFERENCE}.mmi" - | \
        # Sort the alignments
        samtools sort -@ $CORES -o "${barcode}.bam" -
        # Index the sorted .bam file
        samtools index -@ $CORES "${barcode}.bam"
        # Run sniffles to create a VCF file
        sniffles --input "${barcode}.bam" --vcf "${barcode}.vcf" --threads $CORES
    else
        # If only one .bam file with the barcode, process it directly
        samtools fastq -T '*' -@ $CORES "${bam_files[0]}" | \
        minimap2 -a -t $CORES "${REFERENCE}.mmi" - | \
        samtools sort -@ $CORES -o "${barcode}.bam" -
        samtools index -@ $CORES "${barcode}.bam"
        sniffles --input "${barcode}.bam" --vcf "${barcode}.vcf" --threads $CORES
    fi
done
