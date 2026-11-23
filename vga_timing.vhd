-- vga_timing.vhd  --  OWNER: Person A (Hardware & Video)
--
-- GOAL: generate the signals a VGA monitor needs, plus a once-per-frame pulse for the game.
--
-- 640x480 @ ~60 Hz timing from a 25 MHz pixel clock (one pixel per clock):
--                 visible   front porch   sync pulse   back porch   TOTAL
--   horizontal      640          16            96           48        800  (counts)
--   vertical        480          10             2           33        525  (lines)
--   Both sync pulses are ACTIVE LOW (the line is '1' normally and '0' during the pulse).
--   With counter h = 0..799 and v = 0..524 the sync windows are:
--       hs low for h in [656, 752)        vs low for v in [490, 492)
--
-- TODO(A):
--   1. Count: h goes 0..799 and wraps; each time h wraps, v goes 0..524 and wraps.
--      One clocked process with two integer signals is enough.
--   2. hs, vs : low during their sync windows, high otherwise.
--   3. active : '1' only while h < 640 AND v < 480 (the visible area).
--   4. tick   : '1' for exactly ONE clock cycle at the start of vertical blanking
--               (h = 0 and v = 480). The game logic updates once per tick (~60 Hz).
--   5. px, py : the current counters converted to unsigned(9 downto 0)  (to_unsigned).
--   6. DELETE the placeholder assignments at the bottom.
--
-- How to test (no game needed): in digger_top.vhd set USE_TEST_PATTERN := true and look at
-- the monitor. Also try an LED that toggles on every 'tick': it should blink at ~30 Hz.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity vga_timing is
	port(
		clk    : in  std_logic;
		hs     : out std_logic;              -- horizontal sync (active low)
		vs     : out std_logic;              -- vertical sync (active low)
		active : out std_logic;              -- '1' inside the visible 640x480 area
		tick   : out std_logic;              -- one-clock pulse at the start of vertical blanking
		px     : out unsigned(9 downto 0);   -- current pixel x (0..799)
		py     : out unsigned(9 downto 0)    -- current pixel y (0..524)
	);
end vga_timing;

architecture arch of vga_timing is
	signal h : unsigned(9 downto 0) := (others => '0');
	signal v : unsigned(9 downto 0) := (others => '0');
begin
	process(clk)
	begin
		if rising_edge(clk) then
			if h = to_unsigned(799, 10) then
				h <= (others => '0');
				if v = to_unsigned(524, 10) then
					v <= (others => '0');
				else
					v <= v + 1;
				end if;
			else
				h <= h + 1;
			end if;
		end if;
	end process;

	hs <= '0' when (h >= to_unsigned(656, 10) and h < to_unsigned(752, 10)) else '1';
	vs <= '0' when (v >= to_unsigned(490, 10) and v < to_unsigned(492, 10)) else '1';
	active <= '1' when (h < to_unsigned(640, 10) and v < to_unsigned(480, 10)) else '0';
	tick <= '1' when (h = to_unsigned(0, 10) and v = to_unsigned(480, 10)) else '0';
	px <= h;
	py <= v;
end arch;