#!/usr/bin/perl

use strict;
use Cwd;
use Data::Dumper;

my $root    = getcwd;

=cut
FCID,Side_Version,Lane,Sample_ID,Sample_Code,Project,UIN,Pool_ID,Capture_ID,Library_ID,Well_Location,Sample_Plate,Description,Species,Reference,Library_Type,Capture_Type
H3GT5BBXX,4000,1,H3GT5BBXX-1-01,689687,20150803_Khosrotehrani,20150820-0005,TruP-20151009-0005,None,TruR-20151006-0001,A07,TSP1-20150918-2-Khos,151013_ST-K00108_0027_BH3GT5BBXX-1-01,Human,None,Tr
uRT1,None
H3GT5BBXX,4000,1,H3GT5BBXX-1-02,886667,20150803_Khosrotehrani,20150820-0006,TruP-20151009-0005,None,TruR-20151006-0002,B07,TSP1-20150918-2-Khos,151013_ST-K00108_0027_BH3GT5BBXX-1-02,Human,None,Tr
uRT1,None
H3GT5BBXX,4000,1,H3GT5BBXX-1-03,1013089,20150803_Khosrotehrani,20150820-0007,TruP-20151009-0005,None,TruR-20151006-0003,C07,TSP1-20150918-2-Khos,151013_ST-K00108_0027_BH3GT5BBXX-1-03,Human,None,T
ruRT1,None
=cut

my $template    = qq{#PBS -l walltime=20:00:00
#PBS -l ncpus=1
#PBS -l mem=20GB
#PBS -N <PREFIX>merge
#PBS -j oe

set -e

module load samtools

cd $root

java -jar /dmf/uqdi/Core_Services/UQCCG/Software/sw/picard/1.140/picard.jar MergeSamFiles \\
<BAMLIST> OUTPUT=<PREFIX>_star.bam

samtools index <PREFIX>_star.bam
};

my %sample2lane = ();
my $ssheet      = "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/khosrotehrani_rna/fastq/20150803_Khosrotehrani/151013_ST-K00108_0027_BH3GT5BBXX.runsheet.csv";

open(FH, $ssheet) || die;
while(<FH>) {
    next if(/^FCID/);

    my @f   = split /,/;

    push @{$sample2lane{$f[4]}}, $f[3];
}
close(FH);

#H3GT5BBXX-1-01/H3GT5BBXX-1-01.star.bam

foreach my $prefix (keys %sample2lane) {
    my @lanes   = @{$sample2lane{$prefix}};

    my $bamlist = "";
    foreach my $l (@lanes) {
        $bamlist    .= "I=".$prefix."/".$l.".star.bam ";
    }

    my $fname   = $prefix."_merge.pbs";
    my $script  = $template;
    $script     =~ s/<PREFIX>/$prefix/g;
    $script     =~ s/<BAMLIST>/$bamlist/g;

    open(FH, ">".$fname) || die "Cannot write $fname: $!\n";
    print FH $script;
    close(FH);

    print STDERR "Submitting $fname\n\n";
    #system("qsub $fname"); 
    #last;
}

exit(0);

