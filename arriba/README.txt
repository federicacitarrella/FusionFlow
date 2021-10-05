QUICK START:

1. Install Nextflow and Docker.

2. Clone the repository:

        git clone --branch newBranch2 https://<username>@github.com/federicacitarrella/pipelineGeneFusions.git
      
3. Test the pipeline:
        
        cd pipelineGeneFusions/arriba
        nextflow run arriba.nf -profile test_docker

4. Run your own analysis:
        
        cd pipelineGeneFusions/arriba
        nextflow run arriba.nf --fasta1 'read_1.fastq' --fasta2 'read_2.fastq' -profile docker