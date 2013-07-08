--
-- Copyright (c) ARMadeus Systems 2011
--
--*********************************************************************
--
-- File          : spisnif.vhd
-- Created on    : 20/09/2012
-- Author        : Kevin Joly <joly.kevin25@gmail.com
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
    fifo_miso_size : natural := 1024;
    fifo_mosi_size : natural := 1024;
    fifo_packet_ram_num : natural := 3;
    fifo_packet_ram_size : natural := 1024
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
    cs   : in std_logic);
end entity;

---------------------------------------------------------------------------
Architecture spisnif_1 of spisnif is
---------------------------------------------------------------------------

	component fifo_mxsx
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
	end component fifo_mxsx;
	
	component fifo_packet
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
	    pf_init : in std_logic);
	end component fifo_packet;

	-- Mosi signals
	signal fifo_mosi_read : std_logic;
	signal fifo_mosi_empty : std_logic;
	signal fifo_mosi_full : std_logic;
	signal fifo_mosi_out : std_logic_vector(15 downto 0);

	-- Miso signals
	signal fifo_miso_read : std_logic;
	signal fifo_miso_empty : std_logic;
	signal fifo_miso_full : std_logic;
	signal fifo_miso_out : std_logic_vector(15 downto 0);

	-- Miso et Mosi
	signal write_enable : std_logic;
	signal fifo_write : std_logic;

	-- Packet signals
	signal fifo_packet_out : std_logic_vector(15 downto 0);
	signal fifo_packet_read : std_logic;
	signal packet_full : std_logic;
	signal fifo_packet_over : std_logic;
	signal fifo_packet_write : std_logic;
	signal fifo_packet_in : std_logic_vector(15 downto 0);

	-- bit 0 CPOL
	-- bit 1 CPHA
	-- bit 2 CSPOL
	signal control : std_logic_vector(15 downto 0);

	signal packet_count : integer range 0 to 2**16-1 := 0;

	signal fifo_write_rising : std_logic := '0';
begin

	fifo_mosi_inst : fifo_mxsx
	generic map(fifo_size => fifo_mosi_size)
	port map(
		clk => gls_clk,
		reset => gls_reset,
		write => fifo_write,
		read_data => fifo_mosi_read,
		data_in(0) => mosi,
		write_enable => write_enable,
		is_empty => fifo_mosi_empty,
		is_full => fifo_mosi_full,
		data_out => fifo_mosi_out);

	fifo_miso_inst : fifo_mxsx
	generic map(fifo_size => fifo_miso_size)
	port map(
		clk => gls_clk,
		reset => gls_reset,
		write => fifo_write,
		read_data => fifo_miso_read,
		data_in(0) => miso,
		write_enable => write_enable,
		is_empty => fifo_miso_empty,
		is_full => fifo_miso_full,
		data_out => fifo_miso_out);

	fifo_packet_inst : fifo_packet
	generic map(	ram_num => fifo_packet_ram_num,
			ram_size => fifo_packet_ram_size)
	port map(
		gls_reset => gls_reset,
		gls_clk => gls_clk,
		wb_data => fifo_packet_out,
		wb_rd => fifo_packet_read,
		wb_over_flag => fifo_packet_over,
		db_write => fifo_packet_write,
		db_data => fifo_packet_in,
		pf_full => packet_full,
		pf_init => gls_reset); -- TODO

	write_enable <= cs xnor control(2);
	fifo_write <= (sck xnor control(0)) xnor control(1);
	fifo_packet_in <= std_logic_vector(to_unsigned(packet_count, 16));

	-- Wishbone interface
	wishbone : process(gls_clk, gls_reset)
	begin
		if gls_reset = '1' then
			control <= (others => '0');
			wbs_readdata <= (others => '0');
		elsif rising_edge(gls_clk) then
			if wbs_write = '1' and (wbs_strobe = '1' or wbs_cycle = '1')then
				case wbs_add is
					when "0000" => control <= wbs_writedata;
					when others => control <= control;
				end case;
				fifo_mosi_read <= '0';
				fifo_miso_read <= '0';
				fifo_packet_read <= '0';
			elsif wbs_write = '0' and (wbs_strobe = '1' or wbs_cycle = '1') then
				case wbs_add is
					when "0000" => 	wbs_readdata <= control;
					when "0001" =>	wbs_readdata <= fifo_mosi_out;
							fifo_mosi_read <= '1';
							fifo_miso_read <= '0';
							fifo_packet_read <= '0';
					when "0010" =>	wbs_readdata <= fifo_miso_out;
							fifo_miso_read <= '1';
							fifo_mosi_read <= '0';
							fifo_packet_read <= '0';
					when "0011" =>	wbs_readdata <= fifo_packet_out;
							fifo_packet_read <= '1';
							fifo_mosi_read <= '0';
							fifo_miso_read <= '0';
					when others => wbs_readdata <= (others => '0');
				end case;
			else
				fifo_mosi_read <= '0';
				fifo_miso_read <= '0';
				fifo_packet_read <= '0';
			end if;
		end if;
	end process;

	write_enable_falling_edge : process(gls_clk, gls_reset)
		variable write_enable_old : std_logic := '0';
	begin
		if gls_reset = '1' then
			write_enable_old := '0';
		elsif rising_edge(gls_clk) then

			if (write_enable_old = '1') and (write_enable = '0') then
				fifo_packet_write <= '1';
			else
				fifo_packet_write <= '0';
			end if;

			write_enable_old := write_enable;
		end if;
	end process;

	fifo_write_rising_edge : process(gls_clk, gls_reset)
		variable fifo_write_old : std_logic := '0';
	begin
		if gls_reset = '1' then
			fifo_write_old := '0';
			fifo_write_rising <= '0';
		elsif rising_edge(gls_clk) then
			if (fifo_write_old = '0') and (fifo_write = '1') then
				fifo_write_rising <= '1';
			else
				fifo_write_rising <= '0';
			end if;

			fifo_write_old := fifo_write;
		end if;
	end process;

	packet_count_proc : process(gls_clk, gls_reset)
	begin
		if gls_reset = '1' then
			packet_count <= 0;
		elsif rising_edge(gls_clk) then
			if fifo_packet_write = '1' then
				packet_count <= 0;
			elsif fifo_write_rising = '1' then
				packet_count <= (packet_count + 1) mod 2**16;
			end if;
		end if;
	end process;

end architecture spisnif_1;
