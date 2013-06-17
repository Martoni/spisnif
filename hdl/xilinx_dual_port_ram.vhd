-- Listing 11.3
-- Dual-port RAM with synchronous read
-- Modified from XST 8.1i rams_09
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity xilinx_dual_port_ram is
    generic (
        ram_size : natural := 1024);
    port(
      clk   : in  std_logic;
      we    : in  std_logic;
      addr_a: in  std_logic_vector(9 downto 0);
      addr_b: in  std_logic_vector(9 downto 0);
      din_b : in  std_logic_vector(15 downto 0);
      dout_a: out std_logic_vector(15 downto 0)
    );
end xilinx_dual_port_ram;

architecture beh_arch of xilinx_dual_port_ram is
   type ram_type is array (0 to ram_size-1) of std_logic_vector (15 downto 0);
   signal ram: ram_type := (others => (others => '0'));
begin

        process(clk)
        begin
          if rising_edge(clk) then
             if (we = '1') then
                ram(to_integer(unsigned(addr_b)) mod ram_size) <= din_b;
             end if;
             dout_a <= ram(to_integer(unsigned(addr_a)) mod ram_size);
          end if;
        end process;

end beh_arch;

