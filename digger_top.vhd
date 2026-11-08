-- digger_top.vhd  --  OWNER: Person A (Hardware & Video), the INTEGRATION point
--
-- This file is already fully wired. It connects everybody's modules:
--
--   sysclk (12 MHz) -> clk_gen -> pix_clk (25 MHz)         [A]
--   vga_timing  -> px, py, hs, vs, active, tick            [A]
--   input_sync  -> debounced buttons                       [A]
--   game        -> state (game_state_t)                    [C]  (uses level_pkg [B], ai_pkg [A])
--   renderer    -> color for each pixel                    [B]  (uses sprite_pkg [B])
--
-- TWO TEST SWITCHES (change, rebuild, look at the monitor):
--   USE_TEST_PATTERN : true  -> show test_pattern.vhd's color bars instead of the game.
--                              Use this FIRST to check clock, timing and VGA wiring (A).
--   USE_DEMO_STATE   : true  -> the renderer draws demo_pkg's frozen fake state instead of
--                              the real game state. Use this to test artwork (B).
--   Both false = the real game.
--
-- TODO(A):
--   1. Once your own modules work, use USE_TEST_PATTERN to bring up the monitor.
--   2. Add a debugging aid: e.g. drive led(1) from a bit that toggles on every 'tick'
--      (then it blinks at 30 Hz) if you need to check the frame tick.
--   3. When B and C have files ready, pull everything together and make sure the whole
--      project builds. You are the person who runs the final integration.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.digger_pkg.all;
use work.demo_pkg.all;

entity digger_top is
	port(
		sysclk    : in  std_logic;
		btn       : in  std_logic_vector(1 downto 0);   -- onboard: btn(0) = reset, btn(1) = start/restart
		led       : out std_logic_vector(1 downto 0);
		vga_r     : out std_logic_vector(1 downto 0);
		vga_g     : out std_logic_vector(1 downto 0);
		vga_b     : out std_logic_vector(1 downto 0);
		vga_hs    : out std_logic;
		vga_vs    : out std_logic;
		key_up    : in  std_logic;                      -- external buttons to GND (active low)
		key_down  : in  std_logic;
		key_left  : in  std_logic;
		key_right : in  std_logic;
		key_pump  : in  std_logic
	);
end digger_top;

architecture arch of digger_top is
	constant USE_TEST_PATTERN : boolean := false;
	constant USE_DEMO_STATE   : boolean := false;
	constant DEMO : game_state_t := make_demo;

	signal pix_clk, locked          : std_logic;
	signal lock_m, lock_s           : std_logic := '0';
	signal hs, vs, active, tick     : std_logic;
	signal hs_o, vs_o               : std_logic;
	signal px, py                   : unsigned(9 downto 0);
	signal rgb, tp_rgb, rgb_sel     : std_logic_vector(5 downto 0);
	signal d_up, d_down, d_left     : std_logic;
	signal d_right, d_pump          : std_logic;
	signal d_start, d_rst           : std_logic;
	signal rst                      : std_logic;
	signal gs, gs_sel               : game_state_t;
begin
	clkgen: entity work.clk_gen
		port map(clk_in => sysclk, clk_out => pix_clk, locked => locked);

	-- bring the MMCM lock signal into the pixel clock domain; hold reset until locked
	process(pix_clk)
	begin
		if rising_edge(pix_clk) then
			lock_m <= locked;
			lock_s <= lock_m;
		end if;
	end process;
	rst <= d_rst or (not lock_s);

	timing: entity work.vga_timing
		port map(clk => pix_clk, hs => hs, vs => vs, active => active,
		         tick => tick, px => px, py => py);

	s_up:    entity work.input_sync generic map(ACTIVE_LOW => true)
		port map(clk => pix_clk, din => key_up,    dout => d_up);
	s_down:  entity work.input_sync generic map(ACTIVE_LOW => true)
		port map(clk => pix_clk, din => key_down,  dout => d_down);
	s_left:  entity work.input_sync generic map(ACTIVE_LOW => true)
		port map(clk => pix_clk, din => key_left,  dout => d_left);
	s_right: entity work.input_sync generic map(ACTIVE_LOW => true)
		port map(clk => pix_clk, din => key_right, dout => d_right);
	s_pump:  entity work.input_sync generic map(ACTIVE_LOW => true)
		port map(clk => pix_clk, din => key_pump,  dout => d_pump);
	s_start: entity work.input_sync generic map(ACTIVE_LOW => false)
		port map(clk => pix_clk, din => btn(1),    dout => d_start);
	s_rst:   entity work.input_sync generic map(ACTIVE_LOW => false)
		port map(clk => pix_clk, din => btn(0),    dout => d_rst);

	logic: entity work.game
		port map(clk => pix_clk, rst => rst, tick => tick,
		         k_up => d_up, k_down => d_down, k_left => d_left,
		         k_right => d_right, k_pump => d_pump, k_start => d_start,
		         gs => gs);

	gs_sel <= DEMO when USE_DEMO_STATE else gs;

	draw: entity work.renderer
		port map(clk => pix_clk, hs => hs, vs => vs, active => active,
		         px => px, py => py, gs => gs_sel,
		         rgb => rgb, hs_o => hs_o, vs_o => vs_o);

	pattern: entity work.test_pattern
		port map(clk => pix_clk, active => active, px => px, py => py, rgb => tp_rgb);

	rgb_sel <= tp_rgb when USE_TEST_PATTERN else rgb;

	vga_r  <= rgb_sel(5 downto 4);
	vga_g  <= rgb_sel(3 downto 2);
	vga_b  <= rgb_sel(1 downto 0);
	vga_hs <= hs_o;
	vga_vs <= vs_o;

	led(0) <= lock_s;                                   -- on = clock locked
	led(1) <= '1' when gs.gstate = 0 else '0';          -- on while playing
end arch;
