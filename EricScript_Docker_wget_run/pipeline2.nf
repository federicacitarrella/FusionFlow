#!/usr/bin/env nextflow

fasta1 = file(params.in1)
fasta2 = file(params.in2)

process download_ericscript{

    '''
    #!/bin/bash
    wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate "https://docs.google.com/uc?export=download&id=1VENACpUv_81HbIB8xZN0frasrAS7M4SP" -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=1VENACpUv_81HbIB8xZN0frasrAS7M4SP" -O /home/pipelineGeneFusion/ericscript_db_homosapiens_ensembl84.tar.bz2 && rm -rf /tmp/cookies.txt
    tar -xf ericscript_db_homosapiens_ensembl84.tar.bz2
    mv /ericscript_db_homosapiens_ensembl84/data/homo_sapiens /opt/conda/envs/EricScript/share/ericscript-0.5.5-5/lib/data/                                                        
    '''

}

process ericscript{
    conda '/opt/conda/envs/EricScript'

    """
    #!/bin/bash
    /opt/conda/envs/EricScript/bin/ericscript.pl ${fasta1} ${fasta2}                                                          
    """

}

print "DONE"
