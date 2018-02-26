#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use FindBin qw($Bin $Script);
use File::Basename qw(basename dirname);
use File::Path qw(make_path);
use Data::Dumper;
use Cwd qw(abs_path);

&usage if @ARGV<1;

sub usage {
        my $usage = << "USAGE";

        This script automatic run jobs.
        Author: zhoujj2013\@gmail.com 
        Usage: $0 config.txt

USAGE
print "$usage";
exit(1);
};

my $conf=shift;
my %conf;
&load_conf($conf, \%conf);

my $server_dir=abs_path($conf{SERVER});
my $out_dir=abs_path($conf{OUTDIR});

my $pwd=`pwd`;
chomp($pwd);

mkdir "$out_dir" unless(-d $out_dir);

while(1){
	my @dirs = glob("$server_dir/*");
	my @out_dirs=glob("$out_dir/*");
	
	my %b_dirs;
	
	# deal with server dir
	foreach my $d (@dirs){

		my $b = basename($d);
		if(-f "$d/upload.finished" && !(-f "$d/cp.finished")){
			$b_dirs{$b} = $d;
		}
	}
	
	# deal with hpc dir
	my %submitted_dir;
	my %submitted_finished_dir;
	foreach my $d (@out_dirs){
		my $b = basename($d);
		if(-f "$d/hpc.submitted"){
			$submitted_dir{$b} = $d;
		}
		if(-f "$d/hpc.submitted" && -f "$d/07Report.finished"){ # this flag file should change
			$submitted_finished_dir{$b} = $d;
		}
	}
	
	# the jobs need to be submitted
	foreach my $k (keys %b_dirs){
		if(!(exists $submitted_dir{$k})){
			# this jobs is not submitted.
			mkdir "$out_dir/$k" unless(-d "$out_dir/$k");
			`cp $b_dirs{$k}/* $out_dir/$k/`;
			chdir "$out_dir/$k/";
			# generate configure file for lncfuntk analysis.
			&generate_config();
			`perl /lustre/zhoujj/project/57.lncfuntk/test1/lncfuntk/run_lncfuntk.pl ./config.txt`;
			chdir "$pwd";
			`nohup make > make.log 2>make.err &`;
		}elsif(exists $submitted_dir{$k} && exists $submitted_finished_dir{$k}){
			# this jobs is finished.
			`cp -r $out_dir/07Report $b_dirs{$k}/result && touch cp.finished`;
		}
	}
	sleep(5);
	#print join "\n",@dirs;
	#print "\n";
}

#########################

sub load_conf
{
    my $conf_file=shift;
    my $conf_hash=shift; #hash ref
    open CONF, $conf_file || die "$!";
    while(<CONF>)
    {
        chomp;
        next unless $_ =~ /\S+/;
        next if $_ =~ /^#/;
        warn "$_\n";
        my @F = split"\t", $_;  #key->value
        $conf_hash->{$F[0]} = $F[1];
    }
    close CONF;
}

sub generate_config{
	open CONF,"para.txt" || die $!;
	my $version=<CONF>;
	chomp($version);
	my $prefix=<CONF>;
	chomp($prefix);
	close CONF;
	
	my $spe;
	if($version eq "mm9" || $version eq "mm10"){
		$spe="mouse";
	}else{
		$spe="human";
	}
	
	my @input = glob("./*");
	my %input;
	foreach my $i (@input){
		$input{$i} = 1;
	}
	#print Dumper(\%input);
	open OUT,">","./config.txt" || die $!;
	print OUT "OUTDIR\t./\n";
	print OUT "PREFIX\t$prefix\n";
	print OUT "SPE\t$spe\n";
	print OUT "VERSION\t$version\n";
	if(exists $input{"./novo_lncrna.gtf"}){
		print OUT "LNCRNA\t./novo_lncrna.gtf\n";
	}else{
		print OUT "LNCRNA\tnone\n";
	}
	print OUT "MIRLIST\t./mirna.lst\n";
	print OUT "EXPR\t./expr.mat\n";
	print OUT "EXPRCUTOFF\t0.5\n";
	print OUT "PCCCUTOFF\t0.95\n";
	
	open TFLIST,">","./tf.lst" || die $!;
	foreach my $tf_k (keys %input){
		if($tf_k =~ /^TF\.(.*)$/){
			my $tf_name = $1;
			print TFLIST "$tf_name\t$tf_k\n";
		}
	}
	close TFLIST;
	
	print OUT "CHIP\t./tf.lst\n";
	print OUT "PROMOTER\t10000,5000\n";
	
	print OUT "CLIP\t./ago2_binding.bed\n";
	print OUT "EXTEND\t100\n";
	close OUT;
	
# setting output directory
# OUTDIR  ./
#
# # setting output file prefix
# PREFIX  mESCs
#
# # human/mouse
# SPE     mouse
#
# # genome version
# VERSION mm9
#
# # Long noncoding RNA coordinates in gtf format. If set the parameter as none, expressed lncRNAs in RefSeq will be used.
# LNCRNA  ./test_data/novel.final.gtf
#
# # express miRNA list, must be offical gene symbol and it's corresponding transcript ID (with NR_ prefix).
# MIRLIST ./test_data/MirRNA_expr_refseq.lst
#
# # Gene expression matrix time serise transcriptome profiles (multiple datasets, place the stage your focus on at the first column, at least 3 datasets).
# EXPR    ./test_data/GeneExpressionProfiles/gene.expr.mat
#
# # The expression profile column corresponsing to the cell stage that you want to prediction long nocoding RNA
# EXPRCUTOFF      0.5
# PCCCUTOFF       0.95
#
# # TF binding peaks from TF chipseq (multiple datasets, at least the key tfs)
# CHIP    ./test_data/TfBindingProfiles/tf.chipseq.lst
# PROMTER 10000,5000
#
# # Ago2 binding site from CLIP-seq (1 dataset)
# CLIP    ./test_data/MirnaBindingProfiles/miRNA.binding.potential.bed
# EXTEND  100
#
}
