#!/usr/bin/perl

use strict;
use warnings;
use diagnostics;

use POSIX;
use Time::HiRes qw( time );

# Write your perl script here.
my $argc = $#ARGV + 1;

if ($argc != 4) {
        print "Usage: '$0 <nvvp-file> <start-time> <end-time> <offset-time>'\n";
        exit 1;
}
my $nvvpfile = $ARGV[0];
if (! -e $nvvpfile) {
        print "Error: File does not exists!\n";
        exit 2;
}

my $OFFSET = $ARGV[3];
my $START = $ARGV[1] - $OFFSET;
my $END = $ARGV[2] - $OFFSET;

my $nvprof="/usr/local/cuda/bin/nvprof";
my $tmpdump="${nvvpfile}.dump";
print "Generating information from $nvvpfile...\n";
my $startTime = time();
system("$nvprof -i $nvvpfile --print-gpu-trace --normalized-time-unit ns --csv > $tmpdump 2>&1");
if ($! != 0) {
	print "Opps, issue with nvprof command!\n";
	exit 3;
}
printf("### Information is generated: elapsed time %.3f sec.\n\n", (time() - $startTime));

my $tempdump_padding = 3;
my $tmp_file = "${nvvpfile}.t";
print "Creating only start-time information from $tmpdump...\n";
$startTime = time();
system("cut -d ',' -f1 $tmpdump | cut -d '.' -f1 > $tmp_file");
if ($! != 0) {
	print "Opps, issue with shell command!\n";
	exit 4;
}
printf("### Start-time is created: elapsed time %.3f sec.\n\n", (time() - $startTime));

if (! open TRACEFILE, $tmp_file) {
        print "Error: can not open file '$tmp_file'\n";
        exit 5;
}
my @lines = <TRACEFILE>;
close TRACEFILE;

my $n = scalar @lines;
my $DONE = 0;
my $s = 3;
my $e = $n - 1;
my $ln = 0;
my $lastmid = 0;
my $mid = 0;

print "Finding start line...\n";
$startTime = time();
while ($DONE == 0) {
	if ($lines[$s] == $START) {
		$ln = $s;
		$DONE = 1;
	} elsif ($lines[$e] == $START) { 
		$ln = $e;
		$DONE = 1;
	} else {
		$mid = int(floor(($s + $e) / 2));
		print "# $mid \n";
		if ($lastmid == $mid) {
			$ln = $mid;
			$DONE = 1;
		} elsif ($lines[$mid] == $START) {
			$ln = $mid;
			$DONE = 1;
		} elsif ($lines[$mid] < $START) {
			$s = $mid;
		} elsif ($lines[$mid] > $START) {
			$e = $mid;
		}
	}
	$lastmid=$mid
}

#print "### $ln ==> $lines[$ln]\n";
chomp($lines[$ln]);
printf("### Start line found at %d ==> %d: elapsed time %.3f sec.\n\n", $ln, $lines[$ln], (time() - $startTime));
my $HtoD='"[CUDA memcpy HtoD]"';
my $DtoH='"[CUDA memcpy DtoH]"';
my $DtoD='"[CUDA memcpy DtoD]"';
my $PtoP='"[CUDA memcpy PtoP]"';
my %dhtod;
my %ddtoh;
my %ddtod;
my %dptop;
my %dcompute;
my %shtod;
my %sdtoh;
my %sdtod;
my %sptop;

print "Processing...\n";
$startTime = time();

if (! open TRACEFILE, $tmpdump) {
        print "Error: can not open file '$tmpdump'\n";
        exit 5;
}
@lines = <TRACEFILE>;
close TRACEFILE;

my @items = ('"Start"', '"Duration"', '"Size"', '"Device"', '"Name"');
my %itemhash;
@itemhash{@items}=();

