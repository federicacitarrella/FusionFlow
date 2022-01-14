#!/usr/bin/env nextflow

def helpMessage() {
    log.info"""

    Usage:

    The typical command for running the pipeline is as follows:

    nextflow run federicacitarrella/pipelineGeneFusions --rnareads '*_{1,2}.fastq.gz' --dnareads_tumor '*_{3,4}.fastq.gz' --dnareads_normal '*_{5,6}.fastq.gz' -profile docker

    Principal arguments:
      --rnareads [file]               Path to input RNA data (must be surrounded with quotes)
                                      Format: fastq
      --dnareads_tumor [file]         Path to input tumor DNA data (must be surrounded with quotes)
                                      Format: fastq, bam
      --dnareads_normal [file]        Path to input normal DNA data (must be surrounded with quotes)
                                      Format: fastq, bam
      -profile [str]                  Configuration profile to use.
                                      Available: docker, local, test_docker, test_local

    Tool flags:
      --arriba [bool]                 Run Arriba (RNA)
      --ericscript [bool]             Run Ericscript (RNA)
      --fusioncatcher [bool]          Run FusionCatcher (RNA)
      --integrate [bool]              Run Integrate (RNA; RNA+DNA)
      --genefuse [bool]               Run GeneFuse (DNA)

    References:
      --ericscript_ref [file]         Path to EricScript reference
      --arriba_ref [dir]              Path to Arriba reference
      --fusioncatcher_ref [dir]       Path to FusionCatcher reference
      --integrate_ref [file]          Path to Integrate reference
      --genefuse_ref [file]           Path to GeneFuse reference

    Options:
      --dnabam [bool]                 Specifies that the wgs input has bam format
      --nthreads [int]                Specifies the number of threads [8]

    Other options:
      --outdir [dir]                  The output directory where the results will be saved

    """.stripIndent()
}

/*
================================================================================
                         SET UP CONFIGURATION VARIABLES
================================================================================
*/

// Show help message
if (params.help) {
    helpMessage()
    exit 0
}

// Files and folders set up from default directories or directories defined in command line
refDir_refgen = file(params.referenceGenome)
refDir_refgen_index = file(params.referenceGenome_index)

refFile_ericscript = file(params.ericscript_ref)
refDir_arriba = file(params.arriba_ref)
refDir_fusioncatcher = file(params.fusioncatcher_ref)
refDir_integrate = file(params.integrate_ref)
refDir_integrate_bwts = file(params.integrate_bwts)
refDir_genefuse = file(params.genefuse_ref)

// Skip variables set up to verify the existence of files and folders and eventually skip the download processes execution
params.skip_refgen = refDir_refgen.exists()
params.skip_refgen_index = refDir_refgen_index.exists()

params.skip_ericscript = refFile_ericscript.exists()
params.skip_arriba = refDir_arriba.exists()
params.skip_fusioncatcher= refDir_fusioncatcher.exists()
params.skip_integrate = refDir_integrate.exists()
params.skip_integrate_bulder = refDir_integrate_bwts.exists()
params.skip_genefuse = refDir_genefuse.exists()

// INTEGRATE variables set up (this variable could be modified, for this reason they cannot be defined in the configuration file)
integrateWGSt = false
integrateWGSn = false
command1 = ""
command2 = ""

// If the user inserts DNA data in the command line the INTEGRATE variable are modified
if (params.dnareads_tumor) {
  integrateWGSt = true
  command1 = "dna.tumor.bam"
}

if (params.dnareads_normal) {
  integrateWGSn = true
  command2 = "dna.normal.bam"
}

// RNA data channels creation
( rna_reads_ericscript , rna_reads_arriba , rna_reads_fusioncatcher , rna_reads_integrate , support1 , support2 ) = ( params.rnareads ? [
  Channel.fromFilePairs(params.rnareads),
  Channel.fromFilePairs(params.rnareads),
  Channel.fromFilePairs(params.rnareads),
  Channel.fromFilePairs(params.rnareads),
  Channel.fromFilePairs(params.rnareads),
  Channel.fromFilePairs(params.rnareads)
] : [
  Channel.empty(),
  Channel.empty(),
  Channel.empty(),
  Channel.empty(),
  Channel.empty(),
  Channel.empty(),
  Channel.empty()
])

