#!/usr/bin/tclsh

set run_file_list $argv

set top_module "system_top"
if {[info exists ::env(TOP)] && $::env(TOP) ne ""} {
	set top_module $::env(TOP)
}

set run_sim 0
if {[info exists ::env(RUN_SIM)] && $::env(RUN_SIM) eq "1"} {
	set run_sim 1
}

set test_mode "NORMAL"
if {[info exists ::env(TEST_MODE)] && $::env(TEST_MODE) ne ""} {
	set test_mode $::env(TEST_MODE)
}

if {[file isdirectory "../SIM/sim/"]} { 
	exec ../RUN/log.pl 0
} else { exec echo "no sim" }

if {![file isdirectory "../SIM/sim/"]} { 
	exec mkdir ../SIM/sim 
} 

exec vcs \
	-full64 \
	-sverilog \
	-debug_access+all \
	-kdb \
	-lca \
	-ntb_opts uvm-1.2 \
	-timescale=1ns/1ps \
	+incdir+../TB \
	-top $top_module \
	{*}$run_file_list \
	-o ../SIM/sim/simv \
	-cm line+cond+fsm+tgl+branch+assert \
	-cm_dir ../SIM/sim/coverage.vdb \
	-l ../SIM/sim/compile.log \
	2>@1


if {$run_sim && [file exists "../SIM/sim/simv"]} { 
	exec ../SIM/sim/simv \
			+UVM_TESTNAME=Dut_test \
			+TEST_MODE=$test_mode \
			+UVM_VERBOSITY=UVM_HIGH > ../SIM/sim/sim.log 2>@1
} elseif {$run_sim} { exec echo "no simv" }

if {[file exists "../SIM/wave.fsdb"]} { 
	exec mv ../SIM/wave.fsdb ../SIM/sim
} else { exec echo "no wave.fsdb" }

set log_file "../SIM/sim/sim.log"
if {$run_sim && [file exists $log_file]} { 
	puts $log_file
	puts "../SIM/sim/compile.log"
	puts [exec ../RUN/log.pl 1]
		
} elseif {$run_sim} { exec echo "no sim.log" }
