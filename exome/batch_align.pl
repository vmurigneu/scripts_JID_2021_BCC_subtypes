#!/usr/bin/perl

use strict;
use File::Spec;
use Data::Dumper;
use Cwd;

my $root    = getcwd;
my $fqroot  = "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/u_geneve_exomes/fastq/";

my $threads = 24;
my $ref     = "/dmf/uqdi/Genomic_Medicine/Fink_Group/genomes/hs37d5/hs37d5index.nix";

my $fc      = qq{#PBS -l walltime=200:00:00
#PBS -l ncpus=<THREADS>
#PBS -l mem=20GB
#PBS -N novo_round2
#PBS -j oe

set -e 

module load samtools

cd $root

/dmf/uqdi/Core_Services/UQCCG/Software/sw/novoalign/3.02.08/bin/novoalign -d $ref -f <FQ1> <FQ2> -o SAM -k -K <PREFIX>_qualCounts.txt -r A 1  -F STDFQ -o SoftClip -c <THREADS> | samtools view -bhS - > <PREFIX>_unsorted_novo.bam

echo "Novoalign complete"

samtools sort <PREFIX>_unsorted_novo.bam <PREFIX>_norg

echo "Sorting complete"

rm <PREFIX>_unsorted_novo.bam

samtools index <PREFIX>_norg.bam

java -jar /dmf/uqdi/Core_Services/UQCCG/Software/sw/picard/1.131/picard.jar AddOrReplaceReadGroups INPUT=<PREFIX>_norg.bam OUTPUT=<PREFIX>.bam SORT_ORDER=coordinate \\
RGID="<PREFIX>" RGLB="<PREFIX>" RGPL=ILLUMINA RGPU=<PU> RGSM="<PREFIX>" RGCN=UGeneve RGPI=200

samtools index <PREFIX>.bam

rm <PREFIX>_norg.bam

rm <PREFIX>_norg.bam.bai

};

#_EGAR00001384587_5-VS098-N1_1.fastq.gz
#_EGAR00001384587_5-VS098-N1_2.fastq.gz
=cut
grep 5-VS098-N1  metadata/EGAD00001001857/delimited_maps/Sample_File.map
5-VS098-N1RNA   EGAN00001344045 5-VS098-N1RNA_1.fastq.gz.cip    EGAF00000933366
5-VS098-N1RNA   EGAN00001344045 5-VS098-N1RNA_2.fastq.gz.cip    EGAF00000933367
5-VS098-N1  EGAN00001344044 5-VS098-N1_1.fastq.gz.cip   EGAF00000933714
5-VS098-N1  EGAN00001344044 5-VS098-N1_2.fastq.gz.cip   EGAF00000933715
=cut

#my @files   = `find $fqroot -name "*_1.fastq.gz"`;

#round2 of mapping with files ending *_R1.fastq.gz = 19 samples
=cut
5-VS043-T1	EGAN00001343830	5-VS043-T1_R1.fastq.gz.cip	EGAF00000933552
5-VS043-T1	EGAN00001343830	5-VS043-T1_R2.fastq.gz.cip	EGAF00000933553
5-VS043-N1	EGAN00001344009	5-VS043-N1_R1.fastq.gz.cip	EGAF00000933866
5-VS043-N1	EGAN00001344009	5-VS043-N1_R2.fastq.gz.cip	EGAF00000933867
=cut

my @files   = `find $fqroot -name "*_1.fastq.gz"`;
print Dumper @files;

my $count = 0;
foreach my $file (@files) {
    next if($file =~ /RNA/);

    chomp $file;

    my ($v, $d, $f) = File::Spec->splitpath($file);

    print STDERR "Parsing $f\n";

    my $fq1  = $f;
    my $fq2 = $f;
    $fq2    =~ s/_1\.f/_2\.f/;
    # FQ files with path
    my $f2  = $file;
    $f2     =~ s/_1\.f/_2\.f/;

    #_EGAR00001384587_5-VS098-N1_1.fastq.gz
    $f =~ /^\_EGA.+?\_(.+?)\_\d\.fa/;
    print STDERR "Sample $1\n";
    my $sample  = $1;
    my $prefix  = $sample;
    my $pu      = "EGA";
    my $fcid    = "EGA";
    my $fastq2  = $d."/".$f;
    $fastq2     =~ s/1\.f/2\.f/;

    #check if the fq2 file exists
    my @hasfq2 = `ls $fastq2`;
    next unless(scalar(@hasfq2) == 1);

    #check if the mapping for this sample has already been done
    next unless (! -f "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/u_geneve_exomes/$prefix.bam");
    #next if($prefix =~ /5-NB007-N1/);

    # check to see if this file is for exome sequencing; if not, skip it (for now)
    my @wxs     = `grep $sample metadata/EGAD00001001857/delimited_maps/Study_Experiment_Run_sample.map | grep WXS`;
    #print Dumper @wxs;
    unless(scalar(@wxs) == 1) {
        #print STDERR "Not exome data, skipping\n";
        next;
    }

    my $fname   = $prefix."_novoalign_round2.pbs";
    my $script  = $fc;
    $script     =~ s/<PREFIX>/$prefix/g;
    $script     =~ s/<THREADS>/$threads/g;
    $script     =~ s/<FQ1>/$file/g;
    $script     =~ s/<FQ2>/$f2/g;
    $script     =~ s/<REFERENCE>/$ref/g;
    $script     =~ s/<MEAN_IS>/200/g;
    $script     =~ s/<SD_IS>/50/g;
    $script     =~ s/<PU>/$pu/g;
    $script     =~ s/<TAG>/$prefix/g;
    $script     =~ s/<ORIGDIR>/$d/g;

    open(FH, ">".$fname) || die "Cannot write $fname: $!\n";
    print FH $script;
    close(FH);

    print STDERR "Submitting $fname\n\n";
    #system("qsub $fname");

    #last if($count++ > 10);
}
exit(0);

