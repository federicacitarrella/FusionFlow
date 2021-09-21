FROM continuumio/anaconda3

LABEL description="Docker image containing all requirements for ericscript pipeline"

# Install the conda environment
COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a

# Dump the details of the installed packages to a file for posterity
RUN conda env export --name ericscript_0.5.5 > ericscript_0.5.5.yml