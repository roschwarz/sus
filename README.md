# Speed Up Sequence downloads - (sus)

This script downloads sra files via aws, convert the files to fastqs and 
compresses the fastq files. It allows for the submission of single SRA IDs 
using the -i flag. However, a list of SRA IDs are also supported. For list,
these IDs are typically stored in a text file with each SRA IDD on a
separate line. When utelizing the thread flag, the compression step 
experiences acceleration. However, it is important to note that pigz is 
installed for that. Otherwise, single threded gzip is used. 

For those who need to download datasets from SRA and want to speed up the 
download, aws is a fast alternative and leads to ~85% time saving. I came 
across Dave Tang's blog (https://davetang.org/), where he shows a nice 
alternative for SRA data download using fasterq-dump, especially with aws. I
wrapped that up so that you finally get compressed fastq files.

## Little benchmark

I repeat the small benchmark (https://davetang.org/muse/2023/04/06/til-that-you-can-download-sra-data-from-aws/),
shown by Dave, by my self.


**download and conversion with fasterq-dump**

```
fasterq-dump:
time fasterq-dump --progres -e 56 SRR12571105
join   :|-------------------------------------------------- 100.00%
concat :|-------------------------------------------------- 100.00%
spots read      : 31,660,048
reads read      : 63,320,096
reads written   : 31,660,048
reads 0-length  : 31,660,048

real	11m34.224s
user	2m33.669s
sys	    1m46.582s

```

**download with aws and subsequent conversion to fastq**

```
aws s3 sync s3://sra-pub-run-odp/sra/SRR12571105 SRR12571105 --no-sign-request  
cd SRR12571105                                                                  
fasterq-dump ./SRR12571105 --progres -e 56

download: s3://sra-pub-run-odp/sra/SRR12571105/SRR12571105 to SRR12571105/SRR12571105
join   :|-------------------------------------------------- 100.00%
concat :|-------------------------------------------------- 100.00%
spots read      : 31,660,048
reads read      : 63,320,096
reads written   : 31,660,048
reads 0-length  : 31,660,048

real	1m40.652s
user	3m0.679s
sys	    0m20.930s
```

## Requirements

- python3

- pigz when parallel compression is desired

- aws

- fasterq-dump

## Sequencing protocol

The small python script is used to get information about the sequencing 
protocol (single or paired). This information is used to setup fasterq-dump 
so that it separates reads into R1 and R2 when paired-end data is downloaded.
In the past, I used efetch from the sra-tool kit to get this information, 
however, it was quite unstable and caused request errors several times.

## Usage

Make the script executable via `chmod +x sus.sh`

```
    Usage: ./sus.sh [-i] SRA-ID [-l] line separated list of SRR-IDs [-o] outputDir
    
    Parameters:
    
    -i <SRA ID> | SRA ID of file that is downloaded 
    -l <SRA ID list> | Text file with SRA IDs
    -t <threads> | Number if cores used for conversion and compression (default: 1) 
    -o <output> | path to output directory (default: fastqs)
    -h | shows help
        
    Examples: 
    # Download single file    
    ./sus.sh -i SRR16296673 -o sample_fastq -t 10
    # Download multiple files
    ./sus.sh -l sample.list.txt -o sample_list_fastq -t 10
```


