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
