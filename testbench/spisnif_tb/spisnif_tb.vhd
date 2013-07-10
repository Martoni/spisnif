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
--			        Kevin Joly <joly.kevin25@gmail.com
--
--*********************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

use work.wishbone_test_pkg.all;
use work.spigen_pkg.all;

Entity spisnif_tb is
end entity;

Architecture spisnif_tb_1 of spisnif_tb is

    CONSTANT HALF_PERIODE_IMX_CLK  : time :=  5 ns;  -- Half clock period of imx weim clk
    CONSTANT FIFO_BRAM_NUM : natural := 4;

    -- registers mapping
    CONSTANT REG_CONTROL     : std_logic_vector(2 downto 0) := "000";
    CONSTANT REG_FIFO_MOSI   : std_logic_vector(2 downto 0) := "001";
    CONSTANT REG_FIFO_MISO   : std_logic_vector(2 downto 0) := "010";
    CONSTANT REG_FIFO_PACKET : std_logic_vector(2 downto 0) := "011";
    CONSTANT REG_STATUS      : std_logic_vector(2 downto 0) := "100";
--  CONSTANT REG_            : std_logic_vector(2 downto 0) := "101";
--  CONSTANT REG_            : std_logic_vector(2 downto 0) := "110";
    CONSTANT REG_ID          : std_logic_vector(2 downto 0) := "111";

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

    signal value : std_logic_vector(15 downto 0);
    signal cspol : std_logic;
    signal cpha  : std_logic;
    signal cpol  : std_logic;

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


    -- Stimulis for SPI bus
    spi_stimulis : process
    begin
	    -- Test with CPHA=0 CPOL=0 CSPOL=0
	    sck <= '0';
	    mosi <= '0';
	    miso <= '0';
	    cs <= '1';
        wait for 10 us;
        spi_send_frame(mosi => "101101", miso => "000111",
                       clock_per => 33 us,
                       cpol => '0', cpha => '0', cspol => '0',
                       spi_clock => sck,
                       spi_mosi => mosi,
                       spi_miso => miso,
                       spi_cs => cs);

        wait for 1000 ms; -- do not loop
    end process;

    -- main stimulis process
    stimulis : process
    begin
	    reset <= '1';
	    wbs_add <= (others => '0');
	    wbs_writedata <= (others => '0');
	    wbs_strobe <= '0';
	    wbs_cycle <= '0';
	    wbs_write <= '0';
        wait for 1 us;
        reset <= '0';

        -- read component identifiant
        wishbone_read(REG_ID,  value,
                      imx_clk, wbs_strobe, wbs_cycle,
                      wbs_write, wbs_ack, wbs_add(2 downto 0),
                      wbs_writedata, wbs_readdata, 5);
        report "Identifiant read:"&integer'image(to_integer(unsigned(value)))&".";

        -- write configuration CSPOL=0, CPOL=0, CPHA=0
        wishbone_write( REG_CONTROL, x"0000",
                        imx_clk, wbs_strobe, wbs_cycle,
                        wbs_write, wbs_ack, wbs_add(2 downto 0),
                        wbs_writedata, wbs_readdata, 5);

        wait for 500 us;
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

