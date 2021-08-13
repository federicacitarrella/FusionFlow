To run the Nextflow pipeline fiveProcesses follow the instructions below:

1. install Nextflow:
$ wget -qO- https://get.nextflow.io | bash

2. download the pipelineGeneFusion folder:
$ git clone --recursive https://<username>@github.com/federicacitarrella/pipelineGeneFusions.git
$ cd pipelineGeneFusion

3. run the pipeline:
$ ./../nextflow run fiveProcesses.nf


To exploit Docker:

1. install Docker:
$ sudo apt-get remove docker docker-engine docker.io containerd runc
$ curl -fsSL https://got.docker.com -o get-docker.sh
$ sudo sh get-docker.sh

2 sign-in Docker-Hub:
$ sudo docker login -u <username>

3. pull the images:
$ sudo docker pull federicacitarrella/dockertest:image1
$ sudo docker pull federicacitarrella/dockertest:image2

3. run the pipeline:
$ ./../nextflow run fiveProcesses.nf -with-docker federicacitarrella/dockertest:image1 federicacitarrella/dockertest:image2

modifica prova