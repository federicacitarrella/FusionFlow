QUICK START:

1. Install Nextflow and Docker.
     
2. Test the pipeline:
        
        nextflow run federicacitarrella/pipelineGeneFusions -profile [test_docker/test_local]

4. Run your own analysis:
        
        nextflow run federicacitarrella/pipelineGeneFusions \
                --rnareads “/path/to/rna/reads_{1,2}.*” \ 
                --dnareads_tumor “/path/to/dna/tumor/reads_{3,4}.*” \
                --dnareads_normal “/path/to/dna/normal/reads_{5,6}.*” \
                --arriba --ericscript --fusioncatcher --integrate --genefuse \
                -profile <docker/local>