chomp($lines[1]);
chomp($lines[2]);
my @headers = split(/,/, $lines[1]);
my @units = split(/,/, $lines[2]);
my $pattern = '^';
my $unit = "";
my $time_unit="ns";
my $i = 0;
for (@headers) {
	if (exists($itemhash{$_})) {
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

chop($pattern);
#print $pattern . "\n";
my $regex = qr/$pattern/;
$DONE=0;
while ($DONE == 0) {
	#print $lines[$ln];
	#my ($start, $duration, $size, $gpu, $operation) = $lines[$ln] =~ /^([^,]*),([^,]*),[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,([^,]*),[^,]*,([^,]*),[^,]*,[^,]*,([^,]*)/;
	my ($start, $duration, $size, $gpu, $operation) = $lines[$ln] =~ $regex;
	#print "$start, $duration, $size, $gpu, $operation\n";
	chomp($operation);
	if ($start >= $START and ($start + $duration) <= $END) {
		if ($HtoD eq $operation) {
			if ($dhtod{$gpu}) {
			$dhtod{$gpu}=($dhtod{$gpu} + $duration);
			$shtod{$gpu}=($shtod{$gpu} + $size);
			} else {
				$dhtod{$gpu} = $duration;
				$shtod{$gpu} = $size;
			}
		} elsif ($DtoH eq $operation) {
			if ($ddtoh{$gpu}) {
			$ddtoh{$gpu}=($ddtoh{$gpu} + $duration);
			$sdtoh{$gpu}=($sdtoh{$gpu} + $size);
			} else {
				$ddtoh{$gpu} = $duration;
				$sdtoh{$gpu} = $size;
			}
		} elsif ($DtoD eq $operation) {
			if ($ddtod{$gpu}) {
			$ddtod{$gpu}=($ddtod{$gpu} + $duration);
			$sdtod{$gpu}=($sdtod{$gpu} + $size);
			} else {
				$ddtod{$gpu} = $duration;
				$sdtod{$gpu} = $size;
			}
		} elsif ($PtoP eq $operation) {
			if ($dptop{$gpu}) {
			$dptop{$gpu}=($dptop{$gpu} + $duration);
			$sptop{$gpu}=($sptop{$gpu} + $size);
			} else {
				$dptop{$gpu} = $duration;
				$sptop{$gpu} = $size;
			}
		} else {
			if ($dcompute{$gpu}) {
			$dcompute{$gpu}=($dcompute{$gpu} + $duration);
			} else {
				$dcompute{$gpu} = $duration;
			}
		} 
	} elsif (($start + $duration) > $END) {
		$DONE=1;
	}
	$ln=$ln+1;
	undef $start;
	undef $duration;
	undef $size;
	undef $gpu;
	undef $operation;
}
printf("### Processing done: elapsed time %.3f sec.\n\n", (time() - $startTime));
print "#################################### Result ####################################\n";
my @GPUs = keys %dcompute;
for (@GPUs) {
	print "GPU: $_\n";
	print "Compute: $dcompute{$_} $time_unit\n";
	my $dcommunication=0;
	my $scommunication=0;
	if ($dhtod{$_}) {
		$dcommunication = $dcommunication + $dhtod{$_};
		$scommunication = $scommunication + $shtod{$_};
	} 
	if ($ddtoh{$_}) {
		$dcommunication = $dcommunication + $ddtoh{$_};
		$scommunication = $scommunication + $sdtoh{$_};
	} 
	if ($ddtod{$_}) {
		$dcommunication = $dcommunication + $ddtod{$_};
		$scommunication = $scommunication + $sdtod{$_};
	} 
	if ($dptop{$_}) {
		$dcommunication = $dcommunication + $dptop{$_};
		$scommunication = $scommunication + $sptop{$_};
	} 

	printf("Communication: %d %s --> %f %s\n", $dcommunication, $time_unit, $scommunication, $unit);
	if ($dhtod{$_}) {
	printf("    HtoD: %d %s --> %f %s\n", $dhtod{$_}, $time_unit, $shtod{$_}, $unit);
	}
	if ($ddtoh{$_}) {
	printf("    DtoH: %d %s --> %f %s\n", $ddtoh{$_}, $time_unit, $sdtoh{$_}, $unit);
	}
	if ($ddtod{$_}) {
	printf("    DtoD: %d %s --> %f %s\n", $ddtod{$_}, $time_unit, $sdtod{$_}, $unit);
	}
	if ($dptop{$_}) {
	printf("    PtoP: %d %s --> %f %s\n", $dptop{$_}, $time_unit, $sptop{$_}, $unit);
	}
	print "\n";
}