// DNA data channels creation
(dna_reads_tumor_integrate , dna_reads_tumor_genefuse ) = ( params.dnareads_tumor ? [Channel.fromFilePairs(params.dnareads_tumor, size: -1 ), Channel.fromFilePairs(params.dnareads_tumor, size: -1 )] : [support1.map{id,reads -> tuple(id,"1")}, Channel.empty()] ) // support1 channel is used to keep the integrate_concerter process running even if DNA data are not provided
(dna_reads_normal_integrate) = ( params.dnareads_normal ? [Channel.fromFilePairs(params.dnareads_normal, size: -1 )] : [support2.map{id,reads -> tuple(id,"1")}] )

Channel.fromPath(params.referenceGenome).into{ input_ch1_refgen ; input_ch2_refgen ; input_ch3_refgen ; input_ch4_refgen ; input_ch5_refgen}
Channel.fromPath(params.referenceGenome_index).set{ input_ch1_refgen_index }

Channel.fromPath(params.ericscript_ref).set{ input_ch_ericscript }
Channel.fromPath(params.arriba_ref).set{ input_ch_arriba }
Channel.fromPath(params.fusioncatcher_ref).set{ input_ch_fusioncatcher }
Channel.fromPath(params.integrate_ref).into{ input_ch1_integrate;input_ch2_integrate;input_ch3_integrate }
Channel.fromPath(params.integrate_bwts).set{ input_ch1_bwts }
Channel.fromPath(params.genefuse_ref).set{ input_ch1_genefuse }

(refgen_downloader , refgen_integrate , refgen_integrate_builder, refgen_integrate_converter, refgen_genefuse, refgen_referenceGenome_index) = ( params.skip_refgen ? [Channel.empty(), input_ch1_refgen, input_ch2_refgen, input_ch3_refgen, input_ch4_refgen, input_ch5_refgen] : [input_ch1_refgen, Channel.empty(), Channel.empty(), Channel.empty(), Channel.empty(), Channel.empty()] )
(refgen_index_trigger , refgen_index) = ( (params.skip_refgen_index || params.dnabam) ? [Channel.empty(), input_ch1_refgen_index] : [input_ch1_refgen_index, Channel.empty()] )

(ch1_ericscript, ch2_ericscript) =  [input_ch_ericscript, Channel.empty()]
(ch1_arriba, ch2_arriba) = ( params.skip_arriba ? [Channel.empty(), input_ch_arriba] : [input_ch_arriba, Channel.empty()] )
(ch1_fusioncatcher , ch2_fusioncatcher) = ( params.skip_fusioncatcher ? [Channel.empty(), input_ch_fusioncatcher] : [input_ch_fusioncatcher, Channel.empty()] )
(ch1_integrate , ch2_integrate , ch3_integrate, ch4_integrate) = ( params.skip_integrate ? [Channel.empty(), input_ch1_integrate, input_ch2_integrate, input_ch3_integrate] : [input_ch1_integrate, Channel.empty(), Channel.empty(), Channel.empty()] )
(ch1_integrate_bwts , ch2_integrate_bwts) = ( params.skip_integrate_bulder ? [Channel.empty(), input_ch1_bwts] : [input_ch1_bwts, Channel.empty()] )
(ch1_genefuse , ch2_genefuse ) = [input_ch1_genefuse, Channel.empty()]

/*
 * Reference Genome
 */

process referenceGenome_downloader{
    // Tag shown on the terminal while the process is running
    tag "Downloading"

    // publishDir publishes the output in a specific folder with copy mode
    storeDir "${params.outdir}/reference_genome"

    input:
    val trigger from refgen_downloader

    output:
    file "hg38.fa" into refgen_integrate_builder_down, refgen_integrate_converter_down, refgen_referenceGenome_index_down, refgen_integrate_down, refgen_genefuse_down

    // Conditions for the process execution
    when: params.integrate || params.genefuse || !(params.arriba || params.ericscript || params.fusioncatcher || params.genefuse || params.integrate)

    script:
    """
    #!/bin/bash

    export PATH="${params.envPath_integrate}:$PATH"

    curl -O -J -L https://osf.io/yevub/download
    """

}

//gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1AfNX3UvUOn4kSsu-ECrYChq8F8yJbFCI"

