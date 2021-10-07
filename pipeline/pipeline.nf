#!/usr/bin/env nextflow

def helpMessage() {
    log.info"""

    Usage:

    The typical command for running the pipeline is as follows:

    nextflow run nf-core/rnafusion --reads '*_R{1,2}.fastq.gz' -profile docker

    Mandatory arguments:
      --reads [file]                  Path to input data (must be surrounded with quotes)
      -profile [str]                  Configuration profile to use.
                                      Available: docker, local, test_docker, test_local

    References:
      --ericscript_ref [file]         Path to Ericscript reference
      --arriba_ref [dir]              Path to Ericscript reference

    Other options:
      --outdir [file]                 The output directory where the results will be saved
      
    """.stripIndent()
}

// Show help message
if (params.help) {
    helpMessage()
    exit 0
}

refFile_ericscript = file(params.ericscript_ref)
refDir_arriba = file(params.arriba_ref)

params.skip_ericscript = refFile_ericscript.exists()
params.skip_arriba = refDir_arriba.exists()

file1 = file(params.fasta1)
file2 = file(params.fasta2)

Channel.fromPath(params.ericscript_ref).set{ input_ch_ericscript }
Channel.fromPath(params.arriba_ref).set{ input_ch_arriba }

(foo_ch_ericscript, bar_ch_ericscript) = ( params.skip_ericscript ? [Channel.empty(), input_ch_ericscript] : [input_ch_ericscript, Channel.empty()] )
(foo_ch_arriba, bar_ch_arriba) = ( params.skip_arriba ? [Channel.empty(), input_ch_arriba] : [input_ch_arriba, Channel.empty()] )

process downloader_ericsctipt{

    input:
    val x from foo_ch_ericscript

    output:
    file "ericscript_db_homosapiens_ensembl84" into ch2_ericscript
    
    """
    #!/bin/bash

    export PATH="${params.envPath_ericscript}:$PATH"

    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1VENACpUv_81HbIB8xZN0frasrAS7M4SP"
    tar -xf ericscript_db_homosapiens_ensembl84.tar.bz2
    
    rm ericscript_db_homosapiens_ensembl84.tar.bz2
    """

}

process ericscript{

    input:
    file ericscript_db from bar_ch_ericscript.mix(ch2_ericscript)

    output:
    file "EricScript_output" optional true into ericscript_fusions

    """
    #!/bin/bash
    
    export PATH="${params.envPath_ericscript}:$PATH" 
    
    ericscript.pl  -o ./EricScript_output -db $ericscript_db/ ${file1} ${file2}
    """
}

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
   
    ${params.envPath_arriba}var/lib/arriba/download_references.sh GRCh38+ENSEMBL93

    """
}

process arriba{

    input:
    file arriba_ref from bar_ch_arriba.mix(ch2_arriba)

    output:
    file "arriba_output" optional true into arriba_fusions

    """
    #!/bin/bash
    
    export PATH="${params.envPath_arriba}bin:$PATH" 

    mkdir arriba_output 

    run_arriba.sh ${arriba_ref}/STAR_index_GRCh38_ENSEMBL93/ ${arriba_ref}/ENSEMBL93.gtf ${arriba_ref}/GRCh38.fa ${params.envPath_arriba}var/lib/arriba/blacklist_hg19_hs37d5_GRCh37_v2.1.0.tsv.gz ${params.envPath_arriba}var/lib/arriba/known_fusions_hg19_hs37d5_GRCh37_v2.1.0.tsv.gz ${params.envPath_arriba}var/lib/arriba/protein_domains_hg19_hs37d5_GRCh37_v2.1.0.gff3 8 ${file1} ${file2}

    mv *.out arriba_output 
    mv *.tsv arriba_output 
    mv *.out arriba_output 
    mv *bam* arriba_output 
    """
}