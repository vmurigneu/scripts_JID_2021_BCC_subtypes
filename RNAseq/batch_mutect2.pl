#!/usr/bin/perl

use strict;
use Data::Dumper;
use File::Spec;
use Cwd;

my $root    = "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/khosrotehrani_rna/star/mutect2";

my $threads = 8;
my $ref     = "/dmf/uqdi/Genomic_Medicine/Fink_Group/genomes/hs37d5/hs37d5.fa";
my $dbsnp   = "/dmf/uqdi/Genomic_Medicine/Fink_Group/genomes/hs37d5/dbSNP_All.human_9606_b144_hs37.vcf";
my $cosmic  = "/dmf/uqdi/Genomic_Medicine/Fink_Group/genomes/hs37d5/hs37_cosmic_v73_20150908_codingandnoncoding.vcf";
my $bamroot = "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/khosrotehrani_rna/star";

my $template    = qq{#PBS -l walltime=100:00:00

#PBS -l ncpus=$threads
#PBS -l mem=40GB,vmem=40GB
#PBS -N bccmutect2
#PBS -j oe

. /dmf/uqdi/Core_Services/UQCCG/Software/sw/modules/Modules/3.2.10/init/bash

module load samtools
module load R/3.2.1
module load java/1.8.0_25

mkdir <DIR>

cd <DIR>

echo "Running Mutect2"

/dmf/uqdi/Core_Services/UQCCG/Software/sw/java/1.8.0_25/bin/java -jar /dmf/uqdi/Core_Services/UQCCG/Software/sw/gatk/3.6/GenomeAnalysisTK.jar \\
     -nct      $threads \\
     -T        MuTect2 \\
     -R        $ref \\
     -I:tumor  $bamroot/gatk_files/<PREFIX>.recal.bam \\
     --dbsnp   $dbsnp \\
     --cosmic  $cosmic \\
     --artifact_detection_mode \\
     -o        <VCF>
};

my @files   = `find $bamroot -name "*_star.bam"`;
#my @files   = `find ../ -maxdepth 1 -name "*.bam"`;
print Dumper @files;

my $count = 0;
foreach my $file (@files) {

    chomp $file;

    my ($v, $d, $f) = File::Spec->splitpath($file);

    print STDERR "Parsing $f\n";

    $f =~ /(.+)_star.bam/;
    #print STDERR "Sample $1\n";
    my $sample  = $1;
    my $prefix  = $sample;
    my $dir     =   File::Spec->catdir($d,"mutect2/",$prefix);
    #print STDERR "Dir $dir\n";

    #check if the calling for this sample has already been done
    next unless (! -f "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/khosrotehrani_rna/star/mutect2/$prefix/$prefix.vcf");
    #next unless(! -e "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/khosrotehrani_rna/star/mutect2/$prefix");
    
    my $tbam    = $file;
    #print  STDERR $bamroot."/gatk_files/".$prefix.".split.bam\n";
    my $out     = $dir."/".$prefix.".mutect2.vcf";
    #print STDERR "VCF $out\n";
    #next unless(-e $root.$tbam && -e $root.$nbam);
    #check if star mapping and mutect2 preprocessing has been done
    next unless(-e $tbam && -e $bamroot."/gatk_files/".$prefix.".recal.bam");
    #print STDERR "RUN sample present: $tbam\n";

    #next if ($prefix =~ m/008645/);
    next if (-e $out);

    my $script  = $template;
    $script     =~ s/<PREFIX>/$prefix/g;
    $script     =~ s/<THREADS>/$threads/g;
    $script     =~ s/<TBAM>/$tbam/g;
    $script     =~ s/<DIR>/$dir/g;
    $script     =~ s/<VCF>/$out/g;

    my $pbs     = $prefix."_mutect2.pbs";
    open(FH, ">".$pbs) || die "Cannot write $pbs: $!\n";
    print FH $script;
    close(FH);

    print STDERR "Submitting $pbs\n";
    system("qsub $pbs");

    #last;
}

exit(0);

