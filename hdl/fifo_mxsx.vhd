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
generic(fifo_size : natural := 1024);
port (
	clk : in std_logic;
	reset : in std_logic;
	write : in std_logic;
	read_data : in std_logic;
	data_in : in std_logic_vector(0 downto 0);
	write_enable : in std_logic;
	is_empty : out std_logic;
	is_full : out std_logic;
	data_out : out std_logic_vector(15 downto 0));
end entity;

Architecture fifo_mxsx_1 of fifo_mxsx is


	component dual_ports_ram_16b_1b 
	generic (ram_size : natural := 1024);
	port(
		clk     : in  std_logic;
		-- 1 bits write port 
		write   : in  std_logic;
		addr_1b : in  std_logic_vector(13 downto 0); -- addr: 0 to 16383
		din_1b  : in  std_logic_vector(0 downto 0);
		-- 16 bits read port
		addr_16b: in  std_logic_vector(9 downto 0); -- addr: 0 to 1023
		dout_16b: out std_logic_vector(15 downto 0)
	);
	end component;

	-- DATA FIFO
	signal data_write_idx : integer range 0 to (fifo_size*16)-1 := 0;
	signal data_read_idx : integer range 0 to fifo_size-1 := 0;

	-- RAM signals
	signal read_addr : std_logic_vector(9 downto 0);
	signal write_addr : std_logic_vector(13 downto 0);
	signal write_ram : std_logic;

	-- Edge detection
	signal write_enable_falling : std_logic := '0';
	signal write_rising : std_logic := '0';
begin

	read_addr <= std_logic_vector(to_unsigned(data_read_idx, 10));
	write_addr <= std_logic_vector(to_unsigned(data_write_idx, 14));

	write_ram <= write_rising and write_enable;

	-- Ram instanciation
	inst_ram : dual_ports_ram_16b_1b
	generic map ( ram_size => fifo_size)
	port map ( 	clk => clk,
			write => write_ram,
			addr_1b => write_addr,
			din_1b => data_in,
			addr_16b => read_addr,
			dout_16b => data_out);

	ram_management : process(clk, reset)
	begin
		if reset = '1' then
			data_write_idx <= 0;
			data_read_idx <= 0;
		else
			if rising_edge(clk) then
				if write_ram = '1' then
					data_write_idx <= (data_write_idx + 1) mod (fifo_size*16);
				elsif write_enable_falling = '1' then -- Place write index on next 16 bit word
					data_write_idx <= ((data_write_idx / 16) + 1) * 16;
				end if;

				if read_data = '1' then
					data_read_idx <= (data_read_idx + 1) mod fifo_size;
				end if;
			end if;
		end if;
	end process;

	edge_detection : process(clk, reset)
	variable old_write_enable : std_logic := '0';
	variable old_write : std_logic := '0';
	begin
		if reset = '1' then
			write_enable_falling <= '0';
			old_write_enable := '0';
			old_write := '0';
		else
			if rising_edge(clk) then
				if (write_enable = '0') and (old_write_enable = '1') then
					write_enable_falling <= '1';
				else
					write_enable_falling <= '0';
				end if;

				if (write = '1') and (old_write = '0') then
					write_rising <= '1';
				else
					write_rising <= '0';
				end if;

				old_write_enable := write_enable;
				old_write := write;
			end if;
		end if;
	end process;

	-- Data FIFO status signals
	is_empty <= 	'1' when data_write_idx = data_read_idx*16 else
	'0';

	is_full <= 	'1' when ((data_write_idx + 1) mod fifo_size) = (data_read_idx*16) else
	'0';

end architecture fifo_mxsx_1;
