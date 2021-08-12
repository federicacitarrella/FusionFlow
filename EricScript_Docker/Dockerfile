FROM continuumio/anaconda3

RUN conda update -n base -c defaults conda
RUN conda create -y --name EricScript
RUN conda install -y -c bioconda ericscript
RUN chmod +x /opt/conda/envs/EricScript/bin/ericscript.pl
RUN cd  /home/ && curl -s https://get.nextflow.io | bash

ADD /home/federica/Downloads/ericscript_db_homosapiens_ensembl84/data/homo_sapiens /opt/conda/envs/EricScript/share/ericscript-0.5.5-5/lib/data/
ADD /home/federica/sample /home/
ADD /home/federica/pipeline.nf /home/

CMD ["./nextflow pipeline.nf --in1 '/home/sample/SRR064286_1.fastq' --in2 '/home/sample/SRR064286_2.fastq'"]
