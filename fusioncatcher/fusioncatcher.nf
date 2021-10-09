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

    References:
      --fusioncatcher_ref [file]         Path to Ericscript reference

    Other options:
      --outdir [file]                 The output directory where the results will be saved
      
    """.stripIndent()
}

// Show help message
if (params.help) {
    helpMessage()
    exit 0
}

refDir_fusioncatcher = file(params.fusioncatcher_ref)

params.skip_fusioncatcher= refDir_fusioncatcher.exists()

file1 = file(params.fasta1)
file2 = file(params.fasta2)

Channel.fromPath(params.fusioncatcher_ref).set{ input_ch_fusioncatcher }

(foo_ch_fusioncatcher , bar_ch_fusioncatcher) = ( params.skip_fusioncatcher ? [Channel.empty(), input_ch_fusioncatcher] : [input_ch_fusioncatcher, Channel.empty()] )

process downloader_fusioncatcher{

    input:
    val x from foo_ch_fusioncatcher

    output:
    file "ref_fusioncatcher" into ch2_fusioncatcher
    
    """
    #!/bin/bash

    mkdir -p ref_fusioncatcher
    cd ref_fusioncatcher
    wget http://sourceforge.net/projects/fusioncatcher/files/data/human_v102.tar.gz.aa
    wget http://sourceforge.net/projects/fusioncatcher/files/data/human_v102.tar.gz.ab
    wget http://sourceforge.net/projects/fusioncatcher/files/data/human_v102.tar.gz.ac
    wget http://sourceforge.net/projects/fusioncatcher/files/data/human_v102.tar.gz.ad
    cat human_v102.tar.gz.* | tar xz
    ln -s human_v102 current

    cd ..
    wget https://github.com/ndaniel/fastqtk/archive/refs/tags/v0.27.zip
    unzip v0.27.zip
    rm v0.27.zip
    cd fastqtk-0.27
    make
    mv fastqtk ../ref_fusioncatcher/
    """

}

process fusioncatcher{

    input:
    file fusioncatcher_db from bar_ch_fusioncatcher.mix(ch2_fusioncatcher)

    output:
    file "FusionCatcher_output" optional true into fusioncatcher_fusions

    """
    #!/bin/bash
    
    mv ${fusioncatcher_db}/fastqtk ${params.envPath_fusioncatcher}/

    export PATH="${params.envPath_fusioncatcher}:$PATH" 

    mkdir fasta_files
    cp ${file1} fasta_files
    cp ${file2} fasta_files
    
    fusioncatcher -d ${fusioncatcher_db}/human_v102 -i fasta_files -o FusionCatcher_output
    """
}