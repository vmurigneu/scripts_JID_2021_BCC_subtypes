#!/usr/bin/perl

use strict;
use File::Spec;
use Cwd;

my $root    = $getcwd;

my $threads = 12;
my $fc      = qq{#PBS -l walltime=36:00:00
#PBS -l ncpus=$threads
#PBS -l mem=24GB
#PBS -N htseq
#PBS -j oe

module load python_2.7.6

set -e 

cd $root/<SAMPLE>

htseq-count -r pos -f bam -i gene_name --stranded=no <SAMPLE>.star.bam /dmf/uqdi/Genomic_Medicine/Fink_Group/genomes/hg19/Homo_sapiens.GRCh37.75.gtf > <SAMPLE>_counts.txt

};

my @dirs    = `ls -1d $root`;

foreach (@dirs) {
    chomp $_;

	my @files   = `find $_ -name "*star.bam"`;
	
	my $count = 0;
	foreach my $file (@files) {
	    chomp $file;
	
	    my ($v, $d, $f) = File::Spec->splitpath($file);
	
	    print STDERR "Parsing $f\n";
	    $f   =~ /(.+).star.bam/;
	    #print STDERR "$1 $2 $3 $4\n";
	    #my $prefix  = $1."_".$2."_".$3."_".$4;
	    my $sample  = $1;
	    #my $fastq2  = $d."/".$f;
	    #my $rgid    = join "_", $1, $2, $3; 
	    #$fastq2     =~ s/R1/R2/;
	
	    #print STDERR "PREFIX $prefix\n";
	    #print STDERR "$sample -> $samplename{$sample}\n";
	
        #unless($prefix =~ /C6MFAACXX-6-G02/ ||$prefix =~ /C6MFAACXX-6-H02/) {
        #    print STDERR "$prefix, skipping\n";
        #    next;
       # }

	    my $fname   = $sample."htseq.pbs";
	    my $script  = $fc;
	    #$script     =~ s/<PREFIX>/$prefix/g;
	    $script     =~ s/<THREADS>/$threads/g;
	    #$script     =~ s/<RGID>/$rgid/g;
	    $script     =~ s/<SAMPLE>/$sample/g;
	    #$script     =~ s/<FASTQ1>/$file/g;
	    #$script     =~ s/<FASTQ2>/$fastq2/g;
	    #$script     =~ s/<REFERENCE>/$ref/g;
	
	    open(FH, ">".$fname) || die "Cannot write $fname: $!\n";
	    print FH $script;
	    close(FH);
	
	    print STDERR "Submitting $fname\n\n";
	    system("qsub $fname");
	
	}
}

exit(0);
