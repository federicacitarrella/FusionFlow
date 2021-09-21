#!/usr/bin/env nextflow

def helpMessage() {
    log.info"""

    Usage:

    The typical command for running the pipeline is as follows:

    nextflow run nf-core/rnafusion --reads '*_R{1,2}.fastq.gz' -profile docker

    Mandatory arguments:
      --reads [file]                Path to input data (must be surrounded with quotes)
      -profile [str]                Configuration profile to use.
                                    Available: docker and test
    """.stripIndent()
}

// Show help message
if (params.help) {
    helpMessage()
    exit 0
}

dbFile = file(params.db)

params.skip= dbFile.exists()

Channel
    .fromPath( params.reads )
    .ifEmpty { error "Cannot find any reads matching: ${params.reads}" }
    .map { path -> 
       def prefix = readPrefix(path, params.reads)
       tuple(prefix, path) 
    }
    .groupTuple(sort: true)
    .set { read_files } 

Channel.fromPath(params.db).set{ input_ch }

(foo_ch, bar_ch) = ( params.skip
                 ? [Channel.empty(), input_ch]
                 : [input_ch, Channel.empty()] )

process downloader_ericsctipt{

    input:
    val x from foo_ch

    output:
    file "ericscript_db_homosapiens_ensembl84" into ch2
    
    """
    #!/bin/bash
    export PATH="${params.envPath}:$PATH"
    gdown "https://drive.google.com/uc?export=download&confirm=qgOc&id=1VENACpUv_81HbIB8xZN0frasrAS7M4SP"
    tar -xf ericscript_db_homosapiens_ensembl84.tar.bz2
    """

}

process ericscript{

    input:
    file ericscript_db from bar_ch.mix(ch2)
    set val(name), file(reads:'*') from read_files

    output:
    file "EricScript_output" optional true into ericscript_fusions

    """
    #!/bin/bash
    export PATH="${params.envPath}:$PATH"
    ericscript.pl -o ./EricScript_output -db $ericscript_db/ ${reads}
    """

}

def readPrefix( Path actual, template ) {

    final fileName = actual.getFileName().toString()

    def filePattern = template.toString()
    int p = filePattern.lastIndexOf('/')
    if( p != -1 ) filePattern = filePattern.substring(p+1)
    if( !filePattern.contains('*') && !filePattern.contains('?') ) 
        filePattern = '*' + filePattern 
  
    def regex = filePattern
                    .replace('.','\\.')
                    .replace('*','(.*)')
                    .replace('?','(.?)')
                    .replace('{','(?:')
                    .replace('}',')')
                    .replace(',','|')

    def matcher = (fileName =~ /$regex/)
    if( matcher.matches() ) {  
        def end = matcher.end(matcher.groupCount() )      
        def prefix = fileName.substring(0,end)
        while(prefix.endsWith('-') || prefix.endsWith('_') || prefix.endsWith('.') ) 
          prefix=prefix[0..-2]
          
        return prefix
    }
    
    return fileName
}