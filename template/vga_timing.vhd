-- vga_timing.vhd
-- 640x480 @ ~60 Hz timing from a 25 MHz pixel clock.
--   horizontal: 640 visible + 16 front porch + 96 sync + 48 back porch = 800
--   vertical:   480 visible + 10 front porch +  2 sync + 33 back porch = 525
-- Both sync pulses are active low.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity vga_timing is
	port(
		clk    : in  std_logic;
		hs     : out std_logic;
		vs     : out std_logic;
		active : out std_logic;              -- '1' inside the visible 640x480 area
		tick   : out std_logic;              -- one-clock pulse at the start of vertical blanking (60 Hz)
		px     : out unsigned(9 downto 0);   -- current pixel x (0..799)
		py     : out unsigned(9 downto 0)    -- current pixel y (0..524)
	);
end vga_timing;

architecture arch of vga_timing is
	signal h : integer range 0 to 799 := 0;
	signal v : integer range 0 to 524 := 0;
begin
	process(clk)
	begin
		if rising_edge(clk) then
			if h = 799 then
				h <= 0;
				if v = 524 then
					v <= 0;
				else
					v <= v + 1;
				end if;
			else
				h <= h + 1;
			end if;
		end if;
	end process;

	hs     <= '0' when (h >= 656 and h < 752) else '1';
	vs     <= '0' when (v >= 490 and v < 492) else '1';
	active <= '1' when (h < 640 and v < 480) else '0';
	tick   <= '1' when (h = 0 and v = 480) else '0';
	px     <= to_unsigned(h, 10);
	py     <= to_unsigned(v, 10);
end arch;
