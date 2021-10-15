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
refDir_integrate = file(params.integrate_ref)

params.skip_ericscript = refFile_ericscript.exists()
params.skip_arriba = refDir_arriba.exists()
params.skip_fusioncatcher= refDir_fusioncatcher.exists()
params.skip_integrate = refDir_integrate.exists()

file1 = file(params.fasta1)
file2 = file(params.fasta2)

command = ""
filewgst = ""
filewgsn = ""

integrateWGSt = false
integrateWGSn = false

if (params.wgst != "") { 
  integrateWGSt = true
  filewgst = file(params.wgst)
  command = command + " dna.tumor.bam"
  }
if (params.wgsn != "") { 
  integrateWGSn = true
  filewgsn = file(params.wgsn)
  command = command + " dna.normal.out"
  }

Channel.fromPath(params.ericscript_ref).set{ input_ch_ericscript }
Channel.fromPath(params.arriba_ref).set{ input_ch_arriba }
Channel.fromPath(params.fusioncatcher_ref).set{ input_ch_fusioncatcher }
Channel.fromPath(params.integrate_ref).into{ input_ch1_integrate; input_ch2_integrate }

(ch1_ericscript, ch2_ericscript) = ( params.skip_ericscript ? [Channel.empty(), input_ch_ericscript] : [input_ch_ericscript, Channel.empty()] )
(ch1_arriba, ch2_arriba) = ( params.skip_arriba ? [Channel.empty(), input_ch_arriba] : [input_ch_arriba, Channel.empty()] )
(ch1_fusioncatcher , ch2_fusioncatcher) = ( params.skip_fusioncatcher ? [Channel.empty(), input_ch_fusioncatcher] : [input_ch_fusioncatcher, Channel.empty()] )
(ch1_integrate , ch2_integrate , ch3_integrate) = ( params.skip_integrate ? [Channel.empty(), input_ch1_integrate, input_ch2_integrate] : [input_ch1_integrate, Channel.empty(), Channel.empty()] )


process downloader_ericsctipt{

    input:
    val x from ch1_ericscript

    output:
    file "ericscript_db_homosapiens_ensembl84" into ch3_ericscript
    
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
    file ericscript_db from ch2_ericscript.mix(ch3_ericscript)

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
    val x from ch1_arriba

    output:
    file "Arriba" into ch3_arriba
    
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
    file arriba_ref from ch2_arriba.mix(ch3_arriba)

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
    val x from ch1_fusioncatcher

    output:
    file "ref_fusioncatcher" into ch3_fusioncatcher
    
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
    file fusioncatcher_db from ch2_fusioncatcher.mix(ch3_fusioncatcher)

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

process downloader_integrate{

    input:
    val x from ch1_integrate

    output:
    file "ref_integrate" into ch4_integrate
    file "ref_integrate" into ch5_integrate
    
    """
    #!/bin/bash

    export PATH="${params.envPath_integrate}:$PATH" 

    mkdir ref_integrate
    cd ref_integrate

    wget https://ccb.jhu.edu/software/tophat/downloads/tophat-2.1.1.Linux_x86_64.tar.gz
    tar -xvzf tophat-2.1.1.Linux_x86_64.tar.gz
    rm tophat-2.1.1.Linux_x86_64/tophat

    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1A4JyTwjnwqDjWqVuEgt1sfDQrwU3oNbv"
    mv tophat tophat-2.1.1.Linux_x86_64/
    
    wget https://genome-idx.s3.amazonaws.com/bt/GRCh38_noalt_as.zip
    unzip GRCh38_noalt_as.zip
    rm GRCh38_noalt_as.zip

    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1Jd5r2hlfVSyqzz5fiZIspbN0PVORdad8"
    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=18SUV1abrk_MhYGOG6kzJPIeIJ5Zs5Yvb"

    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=14VCiEYWCl5m9bo_tsvNGQDUNUgtLje9Y"
    tar -xvf INTEGRATE.0.2.6.tar.gz
    rm INTEGRATE.0.2.6.tar.gz
    cd INTEGRATE_0_2_6
    mkdir INTEGRATE-build 
    cd INTEGRATE-build
    cmake ../Integrate/ -DCMAKE_BUILD_TYPE=release 
    make 
    cd ../../
    mkdir ./bwts
    INTEGRATE_0_2_6/INTEGRATE-build/bin/Integrate mkbwt GRCh38.fa
    """

}

process integrate_converter{

    input:
    file integrate_db from ch2_integrate.mix(ch4_integrate)

    output:
    file "integrate_input" into integrate_input

    """
    #!/bin/bash

    export PATH="${params.envPath_integrate}:$PATH" 

    cp -r ${integrate_db}/tophat-2.1.1.Linux_x86_64/* ${params.envPath_integrate}

    tophat --no-coverage-search ${integrate_db}/GRCh38_noalt_as/GRCh38_noalt_as ${file1} ${file2}

    mkdir integrate_input
    cp tophat_out/accepted_hits.bam integrate_input
    cp tophat_out/unmapped.bam integrate_input
    
    """
}

process integrate{

    input:
    file integrate_db from ch3_integrate.mix(ch5_integrate)
    file input from integrate_input

    output:
    file "integrate_output" optional true into integrate_fusions

    """
    #!/bin/bash

    export PATH="${params.envPath_integrate}:$PATH" 

    cp ${input}/* .
  
    if ${integrateWGSt}; then
      cp ${filewgst} .
    fi
    if ${integrateWGSn}; then
      cp ${filewgsn} . 
    fi

    parallel samtools index ::: *.bam

    ${integrate_db}/INTEGRATE_0_2_6/INTEGRATE-build/bin/Integrate fusion ${integrate_db}/GRCh38.fa ${integrate_db}/annot.refseq.txt ${integrate_db}/bwts accepted_hits.bam unmapped.bam ${command}

    mkdir integrate_output
    mv *.tsv integrate_output
    mv *.txt integrate_output
    """
}