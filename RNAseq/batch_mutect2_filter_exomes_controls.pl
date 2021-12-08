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

my $template      = qq{#PBS -l walltime=50:00:00
#PBS -l ncpus=$threads
#PBS -l mem=20GB,vmem=20GB
#PBS -N filter_exomes_controls
#PBS -j oe

set -e 

. /dmf/uqdi/Core_Services/UQCCG/Software/sw/modules/Modules/3.2.10/init/bash

module load zlib/1.2.8

module load samtools
module load vcftools/0.1.12b
module load java/1.8.0_25

cd $root/<SAMPLE>

#echo "sample filtering for mutect2"

/dmf/uqdi/Core_Services/UQCCG/Software/sw/java/1.8.0_25/bin/java -jar /dmf/uqdi/Core_Services/UQCCG/Software/sw/gatk/3.6/GenomeAnalysisTK.jar \\
   -R $ref \\
   -T VariantAnnotator \\
   -o <VCFILT> \\
   --resource:exome_normal <VCF_exome_normal> \\
   --expression exome_normal.AF \\
   --expression exome_normal.FILTER \\
   -V <OUT> \\

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
    #next unless (-f "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/khosrotehrani_rna/star/varscan/$sample/$sample.snp.vcf");
    #next unless ($sample =~ m/376326-1/);
    #next unless ($sample =~ m/032940-2/);
   
    my $vcf        = $sample.".mutect2.vcf";
    print STDERR "VCF $vcf\n"; 

    #my $suf = "snpeff_ann.vcf"; # output file suffix
    #my $out     = $f;
    #$out        =~ s/\.vcf//;
    my $out        = $sample.".mutect2.snpeff_ann.vcf";
    print STDERR "Out $out\n";

    my $filt = $sample.".mutect2.snpeff_ann.filtA.vcf";
    print STDERR "filt $filt\n";

    #check if an exome control is found for this sample in the format: normal sample=1140662; tumor sample = 1140662-2
    my @prefix = split /-/, $sample; 
    my $prefix_sample= $prefix[0];
    print Dumper \@prefix;

    #next unless (-f "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/khosrotehrani_exomes/genotype/".$prefix_sample."A.g.vcf");
    next unless (-f "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/khosrotehrani_exomes/genotype/".$prefix_sample."A.g.vcf");
    my $vcf_exome_normal = "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/khosrotehrani_exomes/genotype/".$prefix_sample."A.g.vcf";
    #skip already done
    next if (-f "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/khosrotehrani_rna/star/mutect2/".$sample."/".$filt);

    my $pbs     = $sample."_varscan_filter_exomes_controls.pbs";

    my $script  = $template;
    $script     =~ s/<SAMPLE>/$sample/g;
    #$script    =~ s/<TBAM>/$file/g;
    $script    =~ s/<DIR>/$dir/g;
    $script     =~ s/<VCF>/$vcf/g;
    $script     =~ s/<VCFILT>/$filt/g;
    $script     =~ s/<OUT>/$out/g;
    $script     =~ s/<VCF_exome_normal>/$vcf_exome_normal/g;

    open(FH, ">".$pbs) || die "Cannot write $pbs: $!\n";
    print FH $script;
    close(FH);

    print STDERR "Submitting $pbs\n\n";
    #system("qsub $pbs");

    #last;
}
exit(0);







