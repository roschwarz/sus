# Speed Up Sequence downloads - (sus)

This script downloads sra files via aws, convert the files to fastqs and 
compresses the fastq files. It allows for the submission of single SRA IDs 
using the -i flag. However, a list of SRA IDs are also supported. For list,
these IDs are typically stored in a text file with each SRA IDD on a
separate line. When utelizing the thread flag, the compression step 
experiences acceleration. However, it is important to note that pigz is 
installed for that. Otherwise, single threded gzip is used. 

Usage: sus.sh [-i] SRA-ID [-l] line separated list of SRR-IDs [-o] outputDir
    
Example: sus.sh -i SRA -o sample_fastq

## Requirements

- python3

- pigz when parallel compression is desired

- aws

- fasterq-dump

## Usage

Make the script executable via `chmod +x sus.sh`

Usage: ./sus.sh [-i] SRA-ID [-l] line separated list of SRR-IDs [-o] outputDir
    
Example: ./sus.sh -i SRA -o sample_fastq


## Source

https://davetang.org/muse/2023/04/06/til-that-you-can-download-sra-data-from-aws/
