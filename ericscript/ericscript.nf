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

//file1 = file(params.fasta1)
//file2 = file(params.fasta2)

if (params.input_paths) {
    if (params.single_end) {
        Channel
            .from(params.input_paths)
            .map { row -> [ row[0], [ file(row[1][0], checkIfExists: true) ] ] }
            .ifEmpty { exit 1, "params.input_paths was empty - no input files supplied" }
            .into { read_files_ericscript  }
    } else {
        Channel
            .from(params.input_paths)
            .map { row -> [ row[0], [ file(row[1][0], checkIfExists: true), file(row[1][1], checkIfExists: true) ] ] }
            .ifEmpty { exit 1, "params.input_paths was empty - no input files supplied" }
            .into { read_files_ericscript }
    }
} else {
    Channel
        .fromFilePairs(params.input, size: params.single_end ? 1 : 2)
        .ifEmpty { exit 1, "Cannot find any reads matching: ${params.input}\nNB: Path needs to be enclosed in quotes!\nIf this is single-end data, please specify --single_end on the command line." }
        .into { read_files_ericscript}
}

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
    tag "${sample}"

    publishDir "${params.outdir}/EricScript/${sample}", mode: 'copy'

    input:
    set val(sample), file(reads) from read_files_ericscript
    file ericscript_db from bar_ch.mix(ch2)

    output:
    set val(sample), file("${sample}_ericscript.tsv") optional true into ericscript_fusions
    set val(sample), file("${sample}_ericscript_total.tsv") optional true into ericscript_output

    script:
    """
    #!/bin/bash
    
    export PATH="${params.envPath}:$PATH" 
    
    ericscript.pl -o ./tmp -db $ericscript_db/ ${reads}

    mv tmp/*filtered.tsv ${sample}_ericscript.tsv
    mv tmp/*results.total.tsv ${sample}_ericscript_total.tsv
    """
}

ericscript_fusions = ericscript_fusions.dump(tag:'ericscript_fusions')