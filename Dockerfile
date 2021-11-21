FROM continuumio/anaconda3

LABEL description="Docker image containing all requirements for genefusion pipeline"

RUN apt-get update
RUN apt-get install -y wget
RUN apt-get install unzip
RUN apt-get install make
RUN apt-get install -y build-essential 
RUN apt-get install -y python2
RUN apt-get install -y zlib1g-dev
RUN apt-get install -y libtbb-dev libtbb2 libc6-dev
RUN apt-get install -y libncurses5-dev

RUN apt-get install -y locales
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

RUN pip install gdown

# Install Nextflow
RUN apt update && apt -y install default-jre && apt -y install openjdk-11-jre-headless
RUN curl -s https://get.nextflow.io | bash
RUN cd  /home/ && curl -s https://get.nextflow.io | bash

# Install the conda environment for EricScript
COPY environment_ericscript.yml /
RUN conda env create -f /environment_ericscript.yml && conda clean -a

# Install the conda environment for Arriba
COPY environment_arriba.yml /
RUN conda env create -f /environment_arriba.yml && conda clean -a

# Install the conda environment for FusionCatcher
COPY environment_fusioncatcher.yml /
RUN conda env create -f /environment_fusioncatcher.yml && conda clean -a

RUN wget https://github.com/ndaniel/fastqtk/archive/refs/tags/v0.27.zip
RUN unzip v0.27.zip && rm v0.27.zip
WORKDIR fastqtk-0.27 
RUN make
RUN mv fastqtk /opt/conda/envs/fusioncatcher/bin/ && cd ..
WORKDIR /home

# Install the conda environment for INTEGRATE
COPY environment_integrate.yml /
RUN conda env create -f /environment_integrate.yml && conda clean -a

RUN wget https://ccb.jhu.edu/software/tophat/downloads/tophat-2.1.1.Linux_x86_64.tar.gz
RUN tar -xvzf tophat-2.1.1.Linux_x86_64.tar.gz
RUN rm tophat-2.1.1.Linux_x86_64.tar.gz && rm tophat-2.1.1.Linux_x86_64/tophat
RUN cp -r tophat-2.1.1.Linux_x86_64/* /opt/conda/envs/integrate/bin/

RUN gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1A4JyTwjnwqDjWqVuEgt1sfDQrwU3oNbv"
RUN chmod +x tophat
RUN mv tophat /opt/conda/envs/integrate/bin/

# Install the conda environment for GeneFuse
COPY environment_genefuse.yml /
RUN conda env create -f /environment_genefuse.yml && conda clean -a