process referenceGenome_index{
    tag "Downloading"

    publishDir "${params.outdir}/reference_genome", mode: 'copy'

    input:
    val x from refgen_index_trigger
    file refgen from refgen_referenceGenome_index.mix(refgen_referenceGenome_index_down)

    output:
    file "index" into refgen_index_down

    when: params.integrate || !(params.arriba || params.ericscript || params.fusioncatcher || params.genefuse || params.integrate)

    shell:
    '''
    #!/bin/bash

    export PATH="!{params.envPath_integrate}:$PATH"

    mkdir index && cd "$_"
    cp ../!{refgen} .

    bwa index hg38.fa

    '''

}

/*
================================================================================
                                 FUSION PIPELINE
================================================================================
*/

/*
 * EricScript
 */

process ericsctipt_downloader{
    tag "Downloading"

    storeDir "${params.outdir}/ericscript/files"

    input:
    val x from ch1_ericscript

    output:
    file "ericscript_db_homosapiens_ensembl84" into ch3_ericscript

    when: params.ericscript || !(params.arriba || params.ericscript || params.fusioncatcher || params.genefuse || params.integrate)

    script:
    """
    #!/bin/bash

    export PATH="${params.envPath_ericscript}:$PATH"

    curl -O -J -L https://osf.io/54s6h/download
    tar -xf ericscript_db_homosapiens_ensembl84.tar.bz2

    rm ericscript_db_homosapiens_ensembl84.tar.bz2
    """

}

//gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1VENACpUv_81HbIB8xZN0frasrAS7M4SP"

process ericscript{
    tag "${pair_id}"

    publishDir "${params.outdir}/ericscript", mode: 'move'

    input:
    tuple pair_id, file(rna_reads), file(ericscript_db) from rna_reads_ericscript.combine(ch2_ericscript.mix(ch3_ericscript))

    output:
    file "output/${pair_id}" optional true into ericscript_fusions

    when: params.ericscript || !(params.arriba || params.ericscript || params.fusioncatcher || params.genefuse || params.integrate)

    script:
    reads = "../${rna_reads[0]} ../${rna_reads[1]}" //reads = params.single_end ? rna_reads[0] : "../${rna_reads[0]} ../${rna_reads[1]}"
    """
    #!/bin/bash

    export PATH="${params.envPath_ericscript}:$PATH"

    mkdir output && cd output

    ericscript.pl -o ./${pair_id} -db ../${ericscript_db} ${reads}
    """

}

/*
 * Arriba
 */

process arriba_downloader{
    tag "Downloading"

    storeDir "${params.outdir}/arriba"

    input:
    val x from ch1_arriba

    output:
    file "files" into ch3_arriba

    when: params.arriba || !(params.arriba || params.ericscript || params.fusioncatcher || params.genefuse || params.integrate)

    shell:
    '''
    #!/bin/bash

    export PATH="!{params.envPath_arriba}bin:$PATH"

    mkdir files && cd "$_"

    !{params.envPath_arriba}var/lib/arriba/download_references.sh GRCh38+ENSEMBL93
    '''

}

process arriba{
    tag "${pair_id}"

    publishDir "${params.outdir}/arriba", mode: 'move'

    input:
    tuple pair_id, file(rna_reads), file(arriba_ref) from rna_reads_arriba.combine(ch2_arriba.mix(ch3_arriba))

    output:
    file "output/${pair_id}" optional true into arriba_fusions

    when: params.arriba || !(params.arriba || params.ericscript || params.fusioncatcher || params.genefuse || params.integrate)

    script:
    """
    #!/bin/bash

    export PATH="${params.envPath_arriba}bin:$PATH"

    run_arriba.sh ${arriba_ref}/STAR_index_GRCh38_ENSEMBL93/ ${arriba_ref}/ENSEMBL93.gtf ${arriba_ref}/GRCh38.fa ${params.envPath_arriba}var/lib/arriba/blacklist_hg19_hs37d5_GRCh37_v2.1.0.tsv.gz ${params.envPath_arriba}var/lib/arriba/known_fusions_hg19_hs37d5_GRCh37_v2.1.0.tsv.gz ${params.envPath_arriba}var/lib/arriba/protein_domains_hg19_hs37d5_GRCh37_v2.1.0.gff3 ${params.nthreads} ${rna_reads}

    mkdir output && mkdir output/${pair_id}
    mv *.out output/${pair_id}
    mv *.tsv output/${pair_id}
    mv *.out output/${pair_id}
    mv *bam* output/${pair_id}
    """

}

