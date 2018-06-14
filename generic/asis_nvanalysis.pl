#!/usr/bin/perl

#
# File Name: asis_nvanalysis.pl
#
# Date:      June 13, 2018
# Author:    Asis Kumar Patra
# Purpose:   Process .nvvp file and show different usage.
#

use strict;
use warnings;
use diagnostics;

use POSIX;
use Time::HiRes qw( time );

#no warnings "experimental::autoderef";

# Write your perl script here.

my $print_comm_datasize = 1; # config_flag - print communication data size

# Number of arguments need to be two -  nvprofile file and number of iterations
my $argc = $#ARGV + 1;
if ($argc != 2) {
        print "Usage: '$0 <nvvp-file> <iterations>'\n";
        exit 1;
}

my $iterations = $ARGV[1];

my $nvvpfile = $ARGV[0];
if (! -e $nvvpfile) {
        print "Error: File does not exists!\n";
        exit 2;
}


my $nvprof="/usr/local/cuda/bin/nvprof";
my $tmpdump="${nvvpfile}.dump";
print "Generating information from $nvvpfile...\n";
my $startTime = time();
if (! -e $tmpdump) {
        system("$nvprof -i $nvvpfile --print-gpu-trace --normalized-time-unit ns --csv > $tmpdump 2>&1");

        if ($? != 0) {
                print "Opps, issue with nvprof command!\n";
                exit 3;
        }
}
printf("### Information is generated: elapsed time %.3f sec.\n\n", (time() - $startTime));

my $tempdump_padding = 3; # Not-used variable -  First 3 lines of the dump info is header related - _, Header, Unit

print "Processing...\n";
$startTime = time();

if (! open TRACEFILE, $tmpdump) {
        print "Error: can not open file '$tmpdump'\n";
        exit 5;
}
my @lines = <TRACEFILE>;
my $total_lines = scalar @lines;
close TRACEFILE;

# Information that I am currently interested.
my @items = ('"Start"', '"Duration"', '"Size"');
my %itemhash;
@itemhash{@items}=();

# Information that I am currently interested.
my @items2 = ('"Device"', '"Name"');
my %itemhash2;
@itemhash2{@items2}=();

# Information that I am currently interested - for P2P write and read - link usage.
my @items3 = ('"Src Dev"', '"Dst Dev"');
my %itemhash3;
@itemhash3{@items3}=();

chomp($lines[1]); # Header
chomp($lines[2]); # Unit
my @headers = split(/,/, $lines[1]); # Split header with comma(,)
my @units = split(/,/, $lines[2]); # Split header with comma(,)

# Generate regular expression pattern according to interest
my $pattern = '^';
my $unit = ""; # During regular exp pattern generation, need to find the Communication Size unit.
my $time_unit="ns"; # In the 3rd line of the dump Time unit is ns(nano-second)
my $i = 0;
for (@headers) {
        if (exists($itemhash2{$_})) {
                $pattern = $pattern . '"([^"]*)",';
        } elsif (exists($itemhash{$_})) {
                #print "$_ Yes\n";
                $pattern = $pattern . '([^,]*),';
        } else {
                #print "$_ No\n";
                $pattern = $pattern . '[^,]*,';
        }

        if ($_ eq '"Size"') {
                $unit = $units[$i];
        }
        $i++;
}

chop($pattern); # Pattern is generated
#print $pattern . "\n";
my $regex = qr/$pattern/;

my $pppattern = '^'; # Pattern for P2P link Usage: Src Dev and Dst Dev
$i = 0;
for (@headers) {
        if (exists($itemhash3{$_})) {
                $pppattern = $pppattern . '"([^"]*)",';
        } else {
                $pppattern = $pppattern . '[^,]*,';
        }
        $i++;
}

chop($pppattern); # Pattern is generated
#print $pppattern . "\n";
my $ppregex = qr/$pppattern/;

