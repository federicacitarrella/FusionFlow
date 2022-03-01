# GeneFusion: a nextflow-based application

1. Install Nextflow and Docker.

2. Test the pipeline:

        nextflow run federicacitarrella/FusionFlow -profile [test_docker/test_local]

4. Run your own analysis:

        nextflow run federicacitarrella/FusionFlow \
                --rnareads “/path/to/rna/reads_{1,2}.*” \
                --dnareads_tumor “/path/to/dna/tumor/reads_{3,4}.*” \
                --dnareads_normal “/path/to/dna/normal/reads_{5,6}.*” \
                --arriba --ericscript --fusioncatcher --integrate --genefuse \
                -profile <docker/local>

Before using the local profile you need to create conda virtual environments from the yml files and specify the environment path in the command line (the Arriba path does not need "/bin").



e.g. nextflow run federicacitarrella/FusionFlow \
        --envPath_ericscript /path/to/miniconda3/envs/ericscript/bin \
        --envPath_arriba /path/to/miniconda3/envs/arriba/ \
        --envPath_fusioncatcher /path/to/miniconda3/envs/fusioncatcher/bin \
        --envPath_integrate /path/to/miniconda3/envs/integrate/bin \
        --envPath_genefuse /path/to/miniconda3/envs/genefuse/bin \
         -profile test_local


# Acknowledgments