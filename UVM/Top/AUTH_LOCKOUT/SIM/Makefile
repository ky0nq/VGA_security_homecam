TEST_MODE := AUTH_LOCKOUT
RTL_FILES := $(sort $(wildcard ../RTL/VGA_Tracking/*.sv))
VIDEO_RTL_FILES := $(sort $(wildcard ../RTL/Video_Datapath/*.sv))
TB_FILES := ../TB/interface.sv ../TB/uvm_pkg.sv ../TB/tb_top.sv

.PHONY: build run clean

build:
	TEST_MODE=$(TEST_MODE) TOP=tb_top RUN_SIM=0 ../RUN/compile.tcl $(RTL_FILES) $(VIDEO_RTL_FILES) $(TB_FILES)

run:
	TEST_MODE=$(TEST_MODE) TOP=tb_top RUN_SIM=1 ../RUN/compile.tcl $(RTL_FILES) $(VIDEO_RTL_FILES) $(TB_FILES)

clean:
	rm -rf ../SIM/sim
