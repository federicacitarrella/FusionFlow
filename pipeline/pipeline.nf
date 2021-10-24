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

    Optional DNA files:
      --wgst [file]                  Path to tumor DNA bam file
      --wgsn [file]                  Path to normal DNA bam file

    References:
      --ericscript_ref [file]         Path to EricScript reference
      --arriba_ref [dir]              Path to Arriba reference
      --fusioncatcher_ref [dir]       Path to FusionCatcher reference
      --ericscript_ref [file]         Path to Ericscript reference

    Options:
      --dnabam [bool]                 Specifies that the wgs input has bam format
      --nthreads                      Specifies the number of threads [8]

    Other options:
      --outdir [dir]                 The output directory where the results will be saved
      
    """.stripIndent()
}

// Show help message
if (params.help) {
    helpMessage()
    exit 0
}

refDir_refgen = file(params.referenceGenome)
refDir_refgen_index = file(params.referenceGenome_index)

refFile_ericscript = file(params.ericscript_ref)
refDir_arriba = file(params.arriba_ref)
refDir_fusioncatcher = file(params.fusioncatcher_ref)
refDir_integrate = file(params.integrate_ref)
refDir_integrate_bwts = file(params.integrate_bwts)
refDir_genefuse = file(params.genefuse_ref)

params.skip_refgen = refDir_refgen.exists()
params.skip_refgen_index = refDir_refgen_index.exists()

params.skip_ericscript = refFile_ericscript.exists()
params.skip_arriba = refDir_arriba.exists()
params.skip_fusioncatcher= refDir_fusioncatcher.exists()
params.skip_integrate = refDir_integrate.exists()
params.skip_integrate_bulder = refDir_integrate_bwts.exists()
params.skip_genefuse = refDir_genefuse.exists()

integrateWGSt = false
integrateWGSn = false
command1 = "" 
command2 = "" 

if (params.wgst) { 
  integrateWGSt = true
  command1 = "dna.tumor.bam"
}

if (params.wgsn) { 
  integrateWGSn = true
  command2 = "dna.normal.bam"
}

Channel.fromFilePairs(params.reads, flat: true)
    .into{ reads_ericscript ; reads_arriba ; reads_fusioncatcher ; reads_integrate ; support1 ; support2 }

(ch1_wgst , ch2_wgst ) = ( params.wgst ? [Channel.fromFilePairs(params.wgst, size: params.dnabam ? -1 : -1 ), Channel.fromFilePairs(params.wgst, size: params.dnabam ? 1 : 2 )] : [support1.map{id,read1,read2 -> tuple(id,"1")}, Channel.empty()] )
(ch1_wgsn) = ( params.wgsn ? [Channel.fromFilePairs(params.wgsn, size: params.dnabam ? -1 : -1 )] : [support2.map{id,read1,read2 -> tuple(id,"1")}] )

Channel.fromPath(params.referenceGenome).into{ input_ch1_refgen ; input_ch2_refgen ; input_ch3_refgen ; input_ch4_refgen ; input_ch5_refgen}
Channel.fromPath(params.referenceGenome_index).set{ input_ch1_refgen_index }

Channel.fromPath(params.ericscript_ref).set{ input_ch_ericscript }
Channel.fromPath(params.arriba_ref).set{ input_ch_arriba }
Channel.fromPath(params.fusioncatcher_ref).set{ input_ch_fusioncatcher }
Channel.fromPath(params.integrate_ref).into{ input_ch1_integrate;input_ch2_integrate;input_ch3_integrate }
Channel.fromPath(params.integrate_bwts).set{ input_ch1_bwts }
Channel.fromPath(params.genefuse_ref)
    .ifEmpty{exit 1, "Cannot find any reads matching: ${params.reads}\nNB: Path needs to be enclosed in quotes!\nIf this is single-end data, please specify --single_end on the command line." }
    .into{ input_ch1_genefuse;input_ch2_genefuse }

(refgen_downloader , refgen_integrate , refgen_integrate_builder, refgen_integrate_converter, refgen_genefuse, refgen_referenceGenome_index) = ( params.skip_refgen ? [Channel.empty(), input_ch1_refgen, input_ch2_refgen, input_ch3_refgen, input_ch4_refgen, input_ch5_refgen] : [input_ch1_refgen, Channel.empty(), Channel.empty(), Channel.empty(), Channel.empty(), Channel.empty()] )
(refgen_index_trigger , refgen_index) = ( (params.skip_refgen_index || params.dnabam) ? [Channel.empty(), input_ch1_refgen_index] : [input_ch1_refgen_index, Channel.empty()] )

(ch1_ericscript, ch2_ericscript) = ( params.skip_ericscript ? [Channel.empty(), input_ch_ericscript] : [input_ch_ericscript, Channel.empty()] )
(ch1_arriba, ch2_arriba) = ( params.skip_arriba ? [Channel.empty(), input_ch_arriba] : [input_ch_arriba, Channel.empty()] )
(ch1_fusioncatcher , ch2_fusioncatcher) = ( params.skip_fusioncatcher ? [Channel.empty(), input_ch_fusioncatcher] : [input_ch_fusioncatcher, Channel.empty()] )
(ch1_integrate , ch2_integrate , ch3_integrate, ch4_integrate) = ( params.skip_integrate ? [Channel.empty(), input_ch1_integrate, input_ch2_integrate, input_ch3_integrate] : [input_ch1_integrate, Channel.empty(), Channel.empty(), Channel.empty()] )
(ch1_integrate_bwts , ch2_integrate_bwts) = ( params.skip_integrate_bulder ? [Channel.empty(), input_ch1_bwts] : [input_ch1_bwts, Channel.empty()] )
(ch1_genefuse , ch2_genefuse , ch3_genefuse) = ( params.skip_genefuse ? [Channel.empty(), input_ch1_genefuse, input_ch2_genefuse] : [input_ch1_genefuse, Channel.empty(), Channel.empty()] )


process downloader_referenceGenome{

    publishDir "${params.outdir}/reference_genome", mode: 'copy'
    
    input:
    val x from refgen_downloader

    output:
    file "hg38.fa" into refgen_integrate_builder_down, refgen_integrate_converter_down, refgen_referenceGenome_index_down, refgen_integrate_down, refgen_genefuse_down
    
    script:
    """
    #!/bin/bash

    export PATH="${params.envPath_integrate}:$PATH"

    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1AfNX3UvUOn4kSsu-ECrYChq8F8yJbFCI"
    """

}

process referenceGenome_index{

    publishDir "${params.outdir}/reference_genome", mode: 'copy'
    
    input:
    val x from refgen_index_trigger
    file refgen from refgen_referenceGenome_index.mix(refgen_referenceGenome_index_down)

    output:
    file "index" into refgen_index_down
    
    shell:
    '''
    #!/bin/bash

    export PATH="!{params.envPath_integrate}:$PATH"

    mkdir index && cd "$_"
    cp ../!{refgen} .
    
    bwa index hg38.fa

    '''

}

process ericsctipt_downloader{

    publishDir "${params.outdir}/ericscript/references", mode: 'copy'

    input:
    val x from ch1_ericscript

    output:
    file "ericscript_db_homosapiens_ensembl84" into ch3_ericscript
    
    script:
    """
    #!/bin/bash

    export PATH="${params.envPath_ericscript}:$PATH"

    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1VENACpUv_81HbIB8xZN0frasrAS7M4SP"
    tar -xf ericscript_db_homosapiens_ensembl84.tar.bz2
    
    rm ericscript_db_homosapiens_ensembl84.tar.bz2
    """

}

process ericscript{
    tag "${pair_id}"

    publishDir "${params.outdir}/ericscript", mode: 'copy'

    input:
    tuple pair_id, file(read1), file(read2), file(ericscript_db) from reads_ericscript.combine(ch2_ericscript.mix(ch3_ericscript))

    output:
    file "output/${pair_id}" optional true into ericscript_fusions

    script:
    """
    #!/bin/bash
    
    export PATH="${params.envPath_ericscript}:$PATH" 

    mkdir output && cd output
    
    ericscript.pl -o ./${pair_id} -db ../${ericscript_db} ../${read1} ../${read2}
    """

}

process arriba_downloader{

    publishDir "${params.outdir}/arriba", mode: 'copy'

    input:
    val x from ch1_arriba

    output:
    file "references" into ch3_arriba
    
    shell:
    '''
    #!/bin/bash

    export PATH="!{params.envPath_arriba}bin:$PATH"
    
    mkdir references && cd "$_"
   
    !{params.envPath_arriba}var/lib/arriba/download_references.sh GRCh38+ENSEMBL93
    '''

}

process arriba{
    tag "${pair_id}"

    publishDir "${params.outdir}/arriba", mode: 'copy'

    input:
    tuple pair_id, file(read1), file(read2), file(arriba_ref) from reads_arriba.combine(ch2_arriba.mix(ch3_arriba))

    output:
    file "output/${pair_id}" optional true into arriba_fusions

    script:
    """
    #!/bin/bash
    
    export PATH="${params.envPath_arriba}bin:$PATH" 

    run_arriba.sh ${arriba_ref}/STAR_index_GRCh38_ENSEMBL93/ ${arriba_ref}/ENSEMBL93.gtf ${arriba_ref}/GRCh38.fa ${params.envPath_arriba}var/lib/arriba/blacklist_hg19_hs37d5_GRCh37_v2.1.0.tsv.gz ${params.envPath_arriba}var/lib/arriba/known_fusions_hg19_hs37d5_GRCh37_v2.1.0.tsv.gz ${params.envPath_arriba}var/lib/arriba/protein_domains_hg19_hs37d5_GRCh37_v2.1.0.gff3 8 ${read1} ${read2}
    
    mkdir output && mkdir output/${pair_id}
    mv *.out output/${pair_id}
    mv *.tsv output/${pair_id}
    mv *.out output/${pair_id}
    mv *bam* output/${pair_id}
    """

}

process fusioncatcher_downloader{

    publishDir "${params.outdir}/fusioncatcher", mode: 'copy'

    input:
    val x from ch1_fusioncatcher

    output:
    file "references" into ch3_fusioncatcher
    
    shell:
    '''
    #!/bin/bash

    mkdir -p references && cd "$_"

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
    mv fastqtk ../references/
    '''

}

process fusioncatcher{
    tag "${pair_id}"

    publishDir "${params.outdir}/fusioncatcher", mode: 'copy'

    input:
    tuple pair_id, file(read1), file(read2), file(fusioncatcher_db) from reads_fusioncatcher.combine(ch2_fusioncatcher.mix(ch3_fusioncatcher))

    output:
    file "output/${pair_id}" optional true into fusioncatcher_fusions

    script:
    """
    #!/bin/bash
    
    cp ${fusioncatcher_db}/fastqtk ${params.envPath_fusioncatcher}/

    export PATH="${params.envPath_fusioncatcher}:$PATH" 

    mkdir fasta_files
    cp ${read1} fasta_files
    cp ${read2} fasta_files
    
    fusioncatcher -d ${fusioncatcher_db}/human_v102 -i fasta_files -o output/${pair_id}
    """

}

process integrate_downloader{

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
    file refgen from refgen_integrate_builder.mix(refgen_integrate_builder_down)
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
    tag "${pair_id}"

    publishDir "${params.outdir}/integrate", mode: 'copy'

    input:
    tuple pair_id, file(read1), file(read2), file(integrate_db), file(refgen), file(index), file(wgstinput), file(wgsninput) from reads_integrate.combine(ch2_integrate.mix(ch5_integrate)).combine(refgen_integrate_converter.mix(refgen_integrate_converter_down)).combine(refgen_index.mix(refgen_index_down)).join(ch1_wgst).join(ch1_wgsn)

    output:
    tuple pair_id, file("input/${pair_id}") into integrate_input

    script:
    """
    #!/bin/bash

    export PATH="${params.envPath_integrate}:$PATH" 

    tophat --no-coverage-search ${integrate_db}/GRCh38_noalt_as/GRCh38_noalt_as ${read1} ${read2}

    mkdir input && mkdir input/${pair_id}

    cp tophat_out/accepted_hits.bam input/${pair_id}
    cp tophat_out/unmapped.bam input/${pair_id}

    if ${params.dnabam}; then
      if ${integrateWGSt}; then
        cp ${wgstinput} input/${pair_id}/dna.tumor.bam
      fi
      if ${integrateWGSn}; then
        cp ${wgsninput} input/${pair_id}/dna.normal.bam
      fi
    else
      mkdir index_dir
      cp ${index}/* index_dir
      if ${integrateWGSt}; then
        bwa mem index_dir/hg38.fa ${wgstinput} | samtools sort -o input/${pair_id}/dna.tumor.bam
      fi
      if ${integrateWGSn}; then
        bwa mem index_dir/hg38.fa ${wgsninput} | samtools sort -o input/${pair_id}/dna.normal.bam
      fi
    fi
    """

}

process integrate{
    tag "${pair_id}"

    publishDir "${params.outdir}/integrate", mode: 'copy'

    input:
    tuple pair_id, file(input), file(integrate_db), file(refgen), file(bwts) from integrate_input.combine(ch3_integrate.mix(ch6_integrate)).combine(refgen_integrate.mix(refgen_integrate_down)).combine(ch2_integrate_bwts.mix(ch8_integrate))

    output:
    file "output/${pair_id}" optional true into integrate_fusions

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

    mkdir output && mkdir output/!{pair_id}
    cp *.tsv output/!{pair_id}
    cp *.txt output/!{pair_id}
    '''

}

process genefuse_downloader{

    publishDir "${params.outdir}/genefuse", mode: 'copy'

    input:
    val x from ch1_genefuse

    output:
    file "references" into ch4_genefuse
    
    shell:
    '''
    #!/bin/bash

    export PATH="!{params.envPath_integrate}:$PATH"

    mkdir references && cd "$_"
    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1OBLTo-yGZ88UGcF0F3v_7n8mLTQblWg8"
    chmod a+x ./genefuse
    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1eRI5lAw0qntj0EbEpaNpvRA7saw_iyY3"
    '''

}

process genefuse_converter{
    tag "${pair_id}"

    publishDir "${params.outdir}/genefuse", mode: 'copy'

    input:
    tuple pair_id, file(wgstinput)from ch2_wgst
    
    output:
    tuple pair_id, file("input/${pair_id}") into genefuse_input

    script:
    """
    #!/bin/bash

    export PATH="${params.envPath_genefuse}:$PATH" 
    
    mkdir input && mkdir input/${pair_id}

    if ${params.dnabam} && ${integrateWGSt}; then
        samtools sort -n  -o ${wgstinput}
        samtools fastq -@ ${params.nthreads} ${wgstinput} -1 ${pair_id}_1.fq.gz -2 ${pair_id}_2.fq.gz -0 /dev/null -s /dev/null -n
        cp *.fq.gz input/${pair_id}
    elif ${integrateWGSt}; then
        cp ${wgstinput} input/${pair_id}
    fi
    """

}

process genefuse{
    tag "${pair_id}"

    publishDir "${params.outdir}/genefuse", mode: 'copy'

    input:
    tuple pair_id, file(input), file(refgen), file(genefuse_db) from genefuse_input.combine(refgen_genefuse.mix(refgen_genefuse_down)).combine(ch2_genefuse.mix(ch4_genefuse))

    output:
    file "output/${pair_id}" optional true into genefuse_fusions

    script:
    """
    #!/bin/bash

    export PATH="${params.envPath_genefuse}:$PATH" 

    cp ${input}/* .

    ${genefuse_db}/genefuse -r ${refgen} -f ${genefuse_db}/druggable.hg38.csv -1 *1.fq* -2 *2.fq* -h report.html > result

    mkdir output && mkdir output/${pair_id}
    cp report.html output/${pair_id}
    cp result output/${pair_id}
    """

}