-- game.vhd  --  OWNER: Person C (Game Logic)
--
-- GOAL: all the rules of the game. This module owns the game state (signal s) and updates
-- it ONCE PER VIDEO FRAME (when 'tick' = '1', about 60 times a second). Person B's renderer
-- reads the state through the 'gs' output; it never changes it.
--
-- THE PATTERN (already written for you below, understand it first):
--     v := s;              -- copy the current state into a variable
--     ... change v ...     -- ordinary sequential code, like software
--     s <= v;              -- write the new state back, once, at the end
-- Because this runs only on 'tick', one frame = one step of your game. All speeds below are
-- measured in frames (1 frame = 1/60 s).
--
-- THE RULES to implement (in this order; test each before moving on):
--
-- gstate = 0  (PLAYING)
--   M1  PLAYER MOVEMENT + DIGGING
--       - Read k_up / k_down / k_left / k_right (priority in that order if several pressed).
--       - Set v.pdir to the pressed direction (even if he can't move that way).
--       - Count v.pcnt up to MOVE_FRAMES; only when it is reached may he step one cell.
--       - Step with dir_dx / dir_dy if player_ok(v, nx, ny). Moving INTO a cell digs it:
--         v.dirt(ny*COLS + nx) := '0'. Reset v.pcnt to 0 after a step.
--   M2  PUMP (when k_pump = '1'; the player can't move while pumping)
--       - Walk outward up to 3 cells in direction v.pdir. Stop at the first cell where
--         enemy_ok(v, cx, cy, false) is false (dirt, rock or border). Remember how far
--         it got (v.hlen) and whether a live enemy is in one of those cells (the target).
--       - If there is a target: count v.pcool up; every PUMP_FRAMES frames add 1 to
--         v.einfl(target). When it reaches 4 the enemy pops: v.ealive(target) := '0'.
--         Also set v.ecnt(target) := 0 while it is being pumped so it can't deflate or move.
--       - If not pumping, set v.hlen := 0 and v.pcool := 0.
--   M3  ENEMIES (for each i in 0 to 2 that is alive)
--       - If inflated (v.einfl(i) > 0) it is frozen and, unless it is the one being pumped,
--         deflates by 1 every DEFLATE_FRAMES frames (use v.ecnt(i) as the timer).
--       - Otherwise count v.ecnt(i) up; when it reaches ENEMY_FRAMES reset it and move:
--             r := enemy_step(v, i);
--             v.ex(i) := r.nx;  v.ey(i) := r.ny;  v.eghost(i) := r.ghost;
--         (enemy_step comes from Person A's ai_pkg. Until it exists it just returns the
--          current position, so enemies stand still: fine for testing everything else.)
--   M4  ROCKS (for each j in 0 to 1), a little state machine in v.rstate(j):
--       0 still    : if the cell below is open (enemy_ok(v, rx, ry+1, false)) -> state 1, timer 0
--       1 wobbling : count v.rtimer(j); after WOBBLE_FRAMES -> state 2, timer 0
--       2 falling  : count v.rtimer(j); every FALL_FRAMES frames try to move down one cell:
--                      if the cell below is open -> v.ry(j) := ry + 1, and
--                         * if the player is in that cell he is crushed (remember this)
--                         * any live enemy in that cell dies (v.ealive(i) := '0')
--                      else the rock has landed -> state 0
--   M5  DEATH / WIN (end of the PLAYING branch)
--       - Dead if a live enemy is in the player's cell, or a rock crushed him.
--         Then: v.gstate := 1; v.gtimer := DEAD_FRAMES; v.hlen := 0; v.lives := v.lives - 1.
--       - Otherwise, if no enemy is alive: v.gstate := 3 (win).
--
-- gstate = 1  (JUST DIED, short pause)
--   - Count v.gtimer down to 0. Then: if v.lives = 0 -> v.gstate := 2 (game over);
--     else respawn: player back to (PLAYER_X0, PLAYER_Y0), pdir 1, timers/hlen 0;
--     every enemy back to (EX0(i), EY0(i)) with einfl, eghost, ecnt = 0; v.gstate := 0.
--     (Rocks and dirt stay as they are.)
--
-- gstate = 2 or 3  (GAME OVER / WIN)
--   - When k_start = '1', restart: keep the random bits, v := INIT, v.lfsr := the saved bits.
--
-- Constants for the numbers are below. Tune them while playing (faster / slower).
-- Helper functions you can use (all in digger_pkg): in_bounds, has_rock, enemy_ok,
-- player_ok, dir_dx, dir_dy.
--
-- HOW TO TEST: tb_game.vhd is a ready-to-extend testbench; simulating the game logic in
-- Vivado's simulator is much faster than rebuilding the bitstream. Write a check for each
-- milestone there, then confirm on the real screen once the renderer works.
--
-- GOTCHAS:
--   * Integer signals/variables have a RANGE (see digger_pkg). Assigning a value outside
--     the range is an error in simulation. E.g. never set v.px to -1 or 20: check
--     player_ok / in_bounds BEFORE you assign.
--   * Only assign v.dirt(...) with an index you have checked is inside the playfield.
--   * Everything happens in ONE clock cycle per frame, so order matters: e.g. decide the
--     pump target BEFORE the enemies' deflate logic uses it.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.digger_pkg.all;
use work.level_pkg.all;
use work.ai_pkg.all;

entity game is
	port(
		clk     : in  std_logic;
		rst     : in  std_logic;
		tick    : in  std_logic;               -- one pulse per frame
		k_up    : in  std_logic;               -- debounced buttons, '1' = pressed
		k_down  : in  std_logic;
		k_left  : in  std_logic;
		k_right : in  std_logic;
		k_pump  : in  std_logic;
		k_start : in  std_logic;
		gs      : out game_state_t             -- the state, read by the renderer
	);
end game;

architecture arch of game is
	constant INIT : game_state_t := make_init;
	signal s : game_state_t := INIT;

	-- tuning (frames; 1 frame = 1/60 s)  --  TODO(C): adjust while playing
	constant MOVE_FRAMES    : integer := 7;    -- player: one cell per 7 frames
	constant PUMP_FRAMES    : integer := 10;   -- frames per inflation step
	constant DEFLATE_FRAMES : integer := 45;   -- frames per deflation step
	constant ENEMY_FRAMES   : integer := 16;   -- enemy: one cell per 16 frames
	constant WOBBLE_FRAMES  : integer := 30;   -- rock wobble before falling
	constant FALL_FRAMES    : integer := 5;    -- rock: one cell per 5 frames
	constant DEAD_FRAMES    : integer := 90;   -- pause after dying
begin
	gs <= s;

	process(clk)
		variable v  : game_state_t;
		variable lf : std_logic_vector(15 downto 0);
		-- TODO(C): declare the extra variables you need (wanted direction, new cell nx/ny,
		--          pump target and length, an enemy-move record "r : enemy_move_t",
		--          a 'crushed' flag, alive count, ...).
	begin
		if rising_edge(clk) then
			if rst = '1' then
				s <= INIT;
			elsif tick = '1' then
				v := s;

				-- 16-bit pseudo-random number generator (DONE): taps 16,14,13,11.
				-- Person A's enemy AI reads v.lfsr for random choices.
				v.lfsr := v.lfsr(14 downto 0) &
				          (v.lfsr(15) xor v.lfsr(13) xor v.lfsr(12) xor v.lfsr(10));

				case v.gstate is

					when 0 =>
						-- TODO(C) M1: player movement + digging
						-- TODO(C) M2: pump
						-- TODO(C) M3: enemies (calls enemy_step)
						-- TODO(C) M4: rocks
						-- TODO(C) M5: death / win check
						null;

					when 1 =>
						-- TODO(C): death pause, then respawn or game over
						null;

					when others =>
						-- TODO(C): game over / win: restart when k_start = '1'
						null;

				end case;

				s <= v;
			end if;
		end if;
	end process;
end arch;
