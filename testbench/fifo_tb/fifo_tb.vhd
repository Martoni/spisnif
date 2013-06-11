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

Entity fifo_tb is
end entity;

Architecture fifo_tb_1 of fifo_tb is

    CONSTANT HALF_PERIODE_IMX_CLK  : time :=  5 ns;  -- Half clock period of imx weim clk
    CONSTANT FIFO_BRAM_NUM : natural := 4;

    signal imx_clk : std_logic;

begin

    -- print time debug
    time_count : process
        variable time_c : natural := 0;
    begin
        report "Time "&integer'image(time_c)&" us";
        wait for 10 us;
        time_c := time_c + 10;
    end process time_count;

    -- fifo connections

    stimulis : process
    begin
        reset <= '1';
        wait for 20 ns;
        reset <= '0';
        wait for 20 us;
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

