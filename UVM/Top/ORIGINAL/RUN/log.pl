#!/usr/bin/perl

my $mode_sel  = shift(@ARGV);

if($mode_sel < 0){$mode_sel = 0;}

my $file = "../SIM/sim/sim.log";

if(-d "./sim_/"){
	system("rm -rf ./sim\_/");

}

if($mode_sel eq 0){
	my $result; 
	my %mon = (
	    Jan => "01", Feb => "02", Mar => "03", Apr => "04",
	    May => "05", Jun => "06", Jul => "07", Aug => "08",
	    Sep => "09", Oct => "10", Nov => "11", Dec => "12",
	);
	
	if(-e $file){
		open(my $fh, "<", $file) or die "Cannot open file: $!";
		while (my $line = <$fh>) {
			if ($line =~ /^\w+\s+(\w+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\d+)$/) {
			    my $month = $mon{$1};
			    my $day   = sprintf("%02d", $2);
			    my $hour  = $3;
			    my $min   = $4;
			    my $sec   = $5;
			    $result = "${month}${day}_${hour}_${min}_${sec}";
			}
		}
		close($fh);
		print "$result\n";
		
		system ("mv ../SIM/sim ../SIM/sim_$result");
	}
}

if($mode_sel eq 1){
	if(-e $file){
	system ("grep -rn 'Warning' ./sim/*.log");
	system ("grep -rn 'Error' ./sim/*.log");
	system ("grep -rn 'UVM_INFO :' ./sim/*.log");
	system ("grep -rn 'UVM_ERROR :' ./sim/*.log");
	system ("grep -rn 'UVM_FATAL :' ./sim/*.log");
	system ("grep -rn 'UVM_WARNING :' ./sim/*.log");
	}
	else {printf("no $file");}
	
}
