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
      --dnabam [bool]

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
refDir_refgen = file(params.referenceGenome)
refDir_refgen_index = file(params.referenceGenome_index)
refDir_integrate_bwts = file(params.integrate_bwts)

params.skip_integrate = refDir_integrate.exists()
params.skip_integrate_bulder = refDir_integrate_bwts.exists()

params.skip_refgen = refDir_refgen.exists()
params.skip_refgen_index = refDir_refgen_index.exists()


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

Channel.fromPath(params.integrate_ref).into{ input_ch1_integrate;input_ch2_integrate;input_ch3_integrate }
Channel.fromPath(params.integrate_bwts).set{ input_ch1_bwts }

Channel.fromPath(params.referenceGenome).into{ input_ch1_refgen ; input_ch2_refgen ; input_ch3_refgen ; input_ch4_refgen}
Channel.fromPath(params.referenceGenome_index).set{ input_ch1_refgen_index }

(ch1_integrate , ch2_integrate , ch3_integrate, ch4_integrate) = ( params.skip_integrate ? [Channel.empty(), input_ch1_integrate, input_ch2_integrate, input_ch3_integrate] : [input_ch1_integrate, Channel.empty(), Channel.empty(), Channel.empty()] )
(ch1_integrate_bwts , ch2_integrate_bwts) = ( params.skip_integrate_bulder ? [Channel.empty(), input_ch1_bwts] : [input_ch1_bwts, Channel.empty()] )

(ch1_refgen , ch2_refgen , ch3_refgen, ch4_refgen, ch5_refgen) = ( params.skip_refgen ? [Channel.empty(), input_ch1_refgen, input_ch2_refgen, input_ch3_refgen, input_ch4_refgen] : [input_ch1_refgen, Channel.empty(), Channel.empty(), Channel.empty(), Channel.empty()] )
(ch1_refgen_index , ch2_refgen_index) = ( (params.skip_refgen_index || params.dnabam) ? [Channel.empty(), input_ch1_refgen_index] : [input_ch1_refgen_index, Channel.empty()] )

process downloader_referenceGenome{

    publishDir "${params.outdir}/reference_genome", mode: 'copy'
    
    input:
    val x from ch1_refgen

    output:
    file "hg38.fa" into ch6_refgen, ch7_refgen, ch8_refgen, ch9_refgen
    
    script:
    """
    #!/bin/bash

    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1AfNX3UvUOn4kSsu-ECrYChq8F8yJbFCI"
    """

}

process referenceGenome_index{

    publishDir "${params.outdir}/reference_genome", mode: 'copy'
    
    input:
    val x from ch1_refgen_index
    file refgen from ch5_refgen.mix(ch8_refgen)

    output:
    file "index" into ch3_refgen_index
    
    shell:
    '''
    #!/bin/bash

    export PATH="!{params.envPath_integrate}:$PATH"

    mkdir index && cd "$_"

    bwa index ../!{refgen}

    '''

}

process downloader_integrate{

    publishDir "${params.outdir}/integrate", mode: 'copy'

    input:
    val x from ch1_integrate

    output:
    file "references" into ch5_integrate, ch6_integrate, ch7_integrate
    
    shell:
    '''
    #!/bin/bash

    export PATH="!{params.envPath_integrate}:$PATH"

    mkdir references && cd "$_" 

    wget https://genome-idx.s3.amazonaws.com/bt/GRCh38_noalt_as.zip
    unzip GRCh38_noalt_as.zip
    rm GRCh38_noalt_as.zip

    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=18SUV1abrk_MhYGOG6kzJPIeIJ5Zs5Yvb"

    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=14VCiEYWCl5m9bo_tsvNGQDUNUgtLje9Y"
    tar -xvf INTEGRATE.0.2.6.tar.gz
    rm INTEGRATE.0.2.6.tar.gz
    
    cd INTEGRATE_0_2_6 && mkdir INTEGRATE-build && cd "$_" 
    cmake ../Integrate/ -DCMAKE_BUILD_TYPE=release 
    make 
    '''

}

process integrate_builder{

    publishDir "${params.outdir}/integrate/references", mode: 'copy'

    input:
    val x from ch1_integrate_bwts
    file refgen from ch3_refgen.mix(ch6_refgen)
    file integrate_db from ch4_integrate.mix(ch7_integrate)

    output:
    file "bwts" into ch8_integrate
    
    shell:
    '''
    #!/bin/bash

    export PATH="!{params.envPath_integrate}:$PATH" 

    LD_LIBRARY_PATH=/usr/local/lib
    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:!{integrate_db}/INTEGRATE_0_2_6/INTEGRATE-build/vendor/src/libdivsufsort-2.0.1-build/lib/
    export LD_LIBRARY_PATH

    mkdir ./bwts
    !{integrate_db}/INTEGRATE_0_2_6/INTEGRATE-build/bin/Integrate mkbwt !{refgen}
    '''

}

process integrate_converter{

    publishDir "${params.outdir}/integrate", mode: 'copy'

    input:
    file integrate_db from ch2_integrate.mix(ch5_integrate)
    file refgen from ch4_refgen.mix(ch7_refgen)
    file index from ch2_refgen_index.mix(ch3_refgen_index)

    output:
    file "input" into integrate_input

    script:
    """
    #!/bin/bash

    export PATH="${params.envPath_integrate}:$PATH" 

    tophat --no-coverage-search ${integrate_db}/GRCh38_noalt_as/GRCh38_noalt_as ${file1} ${file2}

    mkdir input
    cp tophat_out/accepted_hits.bam input
    cp tophat_out/unmapped.bam input

    if ${params.dnabam}; then
      if ${integrateWGSt}; then
        mv ${filewgst} input/dna.tumor.bam
      fi
      if ${integrateWGSn}; then
        mv ${filewgsn} input/dna.normal.bam
      fi
    else
      mkdir index_dir
      cp ${refgen}/* index_dir
      cp ${index}/* index_dir
      if ${integrateWGSt}; then
        bwa mem index_dir/hg38.fa ${filewgst} | samtools sort -o input/dna.tumor.bam
      fi
      if ${integrateWGSn}; then
        bwa mem index_dir/hg38.fa ${filewgsn} | samtools sort -o input/dna.normal.bam
      fi
    fi
    """
}

process integrate{

    publishDir "${params.outdir}/integrate", mode: 'copy'

    input:
    file integrate_db from ch3_integrate.mix(ch6_integrate)
    file input from integrate_input
    file refgen from ch2_refgen.mix(ch9_refgen)
    file bwts from ch2_integrate_bwts.mix(ch8_integrate)

    output:
    file "output" optional true into integrate_fusions

    shell:
    '''
    #!/bin/bash

    export PATH="!{params.envPath_integrate}:$PATH" 

    cp !{input}/* .
  
    parallel samtools index ::: *.bam

    LD_LIBRARY_PATH=/usr/local/lib
    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:!{integrate_db}/INTEGRATE_0_2_6/INTEGRATE-build/vendor/src/libdivsufsort-2.0.1-build/lib/
    export LD_LIBRARY_PATH

    !{integrate_db}/INTEGRATE_0_2_6/INTEGRATE-build/bin/Integrate fusion !{refgen} !{integrate_db}/annot.refseq.txt !{bwts} accepted_hits.bam unmapped.bam !{command1} !{command2}

    mkdir output
    mv *.tsv output
    mv *.txt output
    '''
}