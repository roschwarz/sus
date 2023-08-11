#!/usr/bin/env bash
#
set -eo pipefail

# This script downloads sra files via aws, convert the files to fastqs and 
# compress it with pigz.
#
# author: Robert Schwarz
# email: schwarzrobert1988 at gmail.com


function usage(){

cat << help

    Usage: sus.sh [-i] SRA-ID [-l] line separated list of SRR-IDs [-o] outputDir
    
    Example: sus.sh -i SRA -o sample_fastq

    This script downloads sra files via aws, convert the files to fastqs and 
    compresses the fastq files. It allows for the submission of single SRA IDs 
    using the -i flag. However, a list of SRA IDs are also supported. For list,
    these IDs are typically stored in a text file with each SRA IDD on a
    separate line. When utelizing the thread flag, the compression step 
    experiences acceleration. However, it is important to note that pigz is 
    installed for that. Otherwise, single threded gzip is used. 


help


}


SCRIPT_HOME=$(dirname "$(realpath "$0")")
PWD=$(pwd)

output=fastqs

threads=1

# Argument parser
while getopts "i:l:t:o:" opt; do
    case "$opt" in
        i) id="$OPTARG" ;;
        l) idList="$OPTARG" ;;
        t) threads="$OPTARG" ;;
        o) output="$OPTARG" ;;
        *) echo "bash sra_download.sh [-i] SRR-ID [-l] line separated list of SRR-IDs [-t] int [-o] outputDir" >&2
            exit 1;;
    esac
done

if [ -z "$id" ] && [ -z "$idList" ]; then

    printf "\n    ERROR: Missing required input\n\n"
    usage
    exit 1

fi

if ! [ -x "$(command -v fasterq-dump)" ]; then
    printf "\n    ERROR: Fasterq dump is not installed. Make sure to add it to your PATH variable\n\n"
    exit 1
fi

if ! [ -x "$(command -v aws)" ]; then
    printf "\n    ERROR: aws is not installed. Make sure to add it to your PATH variable\n\n"
    exit 1
fi

mkdir -p "$output"

# Get information if data is paired- or single-end sequenced 
# Source bashbone as our common installed efetch produces errors.
# bashbone version of efetch=19.0
# common version of efetch=16.2
# efetch is really error prone, so that I implement an alternativ version
# that is hopefully more stable, see collect_seq_protocol_py
collect_seq_protocol(){
    
    bashbone -c
    local sra_id=$1

    seq_protocol="$(efetch -db sra -id "$sra_id" -format runinfo -mode xml | \
        grep '<LibraryLayout>' | sed -nE 's/^\s*<([^>]+>)(.+)<\/\1/\2/p')"

    bashbone -c

    echo "$seq_protocol"

}

# Get information if data is paired- or single-end sequenced 
# That is hopefully more stable that the efetch stuff
collect_seq_protocol_py(){
    
    local sra_id=$1

    seq_protocol="$(python3 $SCRIPT_HOME/src/getSeqStrat.py -id $sra_id)"

    echo "$seq_protocol"

}

# zip data with pigz; advantaged parallization is possible
# If pigz is not installed, gzip is used instead.
compression(){

    local sra_id=$1
    local seq_protocol=$2

    echo Compression of "$sra_id" 

    if [[ $seq_protocol == "paired" ]]; then
        sra_ids=("${sra_id}"_1.fastq "${sra_id}"_2.fastq)
    else
        sra_ids=("${sra_id}".fastq)
    fi
    
    if ! [ -x "$(command -v pigz)" ]; then
        echo pigz is not installed, using gzip instead
        zip=(gzip "${sra_ids[@]}")
    else
        zip=("pigz" "-p" "$threads" "${sra_ids[@]}")
    fi

    echo "${zip[@]}"
    "${zip[@]}"

}


# Download data with aws because it is much faster than fasterq-dump
# After download the data is converted from sra to fastq with fasterq-dump
# and zipped with pigz
#
# TO-DO:
# - possibility to set fasterq-dump?
download_via_aws(){

    local sra_id=$1
    local fastq_dir=$2
    local seq_protocol=$3
    
    echo "Download $sra_id"

    aws s3 sync s3://sra-pub-run-odp/sra/"$sra_id" "$fastq_dir" --no-sign-request
    
    toFastq=("fasterq-dump" "$fastq_dir/$sra_id" "--progres" "-e" "$threads" -O "$fastq_dir")

    if [[ $seq_protocol == "paired" ]]; then

        toFastq+=("--split-files")
    fi
    
    echo "${toFastq[@]}"

    # run fasterq-dump
    "${toFastq[@]}"

    # cd - jumps back to the orgin start point
    cd "$fastq_dir" && { pwd; compression "$sra_id" "$seq_protocol"; rm "$sra_id"; cd -; }

    echo "Download, conversion, and compression done for $sra_id"
    
}


# Download the fastq files
if [[ $idList ]]; then

# the read command can ignore the last row when there is no line break.
# Therefore, the grep command ensures to skip empty lines, but reads the last 
# line even when there is no linebreak. 

    while IFS= read -r line; do

        echo $line
    
        seq_protocol=$(collect_seq_protocol_py "$line")
        download_via_aws "$line" "$output" "$seq_protocol"
    
    done < <(grep . "$idList")                                

fi

if [[ $id ]]; then

    echo $id
    seq_protocol=$(collect_seq_protocol_py "$id")
    download_via_aws "$id" "$output" "$seq_protocol"

fi
