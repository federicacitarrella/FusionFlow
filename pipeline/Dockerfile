FROM continuumio/anaconda3

LABEL description="Docker image containing all requirements for genefusion pipeline"

# Install Nextflow
RUN apt update && apt -y install default-jre && apt -y install openjdk-11-jre-headless
RUN curl -s https://get.nextflow.io | bash
RUN cd  /home/ && curl -s https://get.nextflow.io | bash

# Install the conda environment for EricScript
COPY environment_EricScript.yml /
RUN conda env create -f /environment_EricScript.yml && conda clean -a

# Install the conda environment for EricScript
COPY environment_Arriba.yml /
RUN conda env create -f /environment_Arriba.yml && conda clean -a

# Dump the details of the installed packages to a file for posterity
# RUN conda env export --name ericscript_0.5.5 > ericscript_0.5.5.yml
