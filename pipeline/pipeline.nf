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
      --ericscript_ref [file]         Path to EricScript reference
      --arriba_ref [dir]              Path to Arriba reference
      --fusioncatcher_ref [dir]       Path to FusionCatcher reference

    Other options:
      --outdir [dir]                 The output directory where the results will be saved
      
    """.stripIndent()
}

// Show help message
if (params.help) {
    helpMessage()
    exit 0
}

refFile_ericscript = file(params.ericscript_ref)
refDir_arriba = file(params.arriba_ref)
refDir_fusioncatcher = file(params.fusioncatcher_ref)

params.skip_ericscript = refFile_ericscript.exists()
params.skip_arriba = refDir_arriba.exists()
params.skip_fusioncatcher= refDir_fusioncatcher.exists()

file1 = file(params.fasta1)
file2 = file(params.fasta2)

Channel.fromPath(params.ericscript_ref).set{ input_ch_ericscript }
Channel.fromPath(params.arriba_ref).set{ input_ch_arriba }
Channel.fromPath(params.fusioncatcher_ref).set{ input_ch_fusioncatcher }

(foo_ch_ericscript, bar_ch_ericscript) = ( params.skip_ericscript ? [Channel.empty(), input_ch_ericscript] : [input_ch_ericscript, Channel.empty()] )
(foo_ch_arriba, bar_ch_arriba) = ( params.skip_arriba ? [Channel.empty(), input_ch_arriba] : [input_ch_arriba, Channel.empty()] )
(foo_ch_fusioncatcher , bar_ch_fusioncatcher) = ( params.skip_fusioncatcher ? [Channel.empty(), input_ch_fusioncatcher] : [input_ch_fusioncatcher, Channel.empty()] )

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
    
    cp ${fusioncatcher_db}/fastqtk ${params.envPath_fusioncatcher}/

    export PATH="${params.envPath_fusioncatcher}:$PATH" 

    mkdir fasta_files
    cp ${file1} fasta_files
    cp ${file2} fasta_files
    
    fusioncatcher -d ${fusioncatcher_db}/human_v102 -i fasta_files -o FusionCatcher_output
    """
}