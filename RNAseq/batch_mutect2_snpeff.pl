#!/usr/bin/perl

use strict;
use File::Spec;
use Data::Dumper;
use Cwd;

my $root    = getcwd;
my $bamroot  = "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/khosrotehrani_rna/star";

my $threads = 1;
my $ref     = "/dmf/uqdi/Genomic_Medicine/Fink_Group/genomes/hs37d5/hs37d5.fa";
my $dbsnp   = "/dmf/uqdi/Genomic_Medicine/Fink_Group/genomes/hs37d5/dbSNP_All.human_9606_b144_hs37.vcf";
my $cosmic  = "/dmf/uqdi/Genomic_Medicine/Fink_Group/genomes/hs37d5/hs37_cosmic_v73_20150908_codingandnoncoding.vcf";
my $vcf100g     = "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/1000genomes/ALL.wgs.phase3_shapeit2_mvncall_integrated_v5b.20130502.sites.vcf";

my $template      = qq{#PBS -l walltime=10:00:00
#PBS -l ncpus=$threads
#PBS -l mem=40GB,vmem=40GB
#PBS -N snpeff_mutect2
#PBS -j oe

set -e 

module load zlib/1.2.8
module load Java/1.8.0_66

cd $root/<SAMPLE>

echo "annotate with snpeff"

/dmf/uqdi/Core_Services/UQCCG/Software/sw/snpeff/4.1l/bin/snpEff ann -v -stats <SAMPLE>.snpeff.html GRCh37.75 <VCF> > <OUT>

};

my @files   = `find $bamroot -name "*_star.bam"`;
print Dumper @files; 

my $count = 0; 

foreach my $file (@files) {

    chomp $file;

    my ($v, $d, $f) = File::Spec->splitpath($file);

    print STDERR "Parsing $f\n";

    $f =~ /(.+)_star.bam/;
    #$f          =~ /(.+)\.mutect/;
    #print STDERR "Sample $1\n";
    my $sample  = $1;
    my $dir     =   File::Spec->catdir($d,"mutect2/",$sample);
    #print STDERR "Dir $dir\n";

    #check if the calling for this sample has been done
    next unless (-f "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/khosrotehrani_rna/star/mutect2/$sample/$sample.mutect2.vcf");
    #next if ($sample =~ m/345025/);
    next unless ($sample =~ m/348891/);
    #next unless ($sample =~ m/032940-2/);
   
    my $vcf        = $sample.".mutect2".".vcf";
    print STDERR "VCF $vcf\n";

    my $suf = "snpeff_ann.vcf"; # output file suffix
    my $out     = $vcf;
    $out        =~ s/\.vcf//;
    $out        = $out.".".$suf;
    #my $out        = $sample."."."snpeff_ann.vcf";
    print STDERR "Out $out\n";

    #my $filt    = $f;
    #$filt       =~ s/\.vcf/\.keep/;

    my $pbs     = $sample."_mutect2_snpeff.pbs";

    my $script  = $template;
    $script     =~ s/<SAMPLE>/$sample/g;
    #$script    =~ s/<TBAM>/$file/g;
    $script    =~ s/<DIR>/$dir/g;
    $script     =~ s/<VCF>/$vcf/g;
    #$script     =~ s/<VCFILT>/$filt/g;
    $script     =~ s/<OUT>/$out/g;

    open(FH, ">".$pbs) || die "Cannot write $pbs: $!\n";
    print FH $script;
    close(FH);

    print STDERR "Submitting $pbs\n\n";
    #system("qsub $pbs");

    #last;
}
exit(0);