my $ln_asis = 3; # First 3 lines of the dump info is header related - _, Header, Unit
my %std; # We need to find what is the uniq operation happened on each iteration.
my %ops; # Hash of operations: operation -> number of occurance
my %ops_arr = (); # Array of operations to maintain which operation was the first
while ($ln_asis < $total_lines) {
        my ($start, $duration, $size, $gpu, $operation) = $lines[$ln_asis] =~ $regex;
        chomp($operation);
        $operation =~ s/ \[\d+\]//;
        if (exists($ops{$gpu}{$operation})) {
                $ops{$gpu}{$operation} = $ops{$gpu}{$operation} + 1;
        } else {
                $ops{$gpu}{$operation} = 1;
                $ops_arr{$gpu}->[scalar @{$ops_arr{$gpu}}] = $operation;
        }
        $ln_asis = $ln_asis + 1;
}
foreach my $gpu (sort keys %ops) {
        print "### $gpu\n";
        for (@{$ops_arr{$gpu}}) {
                #print "    $_ --> $ops{$gpu}{$_}\n";
                if ($ops{$gpu}{$_} == $iterations) {
                        $std{$gpu} = quotemeta $_;
                        print "    $_ --> $ops{$gpu}{$_}\n";
                        last;
                }
        }
        #last;
}

#$std = quotemeta $std; # Here we should have the first unique operation of GPU0
#print "$std\n";
#exit(0);

my $HtoD='[CUDA memcpy HtoD]';
my $DtoH='[CUDA memcpy DtoH]';
my $DtoD='[CUDA memcpy DtoD]';
my $PtoP='[CUDA memcpy PtoP]';
my %dhtod; # Total HtoD
my %ddtoh; # Total DtoH
my %ddtod; # Total DtoD
my %dptop; # Total PtoP
my %rhtod; # real clock HtoD
my %rdtoh; # real clock DtoH
my %rdtod; # real clock DtoD
my %rptop; # real clock PtoP
my %ahtod; # real clock HtoD - Start
my %adtoh; # real clock DtoH - Start
my %adtod; # real clock DtoD - Start
my %aptop; # real clock PtoP - Start
my %bhtod; # real clock HtoD - End
my %bdtoh; # real clock DtoH - End
my %bdtod; # real clock DtoD - End
my %bptop; # real clock PtoP - End
my %dcompute; # Total computation
my %rcompute;  # real clock computation
my %acompute;  # real clock computation - Start
my %bcompute;  # real clock computation - End
my %dgpu; # Total GPU
my %rgpu;  # real clock GPU
my %agpu;  # real clock GPU - Start
my %bgpu;  # real clock GPU - End
my %dcommunication;  # Total communication
my %rcommunication;  # real clock communication
my %acommunication;  # real clock communication - Start
my %bcommunication;  # real clock communication - End
my %scommunication;  # Total communication size
my %shtod; # Total size HtoD
my %sdtoh; # Total size DtoH
my %sdtod; # Total size DtoD
my %sptop; # Total size PtoP
my %dlinkptop; # P2P Link Usage
my %rlinkptop;
my %alinkptop;
my %blinkptop;
my %slinkptop;

my $DONE=0;
my %CAPTURE;
my $ln=3; # First 3 lines of the dump info is header related - _, Header, Unit
my %tmptime;
my %periteration;
my $tmpstr;
my $printstr="";
my %iterstart;
print "#################################### Result ####################################\n";

