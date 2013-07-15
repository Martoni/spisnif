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
-- File          : fifo_packet.vhd
-- Created on    : 17/06/2013
-- Author        : Kevin Joly <joly.kevin25@gmail.com> &  Fabien Marteau <fabien.marteau@armadeus.com>
--
--*********************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

Entity fifo_packet is
generic (
    ram_num          : natural := 3;
    ram_size : natural := 1024
);
port (
    gls_reset : in std_logic;
    gls_clk : in std_logic;
    -- Wb interface
    wb_data : out std_logic_vector(15 downto 0);
    wb_rd : in std_logic;
    wb_over_flag : out std_logic;
    -- Db interface
    db_write : in std_logic;
    db_data : in std_logic_vector(15 downto 0);
    -- pfifo signals
    pf_full : out std_logic;
    pf_empty : out std_logic;
    pf_init : in std_logic);
end entity;

Architecture fifo_packet_1 of fifo_packet is
    -- read/write pointers
    signal wb_count : natural range 0 to (ram_num * ram_size) := 0;
    signal db_count : natural range 0 to (ram_num * ram_size) := 0;
    signal wb_count_slv : std_logic_vector(ram_num + 9 downto 0) := (others => '0');
    signal db_count_slv : std_logic_vector(ram_num + 9 downto 0) := (others => '0');
    -- triggers
    signal wb_rd_rise : std_logic;
    signal wb_rd_fall : std_logic;
    signal db_write_rise : std_logic;
    signal db_write_fall : std_logic;

    type word_array is array (natural range <>) of std_logic_vector(15 downto 0);
    signal rams_out_data : word_array(ram_num - 1 downto 0) := (others => (others => '0'));
    signal rams_write_en : std_logic_vector(ram_num - 1 downto 0) := (others => '0');

    component xilinx_dual_port_ram
        generic( ram_size : natural := 1024);
        port(
           clk   : in  std_logic;
           we    : in  std_logic;
           addr_a: in  std_logic_vector(9 downto 0);
           addr_b: in  std_logic_vector(9 downto 0);
           din_b : in  std_logic_vector(15 downto 0);
           dout_a: out std_logic_vector(15 downto 0)
        );
    end component xilinx_dual_port_ram;

begin
    -- Flags
    wb_over_flag <= '1' when wb_count >= db_count else '0';
    pf_full <= '1' when db_count = (ram_num * ram_size) else '0';
    pf_empty <= '1' when db_count = wb_count else '0';

    db_count_slv <= std_logic_vector(to_unsigned(db_count, ram_num+10));
    wb_count_slv <= std_logic_vector(to_unsigned(wb_count, ram_num+10));

    wb_data <= rams_out_data(wb_count / ram_size) when wb_count /=
               ram_num*ram_size else (others => '0');

    -- Rams instanciation
    rams_instances : for i in 0 to ram_num-1 generate
        rams_instance : xilinx_dual_port_ram
        generic map ( ram_size => ram_size)
        port map (
            clk    => gls_clk,
            we     => rams_write_en(i),
            addr_a => wb_count_slv(9 downto 0),
            addr_b => db_count_slv(9 downto 0),
            din_b  => db_data,
            dout_a => rams_out_data(i)
        );

        rams_write_en(i) <= '1' when (db_count/ram_size = i) and db_write = '1'
                            else '0';
    end generate rams_instances;

    triggers : process(gls_clk, gls_reset)
        variable wb_rd_old : std_logic;
        variable db_write_old : std_logic;
    begin
        if gls_reset = '1' then
                db_count <= 0;
                wb_count <= 0;
        elsif rising_edge(gls_clk) then
            if pf_init = '1' then
                wb_count <= 0;
                db_count <= 0;
            else
                -- wb_rd edges
                if wb_rd_old = '1' and (wb_rd = '0') then
                    wb_count <= wb_count + 1;
                else
                    wb_count <= wb_count;
                end if;
                wb_rd_old := wb_rd;

                -- db_write edges
                if db_write_old = '1' and (db_write = '0') then
                    db_count <= db_count + 1;
                else
                    db_count <= db_count;
                end if;
                db_write_old := db_write;
            end if;
        end if;
    end process triggers;




end architecture fifo_packet_1;

