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
generic(	ram_num : natural := 1;
		ram_size : natural := 1024);
port (
	clk : in std_logic;
	reset : in std_logic;
	init : in std_logic;
	write : in std_logic;
	read_data : in std_logic;
	data_in : in std_logic;
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
	signal data_write_idx : integer range 0 to (ram_num*ram_size*16)-1 := 0;
	signal data_read_idx : integer range 0 to (ram_num*ram_size)-1 := 0;

	-- RAM signals
	signal read_addr : std_logic_vector(9+ram_num downto 0);
	signal write_addr : std_logic_vector(ram_num+13 downto 0);
	signal write_ram : std_logic;
	signal write_data : std_logic_vector(0 downto 0);

	type word_array is array (natural range <>) of std_logic_vector(15 downto 0);
	signal rams_out_data : word_array(ram_num - 1 downto 0) := (others => (others => '0'));
	signal write_rams : std_logic_vector(ram_num-1 downto 0);
begin

	-- Integer to vector conversion for read and write indexes
	read_addr <= std_logic_vector(to_unsigned(data_read_idx, ram_num+10));
	write_addr <= std_logic_vector(to_unsigned(data_write_idx, ram_num+14));

	-- Ram instanciation
	inst_rams : for i in 0 to ram_num-1 generate
		inst_ram : dual_ports_ram_16b_1b
		generic map ( ram_size => ram_size)
		port map ( 	clk => clk,
				write => write_rams(i),
				addr_1b => write_addr(13 downto 0),
				din_1b => write_data,
				addr_16b => read_addr(9 downto 0),
				dout_16b => rams_out_data(i));

		write_rams(i) <= 	'1' when (data_write_idx/ram_size=i) and (write_ram = '1')
					else '0';
	end generate inst_rams;

	-- Read datas
	data_out <= 	rams_out_data(data_read_idx/ram_size) when data_read_idx < ram_num*ram_size
			else (others => '0');

	-- Increment write index on each write in RAM
	-- Align write index to the next 16 bits word when write enable is falling (i.e transmission complete)
	write_index_management : process(clk, reset)
		variable write_enable_old : std_logic := '0';
	begin
		if reset = '1' then
			data_write_idx <= 0;
			write_enable_old := '0';
		elsif rising_edge(clk) then
			if init = '1' then
				data_write_idx <= 0;
			elsif write_ram = '1' and write_enable = '1' then --Increase index
				data_write_idx <= (data_write_idx + 1) mod (ram_size*16);
			elsif write_enable = '0' and write_enable_old = '1' then -- Place write index on next 16 bit word
				data_write_idx <= ((data_write_idx / 16) + 1) * 16;
			end if;

			-- Old value update
			write_enable_old := write_enable;
		end if;
	end process;

	-- Increment read index on each rising edge of "read_data" signal
	read_index_management : process(clk, reset)
		variable old_read_data : std_logic := '0';
	begin
		if reset = '1' then
			data_read_idx <= 0;
			old_read_data := '0';
		elsif rising_edge(clk) then
			if init = '1' then
				data_read_idx <= 0;
			elsif read_data = '1' and old_read_data = '0' then -- Increment index
				data_read_idx <= (data_read_idx + 1) mod ram_size;
			end if;

			-- Old value update
			old_read_data := read_data;
		end if;
	end process;

	-- A write in RAM is triggered by a rising edge of "write" signal when "write_enable" is high
	write_ram_management : process(clk, reset)
		variable old_write : std_logic := '0';
	begin
		if reset = '1' then
			write_ram <= '0';
			write_data <= "0";
			old_write := '0';
		elsif rising_edge(clk) then
			if (old_write = '0') and (write = '1') and (write_enable = '1') then
				write_ram <= '1';
				write_data(0) <= data_in;
			else
				write_ram <= '0';
			end if;

			old_write := write;
		end if;
	end process;

	-- Data FIFO status signals
	is_empty <= 	'1' when data_write_idx = data_read_idx*16 else
	'0';

	is_full <= 	'1' when ((data_write_idx + 1) mod ram_size) = (data_read_idx*16) else
	'0';

end architecture fifo_mxsx_1;
