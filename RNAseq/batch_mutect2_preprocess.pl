#!/usr/bin/perl

use strict;
use Data::Dumper;
use File::Spec;
use Cwd;

my $root    = getcwd;

my $threads = 1;
my $ref     = "/dmf/uqdi/Genomic_Medicine/Fink_Group/genomes/hs37d5/hs37d5.fa";
my $dbsnp   = "/dmf/uqdi/Genomic_Medicine/Fink_Group/genomes/hs37d5/dbSNP_All.human_9606_b144_hs37.vcf";
my $cosmic  = "/dmf/uqdi/Genomic_Medicine/Fink_Group/genomes/hs37d5/hs37_cosmic_v73_20150908_codingandnoncoding.vcf";
my $bamroot = "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/khosrotehrani_rna/star";

my $template    = qq{#PBS -l walltime=100:00:00

#PBS -l ncpus=$threads
#PBS -l mem=40GB,vmem=40GB
#PBS -N bccmutect2_preprocessing_BQSR
#PBS -j oe

. /dmf/uqdi/Core_Services/UQCCG/Software/sw/modules/Modules/3.2.10/init/bash

module load samtools
module load R/3.2.1

set -e

cd $root

#mkdir <DIR>

#samtools index <TBAM>

#echo "Marking duplicates"

#java -Djava.io.tmpdir=/lustre/home/tvmurign/picard -jar /dmf/uqdi/Core_Services/UQCCG/Software/sw/picard/1.131/picard.jar MarkDuplicates INPUT=<TBAM> OUTPUT=$bamroot/gatk_files/<PREFIX>.markdup.bam METRICS_FILE=$bamroot/metrics/<PREFIX>.markdup.metrics ASSUME_SORTED=true OPTICAL_DUPLICATE_PIXEL_DISTANCE=100 CREATE_INDEX=true VALIDATION_STRINGENCY=SILENT

#echo "GATK SplitNCigarReads"

#/dmf/uqdi/Core_Services/UQCCG/Software/sw/java/1.7.0_67/bin/java -jar /dmf/uqdi/Core_Services/UQCCG/Software/sw/gatk/3.5/GenomeAnalysisTK.jar \\
#     -T SplitNCigarReads -rf ReassignOneMappingQuality -RMQF 255 -RMQT 60 -U ALLOW_N_CIGAR_READS \\
#     -R $ref \\
#     -I $bamroot/gatk_files/<PREFIX>.markdup.bam \\
#     -o $bamroot/gatk_files/<PREFIX>.split.bam \\

rm $bamroot/gatk_files/<PREFIX>.markdup.bam

echo "Starting base quality recalibration"

# Analyze patterns of covariation in the sequence dataset; ~1 hour
/dmf/uqdi/Core_Services/UQCCG/Software/sw/java/1.7.0_67/bin/java -Djava.io.tmpdir=/lustre/home/tvmurign/picard1 -jar /dmf/uqdi/Core_Services/UQCCG/Software/sw/gatk/3.4/GenomeAnalysisTK.jar \\
-T BaseRecalibrator \\
-R $ref \\
-I $bamroot/gatk_files/<PREFIX>.split.bam \\
-knownSites $dbsnp \\
-o $bamroot/gatk_files/<PREFIX>.recal_data.table

# Do a second pass to analyze covariation remaining after recalibration; ~1 hour
/dmf/uqdi/Core_Services/UQCCG/Software/sw/java/1.7.0_67/bin/java -Djava.io.tmpdir=/lustre/home/tvmurign/picard1 -jar /dmf/uqdi/Core_Services/UQCCG/Software/sw/gatk/3.4/GenomeAnalysisTK.jar \\
-T BaseRecalibrator \\
-R $ref \\
-I $bamroot/gatk_files/<PREFIX>.split.bam \\
-knownSites $dbsnp \\
-BQSR $bamroot/gatk_files/<PREFIX>.recal_data.table \\
-o    $bamroot/gatk_files/<PREFIX>.post_recal_data.table

# Generate before/after plots; minutes
/dmf/uqdi/Core_Services/UQCCG/Software/sw/java/1.7.0_67/bin/java -Djava.io.tmpdir=/lustre/home/tvmurign/picard1 -jar /dmf/uqdi/Core_Services/UQCCG/Software/sw/gatk/3.4/GenomeAnalysisTK.jar \\
-T AnalyzeCovariates \\
-R $ref \\
-before $bamroot/gatk_files/<PREFIX>.recal_data.table \\
-after  $bamroot/gatk_files/<PREFIX>.post_recal_data.table \\
-plots  $bamroot/gatk_files/<PREFIX>.recalibration_plots.pdf \\
-l DEBUG

# Apply the recalibration to your sequence data; ~30m
/dmf/uqdi/Core_Services/UQCCG/Software/sw/java/1.7.0_67/bin/java -Djava.io.tmpdir=/lustre/home/tvmurign/picard1 -jar /dmf/uqdi/Core_Services/UQCCG/Software/sw/gatk/3.4/GenomeAnalysisTK.jar \\
-T PrintReads \\
-R $ref \\
-I $bamroot/gatk_files/<PREFIX>.split.bam \\
-BQSR $bamroot/gatk_files/<PREFIX>.recal_data.table \\
-o $bamroot/gatk_files/<PREFIX>.recal.bam

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

    #check if the preprocessing for this sample has already been done
    #next unless (! -f "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/khosrotehrani_rna/star/mutect2/$prefix/$prefix.snp.vcf");
    #next unless(! -e "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/khosrotehrani_rna/star/gatk_files/$prefix.markdup.bam");
    next if ($prefix =~ m/918030/);
    
    my $tbam    = $file;
    my $out     = $dir."/".$prefix.".mutect2.vcf";

    #print STDERR "VCF $out\n";
    #next unless(-e $root.$tbam && -e $root.$nbam);
    next unless(-e $tbam);
    print STDERR "RUN sample present: $tbam\n";

    my $script  = $template;
    $script     =~ s/<PREFIX>/$prefix/g;
    $script     =~ s/<THREADS>/$threads/g;
    $script     =~ s/<TBAM>/$tbam/g;
    $script     =~ s/<DIR>/$dir/g;
    $script     =~ s/<VCF>/$out/g;
    #$script     =~ s/<BAM>/$out_bam/g;

    my $pbs     = $prefix."_mutect2_preprocess_BQSR.pbs";
    open(FH, ">".$pbs) || die "Cannot write $pbs: $!\n";
    print FH $script;
    close(FH);

    print STDERR "Submitting $pbs\n";
    system("qsub $pbs");

    #last;
}

exit(0);

