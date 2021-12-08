#!/usr/bin/perl

use strict;
use Cwd;

my $root    = getcwd;
#/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/u_geneve_exomes
my @files   = `find . -maxdepth 1 -name "*.bam"`;

my $threads = 1;
my $ref     = "/dmf/uqdi/Genomic_Medicine/Fink_Group/genomes/hs37d5/hs37d5.fa";
my $dbsnp   = "/dmf/uqdi/Genomic_Medicine/Fink_Group/genomes/hs37d5/dbSNP_All.human_9606_b144_hs37.vcf";

my $fc      = qq{#PBS -l walltime=72:00:00
#PBS -l mem=40GB
#PBS -l ncpus=$threads
#PBS -N postalign
#PBS -j oe

cd $root

set -e

. /dmf/uqdi/Core_Services/UQCCG/Software/sw/modules/Modules/3.2.10/init/bash

module load R/3.2.1
module load samtools

#samtools index <BAM>

echo "Marking duplicates"

java -Djava.io.tmpdir=/lustre/home/tvmurign/picard1 -jar /dmf/uqdi/Core_Services/UQCCG/Software/sw/picard/1.131/picard.jar MarkDuplicates INPUT=<BAM> OUTPUT=<PREFIX>_markdup.bam METRICS_FILE=metrics/<PREFIX>_markdup.metrics ASSUME_SORTED=true OPTICAL_DUPLICATE_PIXEL_DISTANCE=100

samtools index <PREFIX>_markdup.bam

echo "Starting base quality recalibration"

# Analyze patterns of covariation in the sequence dataset; ~1 hour
/dmf/uqdi/Core_Services/UQCCG/Software/sw/java/1.7.0_67/bin/java -Djava.io.tmpdir=/lustre/home/tvmurign/picard1 -jar /dmf/uqdi/Core_Services/UQCCG/Software/sw/gatk/3.4/GenomeAnalysisTK.jar \\
-T BaseRecalibrator \\
-R $ref \\
-I <PREFIX>_markdup.bam \\
-knownSites $dbsnp \\
-o gatk_files/<PREFIX>.recal_data.table

# Do a second pass to analyze covariation remaining after recalibration; ~1 hour
/dmf/uqdi/Core_Services/UQCCG/Software/sw/java/1.7.0_67/bin/java -Djava.io.tmpdir=/lustre/home/tvmurign/picard1 -jar /dmf/uqdi/Core_Services/UQCCG/Software/sw/gatk/3.4/GenomeAnalysisTK.jar \\
-T BaseRecalibrator \\
-R $ref \\
-I <PREFIX>_markdup.bam \\
-knownSites $dbsnp \\
-BQSR gatk_files/<PREFIX>.recal_data.table \\
-o    gatk_files/<PREFIX>.post_recal_data.table

# Generate before/after plots; minutes
/dmf/uqdi/Core_Services/UQCCG/Software/sw/java/1.7.0_67/bin/java -Djava.io.tmpdir=/lustre/home/tvmurign/picard1 -jar /dmf/uqdi/Core_Services/UQCCG/Software/sw/gatk/3.4/GenomeAnalysisTK.jar \\
-T AnalyzeCovariates \\
-R $ref \\
-before gatk_files/<PREFIX>.recal_data.table \\
-after  gatk_files/<PREFIX>.post_recal_data.table \\
-plots  gatk_files/<PREFIX>.recalibration_plots.pdf \\
-l DEBUG

# Apply the recalibration to your sequence data; ~30m
/dmf/uqdi/Core_Services/UQCCG/Software/sw/java/1.7.0_67/bin/java -Djava.io.tmpdir=/lustre/home/tvmurign/picard1 -jar /dmf/uqdi/Core_Services/UQCCG/Software/sw/gatk/3.4/GenomeAnalysisTK.jar \\
-T PrintReads \\
-R $ref \\
-I <PREFIX>_markdup.bam \\
-BQSR gatk_files/<PREFIX>.recal_data.table \\
-o <BAM>

#samtools index <BAM>

#rm <PREFIX>_markdup.bam
};

my $count = 0;
foreach (@files) {
    chomp;

    #next if(/novo/);
    #next if(/norg/);
    next if(/markdup/);
    #next if(/realign/);
    #next if(/recal/);
    #next if(/unsort/);
    #next if(/norg\.0/);
    
    s/^\.\///;

    print STDERR "Parsing $_\n";
    /(.+?)\.bam/;
    my $prefix  = $1;
    #print STDERR "PREFIX: $prefix\n";

    #check if the novoalign mapping for this sample has been successful
    next unless (-f "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/u_geneve_exomes/$prefix.bam.bai");
    #next if ($prefix =~ m/5-VS013-N1/);
    #next if ($prefix =~ m/5-VS003-T1/);
    #skip already processed samples
    next if (-f "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/u_geneve_exomes/gatk_files/$prefix.recalibration_plots.pdf");
    #next if ($prefix =~ m/T1/);

    my $fname   = $prefix."_postalign.pbs";
    my $script  = $fc;
    $script     =~ s/<BAM>/$_/g;
    $script     =~ s/<PREFIX>/$prefix/g;

    open(FH, ">".$fname) || die "Cannot write $fname: $!\n";
    print FH $script;
    close(FH);

    print STDERR "Submitting $fname\n\n";
    #system("qsub $fname");

    #last;
}

exit(0);

