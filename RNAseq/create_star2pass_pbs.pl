#!/usr/bin/perl

use strict;
use File::Spec;
use Data::Dumper;

my $ssheet      = "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/khosrotehrani_rna/fastq/20150803_Khosrotehrani/151013_ST-K00108_0027_BH3GT5BBXX.runsheet.csv";
#FCID,Side_Version,Lane,Sample_ID,Sample_Code,Project,UIN,Pool_ID,Capture_ID,Library_ID,Well_Location,Sample_Plate,Description,Species,Reference,Library_Type,Capture_Type
#H3GT5BBXX,4000,1,H3GT5BBXX-1-01,689687,20150803_Khosrotehrani,20150820-0005,TruP-20151009-0005,None,TruR-20151006-0001,A07,TSP1-20150918-2-Khos,151013_ST-K00108_0027_BH3GT5BBXX-1-01,Human,None,TruRT1,None
my %lane2sample = ();
open(FH, $ssheet) || die;
while(<FH>) {
    chomp;
    next if(/FCID/);

    my @f   = split /,/;

    $f[4]   =~ s/ /\_/g;

    $lane2sample{$f[3]} = $f[4];
}
close(FH);
#print Dumper %lane2sample;

my $rootdir     = "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/khosrotehrani_rna/fastq/20150803_Khosrotehrani/";
my $starroot     = "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/khosrotehrani_rna/star2pass/";
my $outroot     = "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/khosrotehrani_rna/star2pass";
my $starbin     = "/dmf/uqdi/Genomic_Medicine/Fink_Group/software/star/2.5.2b/STAR/bin/Linux_x86_64";
my $genome      = "/dmf/uqdi/Genomic_Medicine/Fink_Group/genomes/hs37d5/hs37_starindex_E85/";

my @files 	    = `find $rootdir -name "*R1_001.fastq.gz"`;

# 240GB, 8 nodes for STAR
my $template	= qq{#PBS -l walltime=50:00:00
#PBS -l mem=600GB,vmem=600GB
#PBS -l nodes=1
#PBS -l ncpus=12
#PBS -N star2pass
#PBS -j oe

set -e

module load samtools

#mkdir $outroot/<PREFIX>

cd  $outroot/<PREFIX>

$starbin/STAR --outFileNamePrefix ./<PREFIX2>. --readFilesIn <FASTQ1> <FASTQ2> --genomeDir $genome --parametersFiles ../star_params.in --readFilesCommand zcat

samtools index ./<PREFIX2>.Aligned.sortedByCoord.out.bam

java -jar /dmf/uqdi/Core_Services/UQCCG/Software/sw/picard/1.140/picard.jar AddOrReplaceReadGroups \\
INPUT=./<PREFIX2>.Aligned.sortedByCoord.out.bam OUTPUT=./<PREFIX2>.star.bam RGID=<READGROUP> RGPL=ILLUMINA RGSM=<PREFIX> RGCN=UQCCG RGLB=<PREFIX2> \\
RGPU=<PREFIX2> SORT_ORDER=coordinate

samtools index ./<PREFIX2>.star.bam

rm ./<PREFIX2>.Aligned.sortedByCoord.out.bam
rm ./<PREFIX2>.Aligned.sortedByCoord.out.bam.bai

};

my $count    = 0;
foreach my $file (@files)  {
    chomp $file;

    print STDERR "$file\n";

    my ($v, $d, $f) = File::Spec->splitpath($file);

    $d          =~ s/^.+\/(.+?)\//$1/;
    my $run     = $lane2sample{$d};

	my $file1	= $f;

    #my $prefix  = $file1;
    #$prefix     =~ s/\_R1\_001\.fastq\.gz//;

    my $f2      = $file;
    $f2         =~ s/\_R1\_/\_R2\_/;

    my $run     = $lane2sample{$d};

    next if(-e "$run/$d.star.bam");

	my $tmp		= $template;
	$tmp		=~ s/<PREFIX>/$run/g;
	$tmp		=~ s/<PREFIX2>/$d/g;
	$tmp		=~ s/<FASTQ1>/$file/g;
	$tmp		=~ s/<FASTQ2>/$f2/g;
        $tmp        =~ s/<READGROUP>/$d/g;

	my $script	= $d."_star2pass.pbs";
	print STDERR "Writing    $script\n";
	open(FH, ">".$script) || die "Cannot create $script: $!";
	print FH $tmp;
	close(FH);

	print STDERR "Submitting $script\n";
	my $cmd		= "qsub $script";
	system($cmd);

    #last if($count++ > 10);
    #last;
}

