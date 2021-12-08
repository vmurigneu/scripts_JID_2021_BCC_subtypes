#!/usr/bin/perl

use strict;
use Data::Dumper;
use File::Spec;
use Cwd;

my $dir = getcwd;
my $suf = "snpeff_ann.vcf"; # output file suffix

my @files   = `find $dir -maxdepth 1 -name "*mutect2.vcf"`;
#print STDERR qq{find $dir -maxdepth 1 -name "*mutect2.vcf"\n};

my $threads = 1;
my $annofc      = qq{#PBS -l walltime=24:00:00
#PBS -l mem=40GB,vmem=40GB
#PBS -l ncpus=$threads
#PBS -N snpeff
#PBS -j oe

set -e

module load zlib/1.2.8
module load Java/1.8.0_66

cd $dir

/dmf/uqdi/UQCCG/Software/sw/vcftools/0.1.12b/bin/vcftools --vcf <VCF> --out <VCFILT> --remove-filtered-all --remove-indv NORMAL --recode

/dmf/uqdi/UQCCG/Software/sw/snpeff/4.1l/bin/snpEff ann -v -stats <SAMPLE>_snpeff.html GRCh37.75 <VCFILT>.recode.vcf > <OUT>
};

my $count = 0;
foreach (@files) {
    chomp;

    my ($v, $d, $f) = File::Spec->splitpath($_);

    # _hg19.realigned.recal.bam
    #print STDERR "Parsing $_\n";
    $f          =~ /(.+)\.mutect/;
    my $sam     = $1;

    my $out     = $f;
    $out        =~ s/\.vcf//;
    $out        = $out.".".$suf;

    my $filt    = $f;
    $filt       =~ s/\.vcf/\.keep/;

    # skip ones that are already done
    #next if(-e $sam."_mutect_annovar.out.multianno.csv");

    next unless($sam);

    my $fname   = $sam."_snpeff.pbs";
    my $script  = $annofc;
    $script     =~ s/<SAMPLE>/$sam/g;
    $script     =~ s/<VCF>/$f/g;
    $script     =~ s/<VCFILT>/$filt/g;
    $script     =~ s/<OUT>/$out/g;

    open(FH, ">".$fname) || die "Cannot write $fname: $!\n";
    print FH $script;
    close(FH);

    print STDERR "Submitting $fname\n\n";
    system("qsub $fname");

    #last;
}

exit(0);

