FROM ubuntu
LABEL maintainer "gianpaolo bontempo"

# Let's start with some basic stuff.
RUN apt-get update -qq && apt-get install -qqy \
    apt-transport-https \
    ca-certificates \
    curl \
    lxc \
    iptables
    
# Install Docker from Docker Inc. repositories.
RUN curl -sSL https://get.docker.com/ | sh

# Install the magic wrapper.
ADD ./wrapdocker /usr/local/bin/wrapdocker
RUN chmod +x /usr/local/bin/wrapdocker


RUN apt update && apt -y install git

RUN apt update && apt -y install default-jre && apt -y install openjdk-11-jre-headless


RUN curl -s https://get.nextflow.io | bash

RUN cd  /home/ && curl -s https://get.nextflow.io | bash

RUN mkdir /home/pipelineGeneFusion
WORKDIR /home/pipelineGeneFusion

# Define additional metadata for our image.
VOLUME /var/lib/docker
CMD ["wrapdocker"]




