#!/usr/bin/env bash
#
set -eo pipefail

# This script downloads sra files via aws, convert the files to fastqs and 
# compress it with pigz or gzip.
#
# author: Robert Schwarz
# email: schwarzrobert1988 at gmail.com


function usage(){

cat << help

    This script downloads sra files via aws, convert the files to fastqs and 
    compresses the fastq files. It allows for the submission of single SRA IDs 
    using the -i flag. However, a list of SRA IDs are also supported. For list,
    these IDs are typically stored in a text file with each SRA IDD on a
    separate line. When utelizing the thread flag, the compression step 
    experiences acceleration. However, it is important to note that pigz is 
    installed for that. Otherwise, single threded gzip is used. 

    Usage: sus.sh [-i] SRA-ID [-l] line separated list of SRR-IDs [-o] outputDir
    
    Example: sus.sh -i SRA -o sample_fastq

    -i <SRA ID> | SRA ID of file that is downloaded 
    -l <SRA ID list> | Text file with SRA IDs
    -t <threads> | Number if cores used for conversion and compression (default: 1) 
    -o <output> | path to output directory (default: fastqs)
    -h | shows this help

    Required tools:
        - aws 
        - fasterq-dump
        - python3

help


}


SCRIPT_HOME=$(dirname "$(realpath "$0")")
PWD=$(pwd)

# colors
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
ENDCOLOR='\033[0m'

log() {

    msg=$1
    dt=$(date +"%x %r");
    printf "[%s] [LOG] %s\n" "$dt" "$msg";

}

err() {

    msg=$1
    dt=$(date +"%x %r");
    printf "\n    ${RED}[%s] [ERROR] %s${ENDCOLOR}\n" "$dt" "$msg";

}

warn() {
    msg=$1
    dt=$(date +"%x %r");
    printf "\n    ${YELLOW}[%s] [WARNING] %s${ENDCOLOR}\n" "$dt" "$msg";
}

#default settings

output=fastqs
threads=1

# Argument parser
while getopts "i:l:t:o:h" opt; do
    case "$opt" in
        i) id="$OPTARG" ;;
        l) idList="$OPTARG" ;;
        t) threads="$OPTARG" ;;
        o) output="$OPTARG" ;;
        h) usage 
            exit 1;;
        *) usage
            exit 1;;
    esac
done

if [ -z "$id" ] && [ -z "$idList" ]; then

    err "Missing required input"
    usage
    exit 1

fi

if ! [ -x "$(command -v fasterq-dump)" ]; then
    err "fasterq-dump is not installed. Make sure to add it to your PATH variable"
    usage
    exit 1
fi

if ! [ -x "$(command -v aws)" ]; then
    err "aws is not installed. Make sure to add it to your PATH variable"
    usage
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

    if [[ "$seq_protocol" == "Invalid Sra id" ]]; then
        echo "invalid"
    else
        echo "$seq_protocol"
    fi

}

# zip data with pigz; advantaged parallization is possible
# If pigz is not installed, gzip is used instead.
compression(){

    local sra_id=$1
    local seq_protocol=$2

    log Compression of "$sra_id" 

    if [[ $seq_protocol == "paired" ]]; then
        sra_ids=("${sra_id}"_1.fastq "${sra_id}"_2.fastq)
    else
        sra_ids=("${sra_id}".fastq)
    fi
    
    if ! [ -x "$(command -v pigz)" ]; then
        echo WARNING pigz is not installed, using gzip instead
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
# - may split the function into download, conversion, compression
download_via_aws(){

    local sra_id=$1
    local fastq_dir=$2
    local seq_protocol=$3
    
    log "Download $sra_id"

    aws s3 sync s3://sra-pub-run-odp/sra/"$sra_id" "$fastq_dir" --no-sign-request
    
    toFastq=("fasterq-dump" "$fastq_dir/$sra_id" "--progres" "-e" "$threads" -O "$fastq_dir")

    if [[ $seq_protocol == "paired" ]]; then

        toFastq+=("--split-files")
    fi
    
    log "${toFastq[@]}"

    # run fasterq-dump
    "${toFastq[@]}"

    # cd - jumps back to the orgin start point
    cd "$fastq_dir" && { pwd; compression "$sra_id" "$seq_protocol"; rm "$sra_id"; cd -; }

    log "Download, conversion, and compression done for $sra_id"
    
}


# Download the fastq files
if [[ $idList ]]; then

# the read command can ignore the last row when there is no line break.
# Therefore, the grep command ensures to skip empty lines, but reads the last 
# line even when there is no linebreak. 

    while IFS= read -r line; do

        seq_protocol=$(collect_seq_protocol_py "$line")


        if [[ "$seq_protocol" == "invalid" ]]; then
            warn "Invalid SRA ID (${id}) skip the requested file"
        else
            download_via_aws "$line" "$output" "$seq_protocol"
        fi
    
    done < <(grep . "$idList")                                

fi

if [[ $id ]]; then

    seq_protocol=$(collect_seq_protocol_py "$id")

    if [[ "$seq_protocol" == "invalid" ]]; then
        warn "Invalid SRA ID (${id}) skip the requested file"
    else
        download_via_aws "$id" "$output" "$seq_protocol"
    fi

fi
