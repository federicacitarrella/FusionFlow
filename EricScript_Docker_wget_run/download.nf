#!/usr/bin/env nextflow

process download_ericscript {
    
    script:
    """
    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1VENACpUv_81HbIB8xZN0frasrAS7M4SP"
    tar -xf ericscript_db_homosapiens_ensembl84.tar.bz2
    rm ericscript_db_homosapiens_ensembl84.tar.bz2
    mv ericscript_db_homosapiens_ensembl84/data/homo_sapiens /opt/conda/envs/EricScript/share/ericscript-0.5.5-5/lib/data/ 
    """
}