/*
 * FusionCatcher
 */

process fusioncatcher_downloader{
    tag "Downloading"

    storeDir "${params.outdir}/fusioncatcher"

    input:
    val x from ch1_fusioncatcher

    output:
    file "files" into ch3_fusioncatcher

    when: params.fusioncatcher || !(params.arriba || params.ericscript || params.fusioncatcher || params.genefuse || params.integrate)

    shell:
    '''
    #!/bin/bash

    mkdir -p files && cd "$_"

    wget http://sourceforge.net/projects/fusioncatcher/files/data/human_v102.tar.gz.aa
    wget http://sourceforge.net/projects/fusioncatcher/files/data/human_v102.tar.gz.ab
    wget http://sourceforge.net/projects/fusioncatcher/files/data/human_v102.tar.gz.ac
    wget http://sourceforge.net/projects/fusioncatcher/files/data/human_v102.tar.gz.ad

    cat human_v102.tar.gz.* | tar xz
    ln -s human_v102 current
    '''

}

process fusioncatcher{
    tag "${pair_id}"

    publishDir "${params.outdir}/fusioncatcher", mode: 'move'

    input:
    tuple pair_id, file(rna_reads), file(fusioncatcher_db) from rna_reads_fusioncatcher.combine(ch2_fusioncatcher.mix(ch3_fusioncatcher))

    output:
    file "output/${pair_id}" optional true into fusioncatcher_fusions

    when: params.fusioncatcher || !(params.arriba || params.ericscript || params.fusioncatcher || params.genefuse || params.integrate)

    script:
    reads = "${rna_reads[0]},${rna_reads[1]}"  //reads = params.single_end ? rna_reads[0] : "${rna_reads[0]},${rna_reads[1]}"
    """
    #!/bin/bash

    export PATH="${params.envPath_fusioncatcher}:$PATH"

    fusioncatcher -d ${fusioncatcher_db}/human_v102 -i ${reads} -o output/${pair_id}
    """

}

/*
 * INTEGRATE
 */

process integrate_downloader{
    tag "Downloading"

    storeDir "${params.outdir}/integrate"

    input:
    val x from ch1_integrate

    output:
    file "files" into ch5_integrate, ch6_integrate, ch7_integrate

    when: params.integrate || !(params.arriba || params.ericscript || params.fusioncatcher || params.genefuse || params.integrate)

    shell:
    '''
    #!/bin/bash

    export PATH="!{params.envPath_integrate}:$PATH"

    mkdir files && cd "$_"

    wget https://genome-idx.s3.amazonaws.com/bt/GRCh38_noalt_as.zip
    unzip GRCh38_noalt_as.zip
    rm GRCh38_noalt_as.zip

    curl -O -J -L https://osf.io/dgvcx/download

    curl -O -J -L https://osf.io/gv7sq/download
    tar -xvf INTEGRATE.0.2.6.tar.gz
    rm INTEGRATE.0.2.6.tar.gz

    cd INTEGRATE_0_2_6 && mkdir INTEGRATE-build && cd "$_"
    cmake ../Integrate/ -DCMAKE_BUILD_TYPE=release
    make
    '''

}

//gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=18SUV1abrk_MhYGOG6kzJPIeIJ5Zs5Yvb"
//gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=14VCiEYWCl5m9bo_tsvNGQDUNUgtLje9Y"

