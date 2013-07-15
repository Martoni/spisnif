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
		data_in : in std_logic;
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
	    pf_empty : out std_logic;
	    pf_init : in std_logic;
	    pf_count : out std_logic_vector(10 downto 0));
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
	signal fifo_packet_full : std_logic;
	signal fifo_packet_empty : std_logic;
	signal fifo_packet_over : std_logic;
	signal fifo_packet_write : std_logic;
	signal fifo_packet_in : std_logic_vector(15 downto 0);

	-- Config register
	---------------
	-- bit 0 is CPOL
	-- bit 1 is CPHA
	-- bit 2 is CSPOL
	signal config : std_logic_vector(15 downto 0);

	-- Control register
	---------------
	-- bits 10 downto 0 is irq_pnum_trig
	-- bit 14 is irq_ack
	-- bit 15 is reset
	signal control : std_logic_vector(15 downto 0);

	-- Status register
	---------------
	-- bit 10 downto 0 is packet_num
	-- bit 13 is fifo_mxsx_full
	-- bit 14 is fifo_full
	-- bit 15 is fifo_empty
	signal status : std_logic_vector(15 downto 0);

	-- Number of bits received in a packet
	signal bit_count : integer range 0 to 2**16-1 := 0;

	-- Number of packet received
	signal packet_count : std_logic_vector(10 downto 0);

	-- Sampled SPI signals
	signal mosi_tmp, mosi_sync : std_logic := '0';
	signal miso_tmp, miso_sync : std_logic := '0';
	signal cs_tmp, cs_sync : std_logic := '0';
	signal sck_tmp, sck_sync : std_logic := '0';
begin

	write_enable <= cs_sync xnor config(2);
	fifo_write <= (sck_sync xnor config(0)) xnor config(1);

	-- MOSI fifo instance
	fifo_mosi_inst : fifo_mxsx
	generic map(fifo_size => fifo_mosi_size)
	port map(
		clk => gls_clk,
		reset => gls_reset,
		write => fifo_write,
		read_data => fifo_mosi_read,
		data_in => mosi_sync,
		write_enable => write_enable,
		is_empty => fifo_mosi_empty,
		is_full => fifo_mosi_full,
		data_out => fifo_mosi_out);

	-- MISO fifo instance
	fifo_miso_inst : fifo_mxsx
	generic map(fifo_size => fifo_miso_size)
	port map(
		clk => gls_clk,
		reset => gls_reset,
		write => fifo_write,
		read_data => fifo_miso_read,
		data_in => miso_sync,
		write_enable => write_enable,
		is_empty => fifo_miso_empty,
		is_full => fifo_miso_full,
		data_out => fifo_miso_out);

	-- Packet fifo instance
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
		pf_full => fifo_packet_full,
		pf_empty => fifo_packet_empty,
		pf_init => gls_reset,
		pf_count => packet_count); -- TODO

	-- Sampling the SPI signals to avoid metastability
	spi_sampling : process(gls_clk, gls_reset)
	begin
		if gls_reset = '1' then
			-- Inactive state of CS is '1' in SPI mode 0
			-- Others signals is '0'
			mosi_tmp <= '0';
			miso_tmp <= '0';
			sck_tmp <= '0';
			cs_tmp <= '1';
			mosi_sync <= '0';
			miso_sync <= '0';
			sck_sync <= '0';
			cs_sync <= '1';
		elsif rising_edge(gls_clk) then
			mosi_tmp <= mosi;
			mosi_sync <= mosi_tmp;
			miso_tmp <= miso;
			miso_sync <= miso_tmp;
			sck_tmp <= sck;
			sck_sync <= sck_tmp;
			cs_tmp <= cs;
			cs_sync <= cs_tmp;
		end if;
	end process;


	-- FIFO packet write management
	write_fifo_packet_management : process(gls_clk, gls_reset)
		variable write_enable_old : std_logic := '0';
	begin
		if gls_reset = '1' then
			fifo_packet_in <= (others => '0');
			write_enable_old := '0';
		elsif rising_edge(gls_clk) then

			if (write_enable_old = '1') and (write_enable = '0') then
				fifo_packet_write <= '1';
				fifo_packet_in <= std_logic_vector(to_unsigned(bit_count, 16));
			else
				fifo_packet_write <= '0';
			end if;

			write_enable_old := write_enable;
		end if;
	end process;

	-- Count number of received SPI packets
	-- Increment on fifo_write rising edge
	-- reset when a write to fifo_packet is performed
	bit_count_proc : process(gls_clk, gls_reset)
		variable fifo_write_old : std_logic := '0';
	begin
		if gls_reset = '1' then
			fifo_write_old := '0';
			bit_count <= 0;
		elsif rising_edge(gls_clk) then
			if fifo_packet_write = '1' then
				bit_count <= 0;
			elsif (fifo_write_old = '0') and (fifo_write = '1') then
				bit_count <= (bit_count + 1) mod 2**16;
			end if;

			fifo_write_old := fifo_write;

		end if;
	end process;

	-- Wishbone interface
	-- TODO: Make it easier to read
	wishbone : process(gls_clk, gls_reset)
	begin
		if gls_reset = '1' then
			config <= (others => '0');
			wbs_readdata <= (others => '0');
		elsif rising_edge(gls_clk) then
			if wbs_write = '1' and (wbs_strobe = '1' or wbs_cycle = '1')then
				case wbs_add is
					when "0000" => config <= wbs_writedata;
					when others => config <= config;
				end case;
				fifo_mosi_read <= '0';
				fifo_miso_read <= '0';
				fifo_packet_read <= '0';
			elsif wbs_write = '0' and (wbs_strobe = '1' or wbs_cycle = '1') then
				case wbs_add is
					when "0000" => 	wbs_readdata <= config;
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
					when "0100" => 	wbs_readdata <= status;
					when others => wbs_readdata <= (others => '0');
				end case;
			else
				fifo_mosi_read <= '0';
				fifo_miso_read <= '0';
				fifo_packet_read <= '0';
			end if;
		end if;
	end process;

	-- Config register mapping
	status(10 downto 0) <= packet_count;
	status(13) <= fifo_mosi_full or fifo_miso_full;
	status(14) <= fifo_packet_full;
	status(15) <= fifo_packet_empty;

end architecture spisnif_1;
