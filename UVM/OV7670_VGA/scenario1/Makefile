# ==============================================================
# Camera / SCCB / VGA UVM - run from the project root (rtl/, tb/)
# make all                 : new session, 38 tests, then reports
# make verdi               : latest completed session (fast profile)
# make comp                : compile only
# make simv TEST=...        : new session, compile + one test
# make run TEST=...         : one test using an existing build
# make run TAG=_wave DUMP=1 : save a separate waveform
# make wave / cov / verdi  : waveform / report / coverage GUI
# Sessions are automatic. Existing results are never deleted.
# Recorder code coverage is disabled at COMPILE time; no GUI mask/elfile.
# The tool-only scope file is generated under results/.../build automatically.
# ==============================================================
.DEFAULT_GOAL := all
ROOT := $(abspath .)

ifeq ($(origin SESSION),undefined)
ifneq ($(filter all comp compile simv regression covall,$(or $(MAKECMDGOALS),all)),)
SESSION := run_$(shell date +%Y%m%d_%H%M%S)_$(shell echo $$$$)
else
SESSION := $(strip $(shell cat "$(ROOT)/results/$(if $(filter verdi cov report check-coverage-scope,$(MAKECMDGOALS)),latest_session,latest_build).txt" 2>/dev/null))
endif
endif
export SESSION

VCS   ?= vcs
VERDI ?= verdi
URG   ?= urg
FAST_SETUP ?= 1
TEST       ?= cam_vga_test
SEED       ?= 1
PHASE      ?= 0
TAG        ?=
INFO_LEVEL ?= UVM_MEDIUM
DUMP       ?= 0
DUMP_WAVES ?= $(DUMP)
RUN_EXTRA  ?=
VCS_EXTRA  ?=
FSDB_PLI   ?=

PROFILE  = $(if $(filter 0,$(FAST_SETUP)),physical,fast)
BASE     = $(ROOT)/results/$(SESSION)/$(PROFILE)
BUILD    = $(BASE)/build
SIMV     = $(BUILD)/simv
COVDIR   = $(BASE)/coverage.vdb
TOOL_COV_SCOPE = $(BUILD)/tool_coverage_scope.hier
RUN_ID   = $(TEST)_seed$(SEED)_phase$(PHASE)$(TAG)
RUN_DIR  = $(BASE)/runs/$(RUN_ID)
FSDB     = $(RUN_DIR)/wave.fsdb
CM       = line+cond+fsm+tgl+branch+assert

# Compile order: RTL -> interface -> package -> top.
RTL  = rtl/pclk_gen.sv rtl/pixel_counter.sv rtl/vga_decoder.sv
RTL += rtl/OV7670_MemCNTL.sv rtl/framebuffer.sv rtl/rom_reader_upscale.sv
RTL += rtl/OV7670_setup_FSM.sv rtl/I2C_master.sv rtl/SCCB_setup_CNTL.sv
RTL += rtl/camera_clk_gen.sv rtl/vga_outreg.sv
TB   = tb/cam_vga_if.sv tb/cam_vga_pkg.sv tb/tb_top.sv
SRC  = $(RTL) $(TB)

VCS_OPTS  = -full64 -sverilog -timescale=1ns/1ps -ntb_opts uvm
VCS_OPTS += -debug_access+all -kdb +define+FSDB +define+FAST_SETUP=$(FAST_SETUP)
VCS_OPTS += +incdir+"$(ROOT)/tb" -top tb_top -cm $(CM) -cm_dir "$(COVDIR)"
VCS_OPTS += -cm_hier "$(TOOL_COV_SCOPE)"
VCS_OPTS += $(FSDB_PLI) $(VCS_EXTRA)

SIMV_OPTS  = +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=$(INFO_LEVEL)
SIMV_OPTS += +ntb_random_seed=$(SEED) +PCLK_PHASE_NS=$(PHASE)
SIMV_OPTS += +FSDB_FILE="$(FSDB)" $(if $(filter 1,$(DUMP_WAVES)),+DUMP_WAVES)
SIMV_OPTS += -cm $(CM) -cm_dir "$(COVDIR)" -cm_name "$(RUN_ID)"
SIMV_OPTS += +UVM_MAX_QUIT_COUNT=30,NO $(RUN_EXTRA)

TESTS  = cam_vga_test camera_test camera_random_test camera_error_test camera_reset_test
TESTS += vga_test vga_random_test vga_gradient_test vga_reset_test
TESTS += sccb_test sccb_reset_test sccb_fault_test camera_to_vga_test

.PHONY: all check comp compile simv run regression covall cov report wave waves verdi clean remember check-coverage-scope

all:
	@echo "[SESSION] $(SESSION)"
	$(MAKE) regression SESSION=$(SESSION) FAST_SETUP=1
	$(MAKE) regression SESSION=$(SESSION) FAST_SETUP=0
	$(MAKE) remember
	@echo "[RESULTS] $(ROOT)/results/$(SESSION)"

# File existence only. VCS checks syntax/types; UVM checks behavior.
check:
	@test "$(FAST_SETUP)" = 0 -o "$(FAST_SETUP)" = 1 || { echo "FAST_SETUP must be 0 or 1"; exit 1; }
	@for f in $(SRC); do test -f "$$f" || { echo "Missing source: $$f"; exit 1; }; done
	@echo "Source files found (not a compile or simulation PASS)."

