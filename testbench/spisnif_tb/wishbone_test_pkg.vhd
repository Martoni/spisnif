library ieee;
use ieee.std_logic_1164.all;

package wishbone_test_pkg is

    CONSTANT CS_MIN : time := 13.6 ns;
    CONSTANT CLOCK_PERIOD : time := 7.5188 ns;
    CONSTANT WE3 : time := 2.25 ns;
    CONSTANT WE4 : time := 2.25 ns;
    CONSTANT ZERO : std_logic_vector := x"0000000000000000";

    -- write procedures
    procedure wishbone_write(
        address     : in std_logic_vector;
        value       : in std_logic_vector (15 downto 0);
        signal gls_clk       : in std_logic;
        signal wbs_strobe    : out std_logic;
        signal wbs_cycle     : out std_logic;
        signal wbs_write     : out std_logic;
        signal wbs_ack       : in std_logic;
        signal wbs_add       : out std_logic_vector;
        signal wbs_writedata : out std_logic_vector (15 downto 0);
        signal wbs_readdata  : in std_logic_vector (15 downto 0);
        WSC         : natural);
    -- read procedures
    procedure wishbone_read(
        address       : in std_logic_vector;
        signal value  : out std_logic_vector (15 downto 0);
        signal gls_clk    : in std_logic;
        signal wbs_strobe : out std_logic;
        signal wbs_cycle  : out std_logic;
        signal wbs_write  : out std_logic;
        signal wbs_ack    : in std_logic;
        signal wbs_add    : out std_logic_vector;
        signal wbs_writedata : out std_logic_vector (15 downto 0);
        signal wbs_readdata  : in std_logic_vector (15 downto 0);
        WSC         : natural);
end package wishbone_test_pkg;

package body wishbone_test_pkg is

    -- Write value from imx
procedure wishbone_write(
        address     : in std_logic_vector;
        value       : in std_logic_vector (15 downto 0);
        signal gls_clk       : in std_logic;
        signal wbs_strobe    : out std_logic;
        signal wbs_cycle     : out std_logic;
        signal wbs_write     : out std_logic;
        signal wbs_ack       : in std_logic;
        signal wbs_add       : out std_logic_vector;
        signal wbs_writedata : out std_logic_vector (15 downto 0);
        signal wbs_readdata  : in std_logic_vector (15 downto 0);
        WSC         : natural
) is
begin

    assert (address'high >= wbs_add'high)
        report "ERROR(wishbone_write): address std_logic_vector size must be >= wbs_add"
            severity error;
    assert (address'low = 0) and (wbs_add'low = 0)
        report "ERROR(wishbone_write): std_logic_vectors must begin at 0"
            severity error;

    -- Write value
    wait until falling_edge(gls_clk);
    wait for 4 ns;
    --wbs_add <= address(wbs_add'range);
    for i in wbs_add'range loop
        wbs_add(i) <= address(i);
    end loop;
    wbs_strobe <= '1';
    wbs_write <= '1';
    wbs_cycle <= '1';
    wait until falling_edge(gls_clk);
    wait for 2500 ps;
    wbs_writedata  <= value;
    if WSC <= 1 then
        wait until falling_edge(gls_clk);
    else
        for n in 1 to WSC loop
            wait until falling_edge(gls_clk); -- WSC = 2
        end loop;
    end if;
    wait for 1 ns;
    wbs_strobe <= '0';
    wbs_write <= '0';
    wbs_cycle <= '0';
    for i in wbs_add'range loop
        wbs_add(i) <= '0';
    end loop;
    wbs_writedata  <= (others => '0');
end procedure wishbone_write;

-- Read a value from imx
procedure wishbone_read(
        address     : in std_logic_vector;
        signal value      : out std_logic_vector (15 downto 0);
        signal gls_clk    : in std_logic;
        signal wbs_strobe : out std_logic;
        signal wbs_cycle  : out std_logic;
        signal wbs_write  : out std_logic;
        signal wbs_ack    : in std_logic;
        signal wbs_add       : out std_logic_vector;
        signal wbs_writedata : out std_logic_vector (15 downto 0);
        signal wbs_readdata  : in std_logic_vector (15 downto 0);
        WSC         : natural) is
begin
    assert (address'high >= wbs_add'high)
        report "ERROR(wishbone_read): address std_logic_vector size must be >= wbs_add"
            severity error;
    assert (address'low = 0) and (wbs_add'low = 0)
        report "ERROR(wishbone_read): std_logic_vectors must begin at 0"
            severity error;

    -- Read value
    wait until falling_edge(gls_clk);
    wait for WE3;
    for i in wbs_add'range loop
        wbs_add(i) <= address(i);
    end loop;
    wbs_strobe <= '1';
    wbs_write <= '0';
    wbs_cycle <= '1';
    wait for CS_MIN; -- minimum chip select time
    if WSC > 1 then
        for n in 2 to WSC loop
            wait until falling_edge(gls_clk);
        end loop;
        --wait for CLOCK_PERIOD*(WSC-1);
    end if;
    wait for WE4;
    value <= wbs_readdata;
    wbs_strobe <= '0';
    wbs_write <= '0';
    wbs_cycle <= '0';
    for i in wbs_add'range loop
        wbs_add(i) <= '0';
    end loop;
    wait for 1 ns;
end procedure wishbone_read;

end package body wishbone_test_pkg;
