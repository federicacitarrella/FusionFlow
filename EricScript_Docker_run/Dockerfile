FROM continuumio/anaconda3
LABEL maintainer "gianpaolo bontempo"

# Let's start with some basic stuff.
RUN apt-get update -qq && apt-get install -qqy \
    apt-transport-https \
    ca-certificates \
    curl \
    lxc \
    iptables
    
RUN apt update && apt -y install git
RUN mkdir -p /usr/share/man/man1
RUN apt update && apt -y install default-jre && apt -y install openjdk-11-jre-headless
RUN curl -s https://get.nextflow.io | bash
RUN cd  /home/ && curl -s https://get.nextflow.io | bash




RUN mkdir /home/pipelineGeneFusion
WORKDIR /home/pipelineGeneFusion

RUN conda update -n base -c defaults conda
RUN conda create -y --name EricScript 

# Make RUN commands use the new environment:
SHELL ["conda", "run", "-n", "EricScript", "/bin/bash", "-c"]

RUN conda install -y -c bioconda ericscript

RUN chmod +x /opt/conda/envs/EricScript/bin/ericscript.pl

ADD homo_sapiens /opt/conda/envs/EricScript/share/ericscript-0.5.5-5/lib/data/
ADD sample /home/pipelineGeneFusion
ADD pipeline.nf /home/pipelineGeneFusion

#CMD ["bash"]
CMD ./../nextflow pipeline.nf --in1 '/home/pipelineGeneFusion/sample/SRR064286_1.fastq' --in2 '/home/pipelineGeneFusion/sample/SRR064286_2.fastq'