while ($ln < $total_lines) {
        #print $lines[$ln];
        my ($start, $duration, $size, $gpu, $operation) = $lines[$ln] =~ $regex;
        #print "$start, $duration, $size, $gpu, $operation\n";

        chomp($operation); # Chomp operation - as it the last item in the line
        $operation =~ s/ \[\d+\]//;
        if (! $CAPTURE{$gpu}) {
                $CAPTURE{$gpu} = 0;
                $tmptime{$gpu} = 0;
                $periteration{$gpu} = 0;
        }
        $tmpstr = $operation;
        if ($CAPTURE{$gpu} == 1) {
                calculate_only_time(\%dgpu, \%rgpu, \%agpu, \%bgpu, $gpu, $start, $duration);
                if ($HtoD eq $operation or $DtoH eq $operation or $DtoD eq $operation or $PtoP eq $operation) {
                        calculate(\%dcommunication, \%rcommunication, \%acommunication, \%bcommunication,
                                $gpu, $start, $duration, \%scommunication, $size);
                }
                if ($HtoD eq $operation) {
                        calculate(\%dhtod, \%rhtod, \%ahtod, \%bhtod, $gpu, $start, $duration, \%shtod, $size);
                } elsif ($DtoH eq $operation) {
                        calculate(\%ddtoh, \%rdtoh, \%adtoh, \%bdtoh, $gpu, $start, $duration, \%sdtoh, $size);
                } elsif ($DtoD eq $operation) {
                        calculate(\%ddtod, \%rdtod, \%adtod, \%bdtod, $gpu, $start, $duration, \%sdtod, $size);
                } elsif ($PtoP eq $operation) {
                        my ($srcdev, $dstdev) = $lines[$ln] =~ $ppregex;
                        calculate(\%dlinkptop, \%rlinkptop, \%alinkptop, \%blinkptop, $srcdev, $start, $duration, \%slinkptop, $size);
                        calculate(\%dlinkptop, \%rlinkptop, \%alinkptop, \%blinkptop, $dstdev, $start, $duration, \%slinkptop, $size);
                        calculate(\%dptop, \%rptop, \%aptop, \%bptop, $gpu, $start, $duration, \%sptop, $size);
                } else {
                        calculate_only_time(\%dcompute, \%rcompute, \%acompute, \%bcompute, $gpu, $start, $duration);
                }
        }
        if (exists($std{$gpu}) and $operation =~ /$std{$gpu}/) {
                if($CAPTURE{$gpu} == 0) {
                        $CAPTURE{$gpu} = 1;
                        $tmptime{$gpu}=$start + $duration;
                        $iterstart{$gpu}=$start;
                } else {
                        $periteration{$gpu} = $start + $duration - $tmptime{$gpu};
                        adjust_last_real_time($gpu);
                        print__result($gpu);
                        $iterstart{$gpu}=$start;
                        delete $dhtod{$gpu};
                        delete $ddtoh{$gpu};
                        delete $ddtod{$gpu};
                        delete $dptop{$gpu};
                        delete $dlinkptop{$gpu};
                        delete $dgpu{$gpu};
                        delete $dcompute{$gpu};
                        delete $dcommunication{$gpu};
                        delete $shtod{$gpu};
                        delete $sdtoh{$gpu};
                        delete $sdtod{$gpu};
                        delete $sptop{$gpu};
                        delete $slinkptop{$gpu};
                        $tmptime{$gpu}=$start + $duration;
                }
        }
        $ln=$ln+1;
        undef $start;
        undef $duration;
        undef $size;
        undef $gpu;
        undef $operation;
}
print "$printstr\n";
printf("### Processing done: elapsed time %.3f sec.\n\n", (time() - $startTime));


sub adjust_last_real_time {
        my $gpu = $_[0];
        if (exists $rhtod{$gpu}) { $rhtod{$gpu} = $rhtod{$gpu} + $bhtod{$gpu} - $ahtod{$gpu}; }
        if (exists $rdtoh{$gpu}) { $rdtoh{$gpu} = $rdtoh{$gpu} + $bdtoh{$gpu} - $adtoh{$gpu}; }
        if (exists $rdtod{$gpu}) { $rdtod{$gpu} = $rdtod{$gpu} + $bdtod{$gpu} - $adtod{$gpu}; }
        if (exists $rptop{$gpu}) { $rptop{$gpu} = $rptop{$gpu} + $bptop{$gpu} - $aptop{$gpu}; }
        if (exists $rcompute{$gpu}) { $rcompute{$gpu} = $rcompute{$gpu} + $bcompute{$gpu} - $acompute{$gpu}; }
        if (exists $rcommunication{$gpu}) { $rcommunication{$gpu} = $rcommunication{$gpu} + $bcommunication{$gpu} - $acommunication{$gpu}; }
}

sub calculate_only_time{
        my ($dvariable, $rvariable, $avariable, $bvariable, $gpu, $start, $duration) = @_;
        if ($$dvariable{$gpu}) {
                $$dvariable{$gpu} = ($$dvariable{$gpu} + $duration);
                if ($$bvariable{$gpu} >= $start and $$bvariable{$gpu} < ($start + $duration)) {
                        $$bvariable{$gpu} = $start + $duration;
                } elsif ($start > $$bvariable{$gpu}) {
                        $$rvariable{$gpu} = $$rvariable{$gpu} + $$bvariable{$gpu} - $$avariable{$gpu};
                        $$avariable{$gpu} = $start;
                        $$bvariable{$gpu} = $$avariable{$gpu} + $duration;
                }
        } else {
                $$dvariable{$gpu} = $duration;
                $$avariable{$gpu} = $start;
                $$bvariable{$gpu} = $$avariable{$gpu} + $duration;
                $$rvariable{$gpu} = 0;
        }
}

