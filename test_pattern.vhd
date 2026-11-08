-- test_pattern.vhd  --  OWNER: Person A (Hardware & Video)
--
-- GOAL: a picture generator you can use to test the clock, VGA timing and the resistor-DAC
-- wiring WITHOUT needing the game or the renderer. This is your "milestone 1".
--
-- TODO(A): draw, using the beam position (px, py):
--   1. Eight vertical color bars across the screen (each 80 pixels wide), e.g. black, blue,
--      green, cyan, red, magenta, yellow, white. Remember the color is 6 bits:
--      rgb = R1 R0 G1 G0 B1 B0  (2 bits per channel, "11" = full brightness).
--   2. A 1-pixel white border around the visible area (px = 0, px = 639, py = 0, py = 479)
--      so you can see if any of the picture is cropped by the monitor.
--   3. Optional: a brightness ramp (all four levels of one color) to check that both
--      resistors in each color channel work.
--   Output black ("000000") whenever 'active' = '0' -- monitors expect black in blanking.
--
-- The output is REGISTERED (one clock late), which matches the one-clock delay the renderer
-- puts on hs/vs, so sync and color stay aligned when digger_top.vhd switches between them.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity test_pattern is
	port(
		clk    : in  std_logic;
		active : in  std_logic;
		px     : in  unsigned(9 downto 0);
		py     : in  unsigned(9 downto 0);
		rgb    : out std_logic_vector(5 downto 0)
	);
end test_pattern;

architecture arch of test_pattern is
begin
	process(clk)
	begin
		if rising_edge(clk) then
			-- TODO(A): replace this placeholder with the color bars + border.
			rgb <= "000000";
		end if;
	end process;
end arch;
