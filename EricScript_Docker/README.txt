To download the sample, install sra-tools (with conda type $ conda install -c bioconda sra-tools). 

Then use the following commands:

$ mkdir sample
$ cd sample
$ fastq-dump --split-files <ID_file>

(ID_file example: SRR064286)
