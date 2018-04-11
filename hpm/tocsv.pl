#!/usr/bin/perl

use strict;
use warnings;
use diagnostics;

use Data::Dumper;

my @alldata = ();
my @header = ( 'Architecture', 'SMT', 'Driver', 'HPM', 'TF_Version' );
my @logfiles = glob( '*.log' );
for (@logfiles) {
  my $hashdata = {};
  my ($arch, $smt, $hostname, $driver, $hpm, $tf, $tsdate, $tstime) = $_ =~ /^([^_]*)_([^_]*)_([^_]*)_([^_]*)_hpm-([^_]*)_TF-([^_]*)_.*_([^_]*)_([^_]*)_[0-9]*.log/;
  #print "$arch, $smt, $hostname, $driver, $hpm, $tf, ${tsdate}_$tstime\n";
  ${hashdata}->{'Architecture'} = $arch;
  ${hashdata}->{'SMT'} = $smt;
  ${hashdata}->{'Driver'} = $driver;
  ${hashdata}->{'HPM'} = $hpm;
  ${hashdata}->{'TF_Version'} = $tf;
  ${hashdata}->{'Time_Stamp'} = ${tsdate} . '_' . $tstime;

  open my $fh, "<", $_ or die "Can't open $_: $!\n";
  my @lines = <$fh>;

  chop($lines[0]);
  chop($lines[-2]);
  for (split(/ /, $lines[0])) {
    if ( $_ =~ /--/ ) {
      my @oppair = split(/=/, $_);
      my $pairlen = scalar @oppair;
      ($oppair[0]) = $oppair[0] =~ /--(.*)$/;
      if ($oppair[0] eq 'data_dir') {
        next;
      } elsif ($oppair[0] eq 'data_name') {
        $oppair[0] = 'dataset';
      }
      if ( $pairlen == 2 ) {
        ${hashdata}->{$oppair[0]} = $oppair[1];
      } elsif ( $pairlen == 1 ) {
        ${hashdata}->{$oppair[0]} = '';
      }
      push(@header, $oppair[0]) unless grep{$_ eq $oppair[0]} @header;
    }
  }
  my ($throughput) = $lines[-2] =~ /total images\/sec: *([^ ][^ ]*)$/;
  #print "$throughput\n";
  ${hashdata}->{'Throughput'} = $throughput;
  if (! exists ${hashdata}->{'dataset'}) {
    ${hashdata}->{'dataset'} = 'synthetic'
  }
  push @alldata, $hashdata;
  #exit 1;
}
#print Dumper(\@alldata);
#my $maxsize = 0;
#for (@alldata) {
#  my $size = keys %{ $_ };
#  if ( $maxsize < $size ) {
#    $maxsize = $size;
#  }
#}
#print Dumper(\@header);
#print "$maxsize\n";
for (@header) {
  print "$_,"
}
print "Time_Stamp,Throughput\n";

foreach my $data (@alldata) {
  for (@header) {
    if (exists $data->{$_}) {
      print "$data->{$_},"
    } else {
      print ",";
    }
  }
  print "$data->{'Time_Stamp'},$data->{'Throughput'}\n"
}