process integrate_builder{
    tag "Building"

    publishDir "${params.outdir}/integrate/files", mode: 'copy'

    input:
    val x from ch1_integrate_bwts
    file refgen from refgen_integrate_builder.mix(refgen_integrate_builder_down)
    file integrate_db from ch4_integrate.mix(ch7_integrate)

    output:
    file "bwts" into ch8_integrate

    when: params.integrate || !(params.arriba || params.ericscript || params.fusioncatcher || params.genefuse || params.integrate)

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
    tuple pair_id, file(rna_reads), file(integrate_db), file(refgen), file(index), file(wgstinput), file(wgsninput) from rna_reads_integrate.combine(ch2_integrate.mix(ch5_integrate)).combine(refgen_integrate_converter.mix(refgen_integrate_converter_down)).combine(refgen_index.mix(refgen_index_down)).join(dna_reads_tumor_integrate).join(dna_reads_normal_integrate)

    output:
    tuple pair_id, file("input/${pair_id}") into integrate_input

    when: params.integrate || !(params.arriba || params.ericscript || params.fusioncatcher || params.genefuse || params.integrate)

    script:
    """
    #!/bin/bash

    export PATH="${params.envPath_integrate}:$PATH"

    tophat --no-coverage-search ${integrate_db}/GRCh38_noalt_as/GRCh38_noalt_as ${rna_reads}

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
    elif ${integrateWGSt} || ${integrateWGSn}; then
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

    publishDir "${params.outdir}/integrate", mode: 'move'

    input:
    tuple pair_id, file(input), file(integrate_db), file(refgen), file(bwts) from integrate_input.combine(ch3_integrate.mix(ch6_integrate)).combine(refgen_integrate.mix(refgen_integrate_down)).combine(ch2_integrate_bwts.mix(ch8_integrate))

    output:
    file "output/${pair_id}" optional true into integrate_fusions

    when: params.integrate || !(params.arriba || params.ericscript || params.fusioncatcher || params.genefuse || params.integrate)

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

/*
 * GeneFuse
 */

process genefuse_downloader{
    tag "Downloading"

    storeDir "${params.outdir}/genefuse"

    input:
    val x from ch1_genefuse

    output:
    file "files" into ch3_genefuse

    when: params.genefuse || !(params.arriba || params.ericscript || params.fusioncatcher || params.genefuse || params.integrate)

    shell:
    '''
    #!/bin/bash

    export PATH="!{params.envPath_integrate}:$PATH"

    mkdir files && cd "$_"
    curl -O -J -L https://osf.io/8r9fh/download
    chmod a+x ./genefuse
    curl -O -J -L https://osf.io/jqywz/download
    '''

}

//gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1OBLTo-yGZ88UGcF0F3v_7n8mLTQblWg8"
//gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1eRI5lAw0qntj0EbEpaNpvRA7saw_iyY3"

process genefuse_converter{
    tag "${pair_id}"

    publishDir "${params.outdir}/genefuse", mode: 'copy'

    input:
    tuple pair_id, file(wgstinput) from dna_reads_tumor_genefuse

    output:
    tuple pair_id, file("input/${pair_id}") into genefuse_input

    when: params.genefuse || !(params.arriba || params.ericscript || params.fusioncatcher || params.genefuse || params.integrate)

    script:
    """
    #!/bin/bash

    export PATH="${params.envPath_genefuse}:$PATH"

    mkdir input && mkdir input/${pair_id}

    if ${params.dnabam} && ${integrateWGSt}; then
        samtools sort -n  -o ${wgstinput}
        samtools fastq -@ ${params.nthreads} ${wgstinput} -1 ${pair_id}_3.fq.gz -2 ${pair_id}_4.fq.gz -0 /dev/null -s /dev/null -n
        cp *.fq.gz input/${pair_id}
    elif ${integrateWGSt}; then
        cp ${wgstinput} input/${pair_id}
    fi
    """

}

process genefuse{
    tag "${pair_id}"

    publishDir "${params.outdir}/genefuse", mode: 'move'

    input:
    tuple pair_id, file(input), file(refgen), file(genefuse_db) from genefuse_input.combine(refgen_genefuse.mix(refgen_genefuse_down)).combine(ch2_genefuse.mix(ch3_genefuse))

    output:
    file "output/${pair_id}" optional true into genefuse_fusions

    when: params.genefuse || !(params.arriba || params.ericscript || params.fusioncatcher || params.genefuse || params.integrate)

    script:
    """
    #!/bin/bash

    export PATH="${params.envPath_genefuse}:$PATH"

    cp ${input}/* .

    ${genefuse_db}/genefuse -r ${refgen} -f ${genefuse_db}/druggable.hg38.csv -1 ${pair_id}_3.* -2 ${pair_id}_4.* -h report.html > result

    mkdir output && mkdir output/${pair_id}
    cp report.html output/${pair_id}
    cp result output/${pair_id}
    """

}