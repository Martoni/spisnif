# Makefile for ghdl simulation
# version 1.2
# Fabien Marteau

# project name
PROJECT=fifo_mxsx

# vhdl files
TESTBENCH_FILE=$(PROJECT)_tb.vhd
FILES=../../hdl/fifo.vhd

# testbench
SIMTOP =$(PROJECT)_tb
# Simu break condition
GHDL_SIM_OPT    = --assert-level=error
#GHDL_SIM_OPT    = --stop-time=500ns
XILINX=/opt/Xilinx/13.2/ISE_DS/ISE/

##############################
# GHDL options
##############################

SIMDIR = simu

GHDL_CMD        	 =ghdl
GHDL_SIMU_FLAGS      = --ieee=synopsys -P$(XILINX)/ghdl/unisim --warn-no-vital-generic
GHDL_SYNTHESIS_FLAGS = --ieee=synopsys -P$(XILINX)/ghdl/unisim --warn-no-vital-generic
GHDL_PANDR_FLAGS     = --ieee=synopsys -P$(XILINX)/ghdl/simprim --warn-no-vital-generic

VIEW_CMD        = gtkwave

OBJS_FILES      = $(patsubst %.vhd, %.o, $(notdir $(FILES)) )
OBJS_SIMFILES   = $(patsubst %.vhd, %.o, $(notdir $(SIMFILES)) )

########################
# Simulation with GHDL
########################

help:
	@echo 'Cleaning:'
	@echo '  clean      - delete simulation directory'
	@echo
	@echo 'simulate:'
	@echo '  ghdl-simu      - make behavioural simulation'
	@echo '  ghdl-synthesis - make post synthesis simulation'
	@echo '  ghdl-pr        - make post place and route simulation'
	@echo ' '
	@echo 'view result:'
	@echo '  ghdl-view      - Launch wave view with gtk-waves'

ghdl-simu : ghdl-compil ghdl-run
ghdl-synthesis : ghdl-compil-synthesis ghdl-run
ghdl-pr : ghdl-compil-pr ghdl-run

ghdl-compil :
	mkdir -p simu
	$(GHDL_CMD) -i $(GHDL_SIMU_FLAGS) --workdir=simu --work=work $(TESTBENCH_FILE) $(LIBRARY_FILE) $(FILES)
	$(GHDL_CMD) -m $(GHDL_SIMU_FLAGS) --workdir=simu --work=work $(SIMTOP)
	@mv $(SIMTOP) simu/$(SIMTOP)

ghdl-run :
	@$(SIMDIR)/$(SIMTOP) $(GHDL_SIM_OPT) --vcdgz=$(SIMDIR)/$(SIMTOP).vcdgz --wave=$(SIMDIR)/$(SIMTOP).ghw

ghdl-view:
	$(VIEW_CMD) $(SIMDIR)/$(SIMTOP).ghw

ghdl-view-vcdgz:
	gunzip --stdout $(SIMDIR)/$(SIMTOP).vcdgz | $(VIEW_CMD) --vcd

clean :
	$(GHDL_CMD) --clean --workdir=simu
	-rm -rf simu
