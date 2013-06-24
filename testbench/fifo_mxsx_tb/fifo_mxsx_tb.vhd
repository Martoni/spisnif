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
-- File          : fifo_tb.vhd
-- Created on    : 04/06/2013
-- Author        : Fabien Marteau <fabien.marteau@armadeus.com>
--
--*********************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

Entity fifo_mxsx_tb is
end entity;

Architecture fifo_tb_1 of fifo_mxsx_tb is

CONSTANT HALF_PERIODE_IMX_CLK  : time :=  5 ns;  -- Half clock period of imx weim clk
CONSTANT FIFO_BRAM_NUM : natural := 4;

signal imx_clk : std_logic;
signal reset : std_logic;
signal write : std_logic;
signal read_data : std_logic;
signal data_in : std_logic_vector(0 downto 0);
signal write_enable : std_logic;
signal is_empty : std_logic;
signal is_full : std_logic;
signal data_out : std_logic_vector(15 downto 0);

component fifo_mxsx
port(
	clk : in std_logic;
	reset : in std_logic;
	write : in std_logic;
	read_data : in std_logic;
	data_in : in std_logic_vector(0 downto 0);
	write_enable : in std_logic;
	is_empty : out std_logic;
	is_full : out std_logic;
	data_out : out std_logic_vector(15 downto 0));
end component;

begin

-- fifo connections
    inst_fifo_mxsx : fifo_mxsx
    port map (
	    clk          => imx_clk,
	    reset        => reset,
	    write        => write,
	    read_data    => read_data,
	    data_in      => data_in,
	    write_enable => write_enable,
	    is_empty     => is_empty,
	    is_full      => is_full,
	    data_out     => data_out);


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
        reset <= '1';
        write <= '0';
        read_data <= '0';
        data_in <= "0";
        write_enable <= '0';
        wait for 20 ns;
        reset <= '0';

        wait for 20 ns;
        data_in <= "1";
        wait for 20 ns;
        write_enable <= '1';
        write <= '1';
        wait for 20 ns;
        wait for 20 ns;
        wait for 20 ns;
        write_enable <= '0';
        write <= '0';
        wait for 20 ns;
        write_enable <= '1';
        write <= '1';
        for i in 0 to 16 loop
            wait for 20 ns;
        end loop;
        write_enable <= '0';
        write <= '0';
        wait for 20 ns;
        read_data <= '1';

        wait for 20 ns;
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

end architecture fifo_tb_1;

