--
-- Copyright (c) ARMadeus Project 2013
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
-- File          : spigen_pkg.vhd
-- Created on    : 08/07/2013
-- Author        : Fabien Marteau <fabien.marteau@armadeus.com>
--
--*********************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

package spigen_pkg is
    procedure spi_send_frame(
                mosi        : std_logic_vector;
                miso        : std_logic_vector;
                clock_per   : time;
                cpol        : std_logic;
                cpha        : std_logic;
                cspol       : std_logic;
                signal spi_clock : out std_logic;
                signal spi_mosi  : out std_logic;
                signal spi_miso  : out std_logic;
                signal spi_cs    : out std_logic);
end package spigen_pkg;

package body spigen_pkg is
    procedure spi_send_frame(
                mosi        : std_logic_vector;
                miso        : std_logic_vector;
                clock_per   : time;
                cpol        : std_logic;
                cpha        : std_logic;
                cspol       : std_logic;
                signal spi_clock : out std_logic;
                signal spi_mosi  : out std_logic;
                signal spi_miso  : out std_logic;
                signal spi_cs    : out std_logic) is
    begin
        assert (mosi'high = miso'high ) and (mosi'low = miso'low)
            report "ERROR: mosi and miso must have the same size" severity error;

        spi_cs <= cspol; 
        spi_clock <= cpol;
        wait for clock_per/2;

        for i in mosi'left to mosi'right loop
                spi_clock <= cpha;
                spi_mosi <= mosi(i);
                spi_miso <= miso(i);
                wait for clock_per/2;
                spi_clock <= not cpha;
                wait for clock_per/2;
        end loop;
        -- end of frame
        spi_cs <= not cspol;
        spi_clock <= cpol;
    end procedure spi_send_frame;

end package body spigen_pkg;
