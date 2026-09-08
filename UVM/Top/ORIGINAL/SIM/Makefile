RTL_DIR       := ../RTL/VGA_Tracking
VIDEO_RTL_DIR := ../RTL/Video_Datapath
BUILD_DIR     := ../SIM/sim

# VGA_Tracking modules use a VGA_ prefix, so both RTL trees can be compiled.
RTL_FILES := $(sort $(wildcard $(RTL_DIR)/*.sv))
VIDEO_RTL_FILES := $(sort $(wildcard $(VIDEO_RTL_DIR)/*.sv))

ALL_RTL_FILES := $(RTL_FILES) $(VIDEO_RTL_FILES)
TB_FILES      := ../TB/interface.sv ../TB/uvm_pkg.sv ../TB/tb_top.sv

.PHONY: all build compile test-build run debug coverage clean help

all: test-build

build compile:
	TOP=system_top RUN_SIM=0 ../RUN/compile.tcl $(ALL_RTL_FILES)

test-build:
	TOP=tb_top RUN_SIM=0 ../RUN/compile.tcl $(ALL_RTL_FILES) $(TB_FILES)

run:
	TOP=tb_top RUN_SIM=1 ../RUN/compile.tcl $(ALL_RTL_FILES) $(TB_FILES)

debug:
	verdi -dbdir $(BUILD_DIR)/simv.daidir -ssf $(BUILD_DIR)/wave.fsdb &

coverage:
	verdi -cov -covdir $(BUILD_DIR)/coverage.vdb \
		-dbdir $(BUILD_DIR)/simv.daidir -ssf $(BUILD_DIR)/wave.fsdb &

clean:
	rm -rf $(BUILD_DIR)

help:
	@echo "make build       Compile both RTL implementations"
	@echo "make test-build  Compile and run the two-board UVM testbench"
	@echo "make run         Alias for test-build"
