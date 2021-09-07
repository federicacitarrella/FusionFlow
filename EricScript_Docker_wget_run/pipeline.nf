#!/usr/bin/env nextflow

fasta1 = file(params.in1)
fasta2 = file(params.in2)

process ericscript{

    script:
    '''
    wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate "https://docs.google.com/uc?export=download&id=1VENACpUv_81HbIB8xZN0frasrAS7M4SP" -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=1VENACpUv_81HbIB8xZN0frasrAS7M4SP" -O /home/pipelineGeneFusion/ericscript_db_homosapiens_ensembl84.tar.bz2 && rm -rf /tmp/cookies.txt                                                        
    '''

}

print "DONE"
