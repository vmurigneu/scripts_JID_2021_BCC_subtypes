#!/usr/bin/perl

use strict;
use Data::Dumper;
use File::Spec;
use Cwd;

my $root    = getcwd;
my $bamroot = "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/u_geneve_exomes";

my @files   = `find $bamroot -maxdepth 1 -name "*-N1.bam"`;

my $tmpl    = qq{#PBS -l walltime=40:00:00
#PBS -l ncpus=1
#PBS -l mem=20GB
#PBS -N <SAMPLE>_geno
#PBS -j oe

set -e

cd $root

module load R/3.2.1
module load samtools/0.1.18
module load Java/1.8.0_66

java -jar /dmf/uqdi/Core_Services/UQCCG/Software/sw/gatk/3.4/GenomeAnalysisTK.jar \\
     -T HaplotypeCaller \\
     -R /dmf/uqdi/Genomic_Medicine/Fink_Group/genomes/hs37d5/hs37d5.fa \\
     -I $bamroot/<SAMPLE>.bam \\
     --emitRefConfidence GVCF \\
     --variant_index_type LINEAR \\
     --variant_index_parameter 128000 \\
     --dbsnp /dmf/uqdi/Genomic_Medicine/Fink_Group/genomes/hs37d5/dbsnp_132_b37.leftAligned.vcf.gz \\
     -L /dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/u_geneve_exomes/S04380219_Regions_hs37d5.intervals \\
     -o <SAMPLE>.raw.g.vcf 

java -jar /dmf/uqdi/Core_Services/UQCCG/Software/sw/gatk/3.4/GenomeAnalysisTK.jar \\
   -T GenotypeGVCFs \\
   -R /dmf/uqdi/Genomic_Medicine/Fink_Group/genomes/hs37d5/hs37d5.fa \\
   --variant <SAMPLE>.raw.g.vcf \\
   -o <SAMPLE>.g.vcf
};

foreach (@files) {
    chomp;

    my ($v, $d, $f) = File::Spec->splitpath($_);

    $f  =~ /(.+?N1)\.bam/;
    my $s   = $1;
    print STDERR "sample $s\n";
    next if(-e "/dmf/uqdi/Genomic_Medicine/Fink_Group/projects/bcc/u_geneve_exomes/genotype/".$s.".g.vcf");

    my $script  = $tmpl;
    $script     =~ s/<SAMPLE>/$s/g;

    my $pbs     = $s."_genotype.pbs";
    open(FH, ">".$pbs) || die;
    print FH $script;
    close(FH);

    #system("qsub $pbs");

    #last;
}

exit(0);