sub calculate{
        my ($dvariable, $rvariable, $avariable, $bvariable, $gpu, $start, $duration, $svariable, $size) = @_;
        if ($$dvariable{$gpu}) {
                $$dvariable{$gpu} = ($$dvariable{$gpu} + $duration);
                $$svariable{$gpu} = ($$svariable{$gpu} + $size);
                if ($$bvariable{$gpu} >= $start and $$bvariable{$gpu} < ($start + $duration)) {
                        $$bvariable{$gpu} = $start + $duration;
                } elsif ($start > $$bvariable{$gpu}) {
                        $$rvariable{$gpu} = $$rvariable{$gpu} + $$bvariable{$gpu} - $$avariable{$gpu};
                        $$avariable{$gpu} = $start;
                        $$bvariable{$gpu} = $$avariable{$gpu} + $duration;
                }
        } else {
                $$dvariable{$gpu} = $duration;
                $$svariable{$gpu} = $size;
                $$avariable{$gpu} = $start;
                $$bvariable{$gpu} = $$avariable{$gpu} + $duration;
                $$rvariable{$gpu} = 0;
        }
}

sub print__result {
        my $gpu = $_[0];
        my $g = $gpu;
        $g =~ tr/\ /_/;
        print "$g,$iterstart{$gpu},$periteration{$gpu},$rcompute{$gpu}";
        $printstr="GPU,Start Time,Duration($time_unit),Computation($time_unit)";
        if (exists $dcommunication{$gpu}) { print ",$rcommunication{$gpu}"; } else {print ","; } $printstr="${printstr},Communication($time_unit)";
        my $nongpu = $periteration{$gpu} - $rgpu{$gpu};
        print ",$nongpu,$rgpu{$gpu}";
        $printstr="${printstr},Non-GPU Activity($time_unit),GPU Activity($time_unit)";
        if (exists $dhtod{$gpu}) { print ",$rhtod{$gpu}"; } else {print ","; } $printstr="${printstr},HtoD($time_unit)";
        if (exists $ddtoh{$gpu}) { print ",$rdtoh{$gpu}"; } else {print ","; } $printstr="${printstr},DtoH($time_unit)";
        if (exists $ddtod{$gpu}) { print ",$rdtod{$gpu}"; } else {print ","; } $printstr="${printstr},DtoD($time_unit)";
        if (exists $dptop{$gpu}) { print ",$rptop{$gpu}"; } else {print ","; } $printstr="${printstr},PtoP($time_unit)";
        if (exists $dlinkptop{$gpu}) { print ",$rlinkptop{$gpu}"; } else {print ","; } $printstr="${printstr},PtoP Link($time_unit)";

        if ($print_comm_datasize and exists $scommunication{$gpu}) { print ",$scommunication{$gpu}"; } else {print ","; } $printstr="${printstr},Communication($unit)";
        if ($print_comm_datasize and exists $shtod{$gpu}) { print ",$shtod{$gpu}"; } else {print ","; } $printstr="${printstr},HtoD($unit)";
        if ($print_comm_datasize and exists $sdtoh{$gpu}) { print ",$sdtoh{$gpu}"; } else {print ","; } $printstr="${printstr},DtoH($unit)";
        if ($print_comm_datasize and exists $sdtod{$gpu}) { print ",$sdtod{$gpu}"; } else {print ","; } $printstr="${printstr},DtoD($unit)";
        if ($print_comm_datasize and exists $sptop{$gpu}) { print ",$sptop{$gpu}"; } else {print ","; } $printstr="${printstr},PtoP($unit)";
        if ($print_comm_datasize and exists $slinkptop{$gpu}) { print ",$slinkptop{$gpu}"; } else {print ","; } $printstr="${printstr},PtoP Link($unit)";
        print "\n";
}
