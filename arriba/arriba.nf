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
      --arriba_ref [dir]         Path to Ericscript reference

    Other options:
      --outdir [file]                 The output directory where the results will be saved
      
    """.stripIndent()
}

// Show help message
if (params.help) {
    helpMessage()
    exit 0
}

dbFile_arriba = file(params.arriba_ref)

params.skip_arriba= dbFile_arriba.exists()

file1 = file(params.fasta1)
file2 = file(params.fasta2)

Channel.fromPath(params.arriba_ref).set{ input_ch_arriba }

(foo_ch_arriba, bar_ch_arriba) = ( params.skip_arriba
                 ? [Channel.empty(), input_ch_arriba]
                 : [input_ch_arriba, Channel.empty()] )

process downloader_arriba{

    input:
    val x from foo_ch_arriba

    output:
    file "Arriba" into ch2_arriba
    
    """
    #!/bin/bash

    export PATH="${params.envPath_arriba}bin:$PATH"

    mkdir Arriba
    cd Arriba

    download_references.sh GRCh38+ENSEMBL93

    """

}

process arriba{

    input:
    file arriba_db from bar_ch_arriba.mix(ch2_arriba)

    output:
    file "arriba_output" optional true into arriba_fusions

    """
    #!/bin/bash
    
    export PATH="${params.envPath_arriba}bin:$PATH" 
    
    mkdir arriba_output
    cd arriba_output
    
    run_arriba.sh $arriba_db/STAR_index*/ $arriba_db/*.gtf $arriba_db/*.fa ${params.envPath_arriba}var/lib/arriba/blacklist*.1.0.tsv.gz ${params.envPath_arriba}var/lib/arriba/known_fusions_*.1.0.tsv.gz ${params.envPath_arriba}var/lib/arriba/protein_domains*.1.0.gff3 8 ${file1} ${file2}
    """
}