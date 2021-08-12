myfile = file( projectDir+'/prova.txt' )

params.range = 100

process perlStuff {
    container 'federicacitarrella/dockertest:image2'

    output:
    stdout result1

    """
    #!/usr/bin/perl

    print ${myfile.text};
    """

}

process pyStuff {
    container 'federicacitarrella/dockertest:image1'

    output:
    stdout result2

    """
    #!/usr/bin/python3

    x = 'Hello'
    y = 'world!'
    print (x+" "+y)
    """

}

process perlTask {
    container 'federicacitarrella/dockertest:image2'

    output:
    stdout into randNums
 
    shell:
    '''
    #!/usr/bin/perl
    use strict;
    use warnings;
 
    my $count;
    my $range = !{params.range};
    for ($count = 0; $count < 10; $count++) {
        print rand($range) . ', ' . rand($range) . "\n";
    }
    '''
}

process pyTask {
    container 'federicacitarrella/dockertest:image1'

    output:
    stdout result3

    """
    #!/usr/bin/python3

    res = "PROVA MAIUSCOLO"
    print(res.lower())
    """

}

process pyTask5 {
    container 'federicacitarrella/dockertest:image1'

    output:
    stdout result4

    """
    #!/usr/bin/python3
    
    string = ${myfile.text}
    lista = string.split("-")
    print(lista[0])
    """

}

result1.view{ it.trim() }
result2.view{ it.trim() }
randNums.view{ it.trim() }
result3.view{ it.trim() }
result4.view{ it.trim() }

