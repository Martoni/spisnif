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
-- File          : fifo_mxsx.vhd
-- Created on    : 13/06/2013
-- Author        : Kevin Joly <joly.kevin25@gmail.com> &  Fabien Marteau <fabien.marteau@armadeus.com>
--
--*********************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

Entity fifo_mxsx is
generic(fifo_size : integer := 32);
port (
	clk : in std_logic;
	reset : in std_logic;
	write : in std_logic;
	read_data : in std_logic;
	read_desc : in std_logic;
	data_in : in std_logic;
	write_enable : in std_logic;
	is_empty : out std_logic;
	is_full : out std_logic;
	data_out : out std_logic_vector(15 downto 0));
end entity;

Architecture fifo_mxsx_1 of fifo_mxsx is
	-- RAM definition
	type array_t is array (0 to fifo_size) of std_logic_vector(15 downto 0);

	-- FIFOs
	signal data : array_t := (others => (others => '0'));
	signal desc : array_t := (others => (others => '0'));

	-- DATA FIFO
	signal data_write_idx : integer range 0 to fifo_size-1 := 0;
	signal data_read_idx : integer range 0 to fifo_size-1 := 0;

	-- DESC FIFO
	signal desc_write_idx : integer range 0 to fifo_size-1 := 0;
	signal desc_read_idx : integer range 0 to fifo_size-1 := 0;

	-- Bit index for DATA FIFO write
	signal bit_index : integer range 0 to 15;

	-- Number of bits in one packet
	signal bit_packet_count : integer range 0 to (2**16) -1;

begin

	-- Write process
	write_proc : process(clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then --INIT
				bit_index <= 0;
				bit_packet_count <= 0;
				data_write_idx <= 0;
				desc_write_idx <= 0;
			else
				if write_enable = '1' and write = '1' then
					data(data_write_idx)(bit_index) <= data_in; -- Store bit
					bit_packet_count <= bit_packet_count + 1; --increment packet bit count

					if bit_index = 15 then --Data RAM segment full
						bit_index <= 0; --Reset bit index
	
						if data_write_idx = fifo_size - 1 then --TODO check if "mod" is lighter on RTL
							data_write_idx <= 0;
						else
							data_write_idx <= data_write_idx + 1; --Increment data write index
						end if;
					else
						bit_index <= bit_index +1; --increment bit index
					end if;
	
				elsif falling_edge(write_enable) then -- Capture complete

					if data_write_idx = fifo_size - 1 then
						data_write_idx <= 0;
					else
						data_write_idx <= data_write_idx + 1; --Increment data write index
					end if;

					if desc_write_idx = fifo_size - 1 then
						desc_write_idx <= 0;
					else
						desc_write_idx <= desc_write_idx + 1; --increment desc index
					end if;

					bit_index <= 0; --Reset bit index
					desc(desc_write_idx) <= std_logic_vector(to_unsigned(bit_packet_count, 16)); -- Store bits packet count
					bit_packet_count <= 0; -- Reset bit counter
				end if;
			end if;
		end if;
	end process;

	-- Read process
	read_proc : process(clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then -- Init
				desc_read_idx <= 0;
				data_read_idx <= 0;
				data_out <= (others => '0');
			elsif read_data = '1' then -- Read on DATA FIFO
				data_out <= data(data_read_idx); --Affect output with data

				if data_read_idx = fifo_size - 1 then
					data_read_idx <= 0;
				else
					data_read_idx <= data_read_idx + 1; --Remove the data from DATA FIFO
				end if
				;
			elsif read_desc = '1' then -- Read on DESC FIFO
				data_out <= desc(desc_read_idx); --Affect output with DESC value
				if desc_read_idx = fifo_size - 1 then
					desc_read_idx <= 0;
				else
					desc_read_idx <= desc_read_idx + 1;--Remove DESC value from DESC FIFO
				end if;
			end if;
		end if;
	end process;

	-- Data FIFO status signals
	is_empty <= 	'1' when data_write_idx = data_read_idx else
	'0';

	is_full <= 	'1' when (data_write_idx + 1) mod fifo_size = data_read_idx else
	'0';

end architecture fifo_mxsx_1;
