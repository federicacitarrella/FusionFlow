QUICK START:

1. Install docker.

2. Run the docker container:

   sudo docker run -it --rm federicacitarrella/ericscript:external

3. Test the pipeline:
   
   cd /home
   ./nextflow run federicacitarrella/pipelineGeneFusions/pipeline -profile test

4. Run your own analysis:
   
   cd /home
   ./nextflow run federicacitarrella/pipelineGeneFusions/pipeline --reads '*_{1,2}.fastq' -profile <docker/local>