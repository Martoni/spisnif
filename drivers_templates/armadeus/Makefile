#
# Makefile for the ACU550 encoder driver
#

ifneq ($(KERNELRELEASE),)

obj-m	+= spisnif.o
obj-m	+= board_spisnif.o

else

ARMADEUS_BASE_DIR=../../../../..
include $(ARMADEUS_BASE_DIR)/Makefile.in

KDIR    := $(ARMADEUS_LINUX_DIR)
PWD	:= $(shell pwd)

# Armadeus custom drivers common targets:
include ../../Makefile.in

endif

