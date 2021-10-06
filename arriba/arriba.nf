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

dbFile_arriba = file(params.arriba_db)

dbFile_arriba_index = file(params.arriba_index)
dbFile_arriba_fasta = file(params.arriba_fasta)
dbFile_arriba_gtf = file(params.arriba_gtf)

/*
allFiles = dbFile_arriba_index.list()
for( def file : allFiles ) {
  println file
}
*/

params.skip_arriba= dbFile_arriba.exists()

file1 = file(params.fasta1)
file2 = file(params.fasta2)

Channel.fromPath(params.arriba).set{ input_ch_arriba }

(foo_ch_arriba, bar_ch_arriba) = ( params.skip_arriba
                 ? [Channel.empty(), input_ch_arriba]
                 : [input_ch_arriba, Channel.empty()] )

/*
Channel.fromPath(params.arriba_fasta).set{ input_ch_arriba_fasta }

(foo_ch_arriba_fasta, bar_ch_arriba_fasta) = ( params.skip_arriba
                 ? [Channel.empty(), input_ch_arriba_fasta]
                 : [input_ch_arriba_fasta, Channel.empty()] )

Channel.fromPath(params.arriba_gtf).set{ input_ch_arriba_gtf }

(foo_ch_arriba_gtf, bar_ch_arriba_gtf) = ( params.skip_arriba
                 ? [Channel.empty(), input_ch_arriba_gtf]
                 : [input_ch_arriba_gtf, Channel.empty()] )

Channel.fromPath(params.arriba_index).set{ input_ch_arriba_index }

(foo_ch_arriba_index, bar_ch_arriba_index) = ( params.skip_arriba
                 ? [Channel.empty(), input_ch_arriba_index]
                 : [input_ch_arriba_index, Channel.empty()] )
*/

process downloader_arriba{

    input:
    val x from foo_ch_arriba

    output:
    file "*.fa" into ch2_arriba_fasta
    file "*.gtf" into ch2_arriba_gtf
    file "STAR_index_GRCh38_ENSEMBL93" into ch2_arriba_index
    
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
    file fasta from bar_ch_arriba_fasta.mix(ch2_arriba_fasta)
    file gtf from bar_ch_arriba_gtf.mix(ch2_arriba_gtf)
    file index from bar_ch_arriba_index.mix(ch2_arriba_index)

    output:
    file "arriba_output" optional true into arriba_fusions

    """
    #!/bin/bash
    
    export PATH="${params.envPath_arriba}bin:$PATH" 
    
    mkdir arriba_output
    cd arriba_output
    
    #run_arriba.sh ${dbFile_arriba_index} ${dbFile_arriba_gtf} ${dbFile_arriba_fasta} ${params.envPath_arriba}var/lib/arriba/blacklist_hg19*.1.0.tsv.gz ${params.envPath_arriba}var/lib/arriba/known_fusions_hg19*.1.0.tsv.gz ${params.envPath_arriba}var/lib/arriba/protein_domains_hg19*.1.0.gff3 8 ${file1} ${file2}
    run_arriba.sh ${index} ${gtf} ${fasta} ${params.envPath_arriba}var/lib/arriba/blacklist_hg19*.1.0.tsv.gz ${params.envPath_arriba}var/lib/arriba/known_fusions_hg19*.1.0.tsv.gz ${params.envPath_arriba}var/lib/arriba/protein_domains_hg19*.1.0.gff3 8 ${file1} ${file2}
    """
}