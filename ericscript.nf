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
      --ericscript_ref [file]         Path to Ericscript reference

    Other options:
      --outdir [file]                 The output directory where the results will be saved
      
    """.stripIndent()
}

// Show help message
if (params.help) {
    helpMessage()
    exit 0
}

dbFile = file(params.ericscript_ref)

params.skip= dbFile.exists()

file1 = file(params.fasta1)
file2 = file(params.fasta2)

Channel.fromPath(params.ericscript_ref).set{ input_ch }

(foo_ch, bar_ch) = ( params.skip
                 ? [Channel.empty(), input_ch]
                 : [input_ch, Channel.empty()] )

process downloader_ericsctipt{

    input:
    val x from foo_ch

    output:
    file "ericscript_db_homosapiens_ensembl84" into ch2
    
    """
    #!/bin/bash

    export PATH="${params.envPath}:$PATH"

    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1VENACpUv_81HbIB8xZN0frasrAS7M4SP"
    tar -xf ericscript_db_homosapiens_ensembl84.tar.bz2
    
    rm ericscript_db_homosapiens_ensembl84.tar.bz2
    """

}

process ericscript{

    input:
    file ericscript_db from bar_ch.mix(ch2)

    output:
    file "EricScript_output" optional true into ericscript_fusions

    """
    #!/bin/bash
    
    export PATH="${params.envPath}:$PATH" 
    
    ericscript.pl  -o ./EricScript_output -db $ericscript_db/ ${file1} ${file2}
    """
}