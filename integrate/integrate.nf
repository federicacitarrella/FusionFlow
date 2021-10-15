#!/usr/bin/env nextflow

def helpMessage() {
    log.info"""

    Usage:

    The typical command for running the pipeline is as follows:

    nextflow run nf-core/rnafusion --reads '*_R{1,2}.fastq.gz' -profile docker

    Mandatory arguments:
      --reads [file]                Path to input data (must be surrounded with quotes)
      -profile [str]                Configuration profile to use.
                                    Available: docker, local, test_docker, test_local
    Optional DNA files:
      --wgst [file]                  Path tumor DNA bam file
      --wgsn [file]                  Path normal DNA bam file

    Tool flags:
      --arriba [bool]                Run Arriba
      --ericscript [bool]            Run Ericscript  
      --fusioncatcher [bool]         Run FusionCatcher
      --integrate [bool]             Run INTEGRATE

    References:
      --integrate_ref                Path to INTEGRATE reference

    Other options:
      --outdir [dir]                 The output directory where the results will be saved
      
    """.stripIndent()
}

// Show help message
if (params.help) {
    helpMessage()
    exit 0
}

refDir_integrate = file(params.integrate_ref)

params.skip_integrate = refDir_integrate.exists()

command = ""
filewgst = ""
filewgsn = ""
file1 = file(params.fasta1)
file2 = file(params.fasta2)

integrateWGSt = false
integrateWGSn = false

if (params.wgst != "") { 
  integrateWGSt = true
  filewgst = file(params.wgst)
  command = command + " dna.tumor.bam"
  }
if (params.wgsn != "") { 
  integrateWGSn = true
  filewgsn = file(params.wgsn)
  command = command + " dna.normal.out"
  }

Channel.fromPath(params.integrate_ref).into{ input_ch1_integrate;input_ch2_integrate }

(ch1_integrate , ch2_integrate , ch3_integrate) = ( params.skip_integrate ? [Channel.empty(), input_ch1_integrate, input_ch2_integrate] : [input_ch1_integrate, Channel.empty(), Channel.empty()] )

process downloader_integrate{

    input:
    val x from ch1_integrate

    output:
    file "ref_integrate" into ch4_integrate
    file "ref_integrate" into ch5_integrate
    
    """
    #!/bin/bash

    export PATH="${params.envPath_integrate}:$PATH" 

    mkdir ref_integrate
    cd ref_integrate

    wget https://ccb.jhu.edu/software/tophat/downloads/tophat-2.1.1.Linux_x86_64.tar.gz
    tar -xvzf tophat-2.1.1.Linux_x86_64.tar.gz
    rm tophat-2.1.1.Linux_x86_64/tophat

    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1A4JyTwjnwqDjWqVuEgt1sfDQrwU3oNbv"
    mv tophat tophat-2.1.1.Linux_x86_64/
    
    wget https://genome-idx.s3.amazonaws.com/bt/GRCh38_noalt_as.zip
    unzip GRCh38_noalt_as.zip
    rm GRCh38_noalt_as.zip

    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1Jd5r2hlfVSyqzz5fiZIspbN0PVORdad8"
    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=18SUV1abrk_MhYGOG6kzJPIeIJ5Zs5Yvb"

    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=14VCiEYWCl5m9bo_tsvNGQDUNUgtLje9Y"
    tar -xvf INTEGRATE.0.2.6.tar.gz
    rm INTEGRATE.0.2.6.tar
    cd INTEGRATE_0_2_6
    mkdir INTEGRATE-build 
    cd INTEGRATE-build
    cmake ../Integrate/ -DCMAKE_BUILD_TYPE=release 
    make 
    cd ../../
    mkdir ./bwts
    INTEGRATE_0_2_6/INTEGRATE-build/bin/Integrate mkbwt GRCh38.fa
    """

}

process integrate_converter{

    input:
    file integrate_db from ch2_integrate.mix(ch4_integrate)

    output:
    file "integrate_input" into integrate_input

    """
    #!/bin/bash

    export PATH="${params.envPath_integrate}:$PATH" 

    cp -r ${integrate_db}/tophat-2.1.1.Linux_x86_64/* ${params.envPath_integrate}

    tophat --no-coverage-search ${integrate_db}/GRCh38_noalt_as/GRCh38_noalt_as ${file1} ${file2}

    mkdir integrate_input
    cp tophat_out/accepted_hits.bam integrate_input
    cp tophat_out/unmapped.bam integrate_input
    
    """
}

process integrate{

    input:
    file integrate_db from ch3_integrate.mix(ch5_integrate)
    file input from integrate_input

    output:
    file "integrate_output" optional true into integrate_fusions

    """
    #!/bin/bash

    export PATH="${params.envPath_integrate}:$PATH" 

    cp ${input}/* .
  
    if ${integrateWGSt}; then
      cp ${filewgst} .
    fi
    if ${integrateWGSn}; then
      cp ${filewgsn} . 
    fi

    parallel samtools index ::: *.bam

    ${integrate_db}/INTEGRATE_0_2_6/INTEGRATE-build/bin/Integrate fusion ${integrate_db}/GRCh38.fa ${integrate_db}/annot.refseq.txt ${integrate_db}/bwts accepted_hits.bam unmapped.bam ${command}

    mkdir integrate_output
    mv *.tsv integrate_output
    mv *.txt integrate_output
    """
}