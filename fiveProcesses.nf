#!/usr/bin/env nextflow

fasta1 = file(params.in1)
fasta2 = file(params.in2)

process ericscript{

    output:
    stdout ch
    """
    #!/bin/bash
    conda run -n EricScript /opt/conda/envs/EricScript/bin/ericscript.pl 
                                                        
    """

}

ch.view{print "I say..  $it"}