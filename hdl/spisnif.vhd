--
-- Copyright (c) ARMadeus Systems 2011
--
--*********************************************************************
--
-- File          : spisnif.vhd
-- Created on    : 20/09/2012
-- Author        : Fabien Marteau <fabien.marteau@armadeus.com>
--
--*********************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

---------------------------------------------------------------------------
Entity spisnif is
---------------------------------------------------------------------------
generic(
    id : natural := 1;
);
port
(
    -- Syscon signals
    gls_reset    : in std_logic;
    gls_clk      : in std_logic;
    -- Wishbone signals
    wbs_add       : in std_logic_vector(3 downto 0);
    wbs_writedata : in std_logic_vector(15 downto 0);
    wbs_readdata  : out std_logic_vector(15 downto 0);
    wbs_strobe    : in std_logic;
    wbs_cycle     : in std_logic;
    wbs_write     : in std_logic;
    wbs_ack       : out std_logic;
    -- interrupt
    wbs_irq     : out std_logic;
    -- spi
    sck  : in std_logic;
    mosi : in std_logic;
    miso : in std_logic;
    cs   : in std_logic
end entity;

---------------------------------------------------------------------------
Architecture spisnif_1 of spisnif is
---------------------------------------------------------------------------

begin

end architecture spisnif_1;

