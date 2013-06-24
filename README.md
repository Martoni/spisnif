spisnif
=======

Virtual component (in VHDL) with Linux driver to snif SPI protocol

Introduction
------------

The objective of the spisnif component is to log SPI data transfered on MISO and
MOSI.

All frames that circulate on the bus must be transfered to Linux in real time.
To do that we will use 2 FIFO, one for MISO and one for MOSI.
Data will be logged when chip select low and on rising (or falling depending
configuration) edge of SCK.

Requirements
------------

To simulate the fifo_mxsx component with GHDL, a compiled version of the UNISIM library is requested. Please follow this wiki page: http://www.armadeus.com/wiki/index.php?title=How_to_simulate_post_synthesis_and_post_place_%26_route_design_with_GHDL
