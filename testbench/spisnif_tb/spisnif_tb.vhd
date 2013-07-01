--
-- Copyright (c) Armadeus system 2013
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation; either version 2, or (at your option)
-- any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
--*********************************************************************
--
-- File          : spi_tb.vhd
-- Created on    : 27/06/2013
-- Author        : 	Fabien Marteau <fabien.marteau@armadeus.com> &
--			Kevin Joly <joly.kevin25@gmail.com
--
--*********************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

Entity spisnif_tb is
end entity;

Architecture spisnif_tb_1 of spisnif_tb is

CONSTANT HALF_PERIODE_IMX_CLK  : time :=  5 ns;  -- Half clock period of imx weim clk
CONSTANT FIFO_BRAM_NUM : natural := 4;

signal imx_clk : std_logic;
signal reset : std_logic;
signal wbs_add       : std_logic_vector(3 downto 0);
signal wbs_writedata : std_logic_vector(15 downto 0);
signal wbs_readdata  : std_logic_vector(15 downto 0);
signal wbs_strobe    : std_logic;
signal wbs_cycle     : std_logic;
signal wbs_write     : std_logic;
signal wbs_ack       : std_logic;
 -- interrupt
signal wbs_irq     : std_logic;
-- spi
signal sck  : std_logic;
signal mosi : std_logic;
signal miso : std_logic;
signal cs   : std_logic;

component spisnif
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
    cs   : in std_logic);
end component;

begin

	-- fifo connections
	inst_spisnif : spisnif
	port map (
	    -- Syscon signals
	    gls_clk => imx_clk,
	    gls_reset => reset,
	    -- Wishbone signals
	    wbs_add => wbs_add,
	    wbs_writedata => wbs_writedata,
	    wbs_readdata => wbs_readdata,
	    wbs_strobe => wbs_strobe,
	    wbs_cycle => wbs_cycle,
	    wbs_write => wbs_write,
	    wbs_ack => wbs_ack,
	    -- interrupt
	    wbs_irq => wbs_irq,
	    -- spi
	    sck => sck,
	    mosi => mosi,
	    miso => miso,
	    cs => cs);

    -- print time debug
    time_count : process
    variable time_c : natural := 0;
    begin
        report "Time "&integer'image(time_c)&" us";
        wait for 10 us;
        time_c := time_c + 10;
    end process time_count;


    stimulis : process
    begin
	-- Test with CPHA=0 CPOL=0 CSPOL=0
	reset <= '1';
	wbs_add <= (others => '0');
	wbs_writedata <= (others => '0');
	wbs_strobe <= '0';
	wbs_cycle <= '0';
	wbs_write <= '0';
	sck <= '0';
	mosi <= '0';
	miso <= '0';
	cs <= '1';
	wait for 20 ns;
	reset <= '0';
	wait for 20 ns; 
	cs <= '0'; -- Select component
	-- Bit 1
	mosi <= '0';
	miso <= '1';
	wait for 20 ns; 
	sck <= '1'; -- Transmit
	wait for 20 ns;
	-- Bit 2
	sck <= '0';
	mosi <= '1';
	miso <= '0';
	wait for 20 ns; 
	sck <= '1'; -- Transmit
	wait for 20 ns;
	-- Bit 3
	sck <= '0';
	mosi <= '1';
	miso <= '1';
	wait for 20 ns; 
	sck <= '1'; -- Transmit

	wait for 20 ns;
	sck <= '0';
	wait for 20 ns; 
	cs <= '1'; -- end of transfert
	wait for 40 ns; 

	-- Test with CPHA=1 CPOL=0 CSPOL=0
	wbs_writedata(0) <= '0';
	wbs_writedata(1) <= '1';
	wbs_writedata(2) <= '0';
	wbs_strobe <= '1';
	wbs_write <= '1';
	wait for 2*HALF_PERIODE_IMX_CLK;
	cs <= '0'; -- Select component
	-- Bit 1
	mosi <= '0';
	miso <= '1';
	sck <= '1';
	wait for 20 ns; 
	sck <= '0'; -- Transmit
	wait for 20 ns;
	-- Bit 2
	sck <= '1';
	mosi <= '1';
	miso <= '0';
	wait for 20 ns; 
	sck <= '0'; -- Transmit
	wait for 20 ns;
	-- Bit 3
	sck <= '1';
	mosi <= '1';
	miso <= '1';
	wait for 20 ns; 
	sck <= '0'; -- Transmit

	wait for 20 ns;
	sck <= '1';
	wait for 20 ns; 
	cs <= '1'; -- end of transfert
	wait for 40 ns;

	-- Test with CPHA=0 CPOL=1 CSPOL=0
	wbs_writedata(0) <= '1';
	wbs_writedata(1) <= '0';
	wbs_writedata(2) <= '0';
	wbs_strobe <= '1';
	wbs_write <= '1';
	wait for 2*HALF_PERIODE_IMX_CLK;
	cs <= '0'; -- Select component
	-- Bit 1
	mosi <= '0';
	miso <= '1';
	sck <= '1';
	wait for 20 ns; 
	sck <= '0'; -- Transmit
	wait for 20 ns;
	-- Bit 2
	sck <= '1';
	mosi <= '1';
	miso <= '0';
	wait for 20 ns; 
	sck <= '0'; -- Transmit
	wait for 20 ns;
	-- Bit 3
	sck <= '1';
	mosi <= '1';
	miso <= '1';
	wait for 20 ns; 
	sck <= '0'; -- Transmit

	wait for 20 ns;
	sck <= '1';
	wait for 20 ns; 
	cs <= '1'; -- end of transfert
	wait for 40 ns;

	-- Test with CPHA=1 CPOL=1 CSPOL=0
	wbs_writedata(0) <= '1';
	wbs_writedata(1) <= '1';
	wbs_writedata(2) <= '0';
	wbs_strobe <= '1';
	wbs_write <= '1';
	wait for 2*HALF_PERIODE_IMX_CLK;
	cs <= '0'; -- Select component
	-- Bit 1
	mosi <= '0';
	miso <= '1';
	sck <= '1';
	wait for 20 ns; 
	sck <= '0'; -- Transmit
	wait for 20 ns;
	-- Bit 2
	sck <= '1';
	mosi <= '1';
	miso <= '0';
	wait for 20 ns; 
	sck <= '0'; -- Transmit
	wait for 20 ns;
	-- Bit 3
	sck <= '1';
	mosi <= '1';
	miso <= '1';
	wait for 20 ns; 
	sck <= '0'; -- Transmit

	wait for 20 ns;
	sck <= '1';
	wait for 20 ns; 
	cs <= '1'; -- end of transfert
	wait for 40 ns;

        assert false report "*** End of test ***" severity error;
    end process stimulis;

    ------------
    -- clocks --
    ------------
    imx_clk_p : process
    begin
        imx_clk <= '1';
        wait for HALF_PERIODE_IMX_CLK;
        imx_clk <= '0';
        wait for HALF_PERIODE_IMX_CLK;
    end process imx_clk_p;

end architecture spisnif_tb_1;

