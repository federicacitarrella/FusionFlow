#!/usr/bin/env nextflow

fasta1 = file(params.in1)
fasta2 = file(params.in2)

process ericscript{
    conda '/opt/conda/envs/EricScript'

    """
    #!/bin/bash
    /opt/conda/envs/EricScript/bin/ericscript.pl ${fasta1} ${fasta2}                                                          
    """

}

