-- tb_game.vhd  --  OWNER: Person C (Game Logic)
--
-- GOAL: a simulation testbench for game.vhd, so you can test the rules in seconds without
-- building a bitstream. A testbench is a VHDL file with NO ports that creates a fake clock,
-- fake frame ticks and fake button presses, feeds them to your module, and checks the
-- results with 'assert'.
--
-- In Vivado: add this file under "Simulation Sources" (not Design Sources), set it as the
-- simulation top, and Run Behavioral Simulation. Watch the signals in the waveform window
-- and read assertion failures in the Tcl console.
--
-- HOW TIME WORKS HERE: the real design gets one 'tick' per 416,666 clocks (one video frame).
-- To keep simulation fast this testbench makes one tick every 20 clocks instead. The game
-- doesn't care how long a frame is; it only counts ticks.
--
-- TODO(C): after each game.vhd milestone, add a test below (copy the example):
--   M1  hold right for N frames -> px increased; walk into dirt -> that dirt bit is '0';
--       walking into the border / a rock does nothing.
--   M2  put an enemy 2 cells in front of the player (you can't edit the state from here, so
--       choose the level layout / start positions accordingly, or drive the player there
--       with the buttons), hold pump -> einfl rises every PUMP_FRAMES; after 4 -> ealive = '0'.
--   M3  let time pass with no buttons -> enemies move (once Person A's AI exists).
--   M4  dig under a rock, wait -> rstate goes 0 -> 1 -> 2 and ry increases.
--   M5  walk into an enemy -> gstate = 1 and lives decreases by 1; lose all lives -> gstate = 2.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.digger_pkg.all;

entity tb_game is
end tb_game;

architecture sim of tb_game is
	signal clk     : std_logic := '0';
	signal rst     : std_logic := '1';
	signal tick    : std_logic := '0';
	signal k_up    : std_logic := '0';
	signal k_down  : std_logic := '0';
	signal k_left  : std_logic := '0';
	signal k_right : std_logic := '0';
	signal k_pump  : std_logic := '0';
	signal k_start : std_logic := '0';
	signal gs      : game_state_t;

	-- wait until n more ticks (frames) have happened
	procedure wait_frames(n : in integer) is
	begin
		for i in 1 to n loop
			wait until rising_edge(clk) and tick = '1';
		end loop;
	end procedure;
begin
	-- 25 MHz clock (40 ns period)
	clk <= not clk after 20 ns;

	-- one tick pulse every 20 clocks
	process
	begin
		tick <= '0';
		for i in 1 to 19 loop
			wait until rising_edge(clk);
		end loop;
		tick <= '1';
		wait until rising_edge(clk);
	end process;

	dut: entity work.game
		port map(clk => clk, rst => rst, tick => tick,
		         k_up => k_up, k_down => k_down, k_left => k_left,
		         k_right => k_right, k_pump => k_pump, k_start => k_start,
		         gs => gs);

	stimulus: process
		variable x_before : integer;
	begin
		-- reset for a few clocks
		rst <= '1';
		wait for 200 ns;
		rst <= '0';
		wait_frames(2);

		-- ---------- EXAMPLE TEST (M1): hold RIGHT, the player should move right ----------
		x_before := gs.px;
		k_right <= '1';
		wait_frames(30);
		k_right <= '0';
		assert gs.px > x_before
			report "M1 FAILED: player did not move right" severity error;

		-- TODO(C): more tests here, one block per milestone.

		report "Testbench finished" severity note;
		wait;   -- stop
	end process;
end sim;