comp compile: check
	@test -n "$(SESSION)" || { echo "Empty SESSION is not allowed."; exit 1; }
	@command -v "$(VCS)" >/dev/null || { echo "VCS not found: load the server tool environment."; exit 1; }
	@test ! -e "$(BUILD)" && test ! -e "$(COVDIR)" || { echo "Build exists: choose a NEW SESSION."; exit 1; }
	mkdir -p "$(BUILD)"
	@printf '%s\n' 'begin line+cond+branch+tgl+fsm' \
	  '    -module uvm_custom_install_verdi_recording' 'end' > "$(TOOL_COV_SCOPE)"
	@echo "[COVERAGE_SCOPE] Tool recorder code coverage disabled; RTL/TB coverage unchanged."
	cd "$(BUILD)" && $(VCS) $(VCS_OPTS) $(foreach f,$(SRC),"$(ROOT)/$(f)") \
	  -Mdir=csrc -o "$(SIMV)" -l compile.log
	@printf '%s\n' "$(SESSION)" > "$(ROOT)/results/latest_build.$(SESSION).tmp"
	@mv -f "$(ROOT)/results/latest_build.$(SESSION).tmp" "$(ROOT)/results/latest_build.txt"

simv: comp
	$(MAKE) run
	$(MAKE) cov
	$(MAKE) remember

run:
	@test -n "$(SESSION)" && test -x "$(SIMV)" || { echo "No build: run make comp first; check FAST_SETUP."; exit 1; }
	@mkdir -p "$(BASE)/runs"
	@mkdir "$(RUN_DIR)" || { echo "Run exists: choose a new TAG."; exit 1; }
	cd "$(RUN_DIR)" && "$(SIMV)" $(SIMV_OPTS) -l run.log
	@grep -Fq '[TEST_RESULT] PASS ' "$(RUN_DIR)/run.log" || { echo "[RUN_RESULT] FAIL: $(RUN_ID)"; exit 1; }

# Compile once, run 13 base tests + 6 phase tests in the same profile.
regression: comp
	@set -e; for t in $(TESTS); do $(MAKE) run TEST=$$t PHASE=0; done
	@set -e; for p in 5 7 11; do \
	  for t in camera_random_test vga_random_test; do \
	    $(MAKE) run TEST=$$t PHASE=$$p RUN_EXTRA="$(RUN_EXTRA) +NUM_FRAMES=1"; \
	  done; \
	done
	$(MAKE) cov

covall: all

cov report:
	@test -n "$(SESSION)" && test -d "$(COVDIR)" || { echo "No completed coverage: run make all first; check FAST_SETUP."; exit 1; }
	$(URG) -full64 -dir "$(COVDIR)" -report "$(BASE)/report" -format both
	$(MAKE) check-coverage-scope

# Verify the actual server-generated report, not a GUI filter or a fabricated score.
# No scope files are retroactively added to old DBs. Rebuild in a NEW session.
check-coverage-scope:
	@test -f "$(TOOL_COV_SCOPE)" || { echo "Old build without recorder scope: run make all to create a NEW session."; exit 1; }
	@for f in modlist.txt hierarchy.txt; do \
	  test -s "$(BASE)/report/$$f" || { echo "Coverage scope not verified: missing report/$$f. Run make cov."; exit 1; }; \
	  grep -Fq 'uvm_custom_install_verdi_recording' "$(BASE)/report/$$f"; status=$$?; \
	  if test "$$status" = 0; then \
	    echo "[COVERAGE_SCOPE] FAIL: recorder remains in $$f. Check $(BUILD)/compile.log for -cm_hier warnings."; exit 1; \
	  elif test "$$status" != 1; then \
	    echo "[COVERAGE_SCOPE] FAIL: cannot read report/$$f (grep status $$status)."; exit 1; \
	  fi; \
	done
	@echo "[COVERAGE_SCOPE] OK: recorder absent from module/hierarchy reports (not a DUT PASS verdict)."

wave waves:
	@test -n "$(SESSION)" && test -f "$(FSDB)" || { echo "No waveform: make run with a new TAG and DUMP=1."; exit 1; }
	$(VERDI) -dbdir "$(SIMV).daidir" -ssf "$(FSDB)"

verdi: check-coverage-scope
	@test -n "$(SESSION)" && test -d "$(COVDIR)" || { echo "No completed coverage: run make all first; check FAST_SETUP."; exit 1; }
	@echo "[COVERAGE] $(COVDIR)"
	$(VERDI) -cov -covdir "$(COVDIR)"

# Called only after the requested run succeeds, never after a failed test.
remember:
	@test -n "$(SESSION)" && test -d "$(COVDIR)" || { echo "No coverage to remember."; exit 1; }
	@printf '%s\n' "$(SESSION)" > "$(ROOT)/results/latest_session.$(SESSION).tmp"
	@mv -f "$(ROOT)/results/latest_session.$(SESSION).tmp" "$(ROOT)/results/latest_session.txt"

clean:
	@echo "Existing results are preserved. Run make all to create a new session."
