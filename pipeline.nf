#!/usr/bin/env nextflow

fasta1 = file(params.in1)
fasta2 = file(params.in2)

process arriba{
    conda '/home/fcitarrella/miniconda3/envs/EricScript'

    """
    #!/bin/bash
    /home/fcitarrella/miniconda3/envs/EricScript/bin/ericscript.pl ${fasta1} ${fasta2}                                                            
    """

}

print "DONE"
