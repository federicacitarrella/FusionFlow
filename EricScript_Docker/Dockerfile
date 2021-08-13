FROM continuumio/anaconda3

RUN apt-get update -qq && apt-get install -qqy \
    apt-transport-https \
    ca-certificates \
    curl \
    lxc \
    iptables

RUN apt update && apt -y install git

RUN apt update && apt -y install default-jre && apt -y install openjdk-11-jre-headless

RUN conda update -n base -c defaults conda
RUN conda create -y --name EricScript
RUN conda install -y -c bioconda ericscript
RUN chmod +x /opt/conda/envs/EricScript/bin/ericscript.pl
RUN cd  /home/ && curl -s https://get.nextflow.io | bash

ADD /home/federica/Downloads/ericscript_db_homosapiens_ensembl84/data/homo_sapiens /opt/conda/envs/EricScript/share/ericscript-0.5.5-5/lib/data/
ADD /home/federica/sample /home/
ADD /home/federica/pipeline.nf /home/
