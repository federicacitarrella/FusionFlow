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
      --dnabam

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

refDir_genefuse = file(params.genefuse_ref)
refDir_refgen = file(params.referenceGenome)

params.skip_genefuse = refDir_genefuse.exists()
params.skip_refgen = refDir_refgen.exists()

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
  command1 = "dna.tumor.bam"
  }

if (params.wgsn != "") { 
  integrateWGSn = true
  filewgsn = file(params.wgsn)
  command2 = "dna.normal.bam"
  }

Channel.fromPath(params.genefuse_ref).into{ input_ch1_genefuse;input_ch2_genefuse }
Channel.fromPath(params.referenceGenome).into{ input_ch1_refgen ; input_ch2_refgen ; input_ch3_refgen }

(ch1_genefuse , ch2_genefuse , ch3_genefuse) = ( params.skip_genefuse ? [Channel.empty(), input_ch1_genefuse, input_ch2_genefuse] : [input_ch1_genefuse, Channel.empty(), Channel.empty()] )
(ch1_refgen , ch2_refgen , ch3_refgen, ch4_refgen) = ( params.skip_refgen ? [Channel.empty(), input_ch1_refgen, input_ch2_refgen, input_ch3_refgen] : [input_ch1_refgen, Channel.empty(), Channel.empty(), Channel.empty()] )

process downloader_referenceGenome{

    publishDir "${params.outdir}/reference_genome", mode: 'copy'
    
    input:
    val x from ch1_refgen

    output:
    file "hg38.fa" into ch5_refgen
    
    """
    #!/bin/bash

    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1AfNX3UvUOn4kSsu-ECrYChq8F8yJbFCI"
    """

}

process downloader_genefuse{

    publishDir "${params.outdir}/genefuse", mode: 'copy'

    input:
    val x from ch1_genefuse

    output:
    file "reference" into ch4_genefuse
    
    shell:
    '''
    #!/bin/bash

    mkdir reference && cd "$_"
    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1OBLTo-yGZ88UGcF0F3v_7n8mLTQblWg8"
    chmod a+x ./genefuse
    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1eRI5lAw0qntj0EbEpaNpvRA7saw_iyY3"
    '''

}

process genefuse_converter{

    publishDir "${params.outdir}/genefuse", mode: 'copy'

    output:
    file "input" into genefuse_input

    script:
    """
    #!/bin/bash

    export PATH="${params.envPath_genefuse}:$PATH" 
    
    mkdir input

    if ${params.dnabam} && ${integrateWGSt}; then
        samtools sort -n  -o ${filewgst}
        samtools fastq -@ 8 ${filewgst} -1 R1.fastq.gz -2 R2.fastq.gz -0 /dev/null -s /dev/null -n
        cp *.fastq.gz input
    elif ${integrateWGSt}; then
        mv ${filewgst} input
    fi
    
    """
}

process genefuse{

    publishDir "${params.outdir}/genefuse", mode: 'copy'

    input:
    file input from genefuse_input
    file refgen from ch4_refgen.mix(ch5_refgen)
    file genefuse_db from ch2_genefuse.mix(ch4_genefuse)

    output:
    file "output" optional true into genefuse_fusions

    script:
    """
    #!/bin/bash

    export PATH="${params.envPath_genefuse}:$PATH" 

    cp ${input}/* .

    ${genefuse_db}/genefuse -r ${refgen} -f ${genefuse_db}/druggable.hg38.csv -1 *1.fastq.gz -2 *2.fastq.gz -h report.html > result

    mkdir output
    cp report.html output
    cp result output
    """
}