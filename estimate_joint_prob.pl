#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

my $input_file;
my $num_iter;
my $output_file1;
my $output_file2;

GetOptions(
	'input=s' => \$input_file,
	'iter=s' => \$num_iter,
	'out1=s' => \$output_file1,
	'out2=s' => \$output_file2,
);

open(IN01, "<$input_file");
open(OUT01, ">$output_file1");
open(OUT02, ">$output_file2");

my $line;
my $variant;

my @data;
my @variant_list = ();

my %joint_prob_pre;
my %joint_prob_post;

while ($line = <IN01>) {
	chomp($line);
	@data = split(/\t/, $line);
	unless ($line =~ /^mut_group/) {
		$variant = join(":", ($data[2], $data[3], $data[4], $data[5]));
		if (exists($joint_prob_pre{$variant})) {
			$joint_prob_pre{$variant} += log($data[11]);
		} else {
			$joint_prob_pre{$variant} = log($data[11]);
		}
		if (exists($joint_prob_post{$variant})) {
			$joint_prob_post{$variant} += log($data[12]);
		} else {
			$joint_prob_post{$variant} = log($data[12]);
		}
		unless (grep {$_ eq $variant} @variant_list) {
			push(@variant_list, $variant);
		}
	}
}
close(IN01);

my $prob_pre;
my $prob_post;
my $datum;

my @header = ("joint_prob_pre", "joint_prob_post");

my %str_prob;

open(IN01, "<$input_file");
while ($line = <IN01>) {
	chomp($line);
	@data = split(/\t/, $line);
	if ($line =~ /^mut_group/) {
		push(@data, @header);
	} else {
		$variant = join(":", ($data[2], $data[3], $data[4], $data[5]));
		$prob_pre = exp($joint_prob_pre{$variant});
		$prob_post = exp($joint_prob_post{$variant});
		$prob_pre = $prob_pre / ($prob_pre + $prob_post);
		$prob_post = 1 - $prob_pre;
		push(@data, ($prob_pre, $prob_post));
		unless (exists($str_prob{$variant})) {
			$str_prob{$variant} = $prob_pre;
		}
	}
	$datum = join("\t", @data);
	print OUT01 "$datum\n";
}
close(IN01);

my $i;
my $check;
my $rand_value;
my $chr;

my @array;
my @chr_list = ("chr3", "chr10");

my %num_pre;
my %num_post;
my %prop_pre;
my %var_prop_pre;

@header = (
	"iteration",
	"num_pre_chr3", "num_pos_chr3", "prop_pre_chr3", "var_prop_pre_chr3",
	"num_pre_chr10", "num_pos_chr10", "prop_pre_chr10", "var_prop_pre_chr10");
$datum = join("\t", @header);
print OUT02 "$datum\n";

for ($i=1; $i<=$num_iter; $i++) {
	%num_pre = ();
	%num_post = ();
	foreach $variant (@variant_list) {
		@array = split(/:/, $variant);
		$check = 0;
		while ($check == 0) {
			$rand_value = rand();
			if ($str_prob{$variant} > $rand_value) {
				if (exists($num_pre{$array[0]})) {
					$num_pre{$array[0]}++;
				} else {
					$num_pre{$array[0]} = 1;
				}
				$check = 1;
			} elsif ($str_prob{$variant} < $rand_value) {
				if (exists($num_post{$array[0]})) {
					$num_post{$array[0]}++;
				} else {
					$num_post{$array[0]} = 1;
				}
				$check = 1;
			}
		}
	}
	@data = ();
	push(@data, $i);
	foreach $chr (@chr_list) {
		$num_pre{$chr} = 2 * $num_pre{$chr};
		$prop_pre{$chr} = $num_pre{$chr} / ($num_pre{$chr} + $num_post{$chr});
		$var_prop_pre{$chr} = $prop_pre{$chr} * (1 - $prop_pre{$chr}) / ($num_pre{$chr} + $num_post{$chr});
		push(@data, ($num_pre{$chr}, $num_post{$chr}, $prop_pre{$chr}, $var_prop_pre{$chr}));
	}
	$datum = join("\t", @data);
	print OUT02 "$datum\n";
}
