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
--       - Walk outward up to 2 cells in direction v.pdir. Stop at the first cell where
--         enemy_ok(v, cx, cy, false) is false (dirt, rock or border). Remember how far
--         it got (v.hlen) and whether a live enemy is in one of those cells (the target).
--       - If there is a target: count v.pcool up; every PUMP_FRAMES frames add 1 to
--         v.einfl(target). When it reaches 4 the enemy pops: v.ealive(target) := '0'.
--         Also set v.ecnt(target) := 0 while it is being pumped so it can't deflate or move.
--       - If not pumping, set v.hlen := 0 and v.pcool := 0.
--   M3  ENEMIES (for each i in 0 to 3 that is alive)
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
		variable nx, ny    : integer;
		variable cx, cy    : integer;
		variable target_idx: integer;
		variable has_target: boolean;
		variable r         : enemy_move_t;
		variable crushed   : boolean;
		variable enemies_alive : boolean;

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
						if k_up = '1' then
							v.pdir := 0;   -- 0 = up
						elsif k_down = '1' then
							v.pdir := 2;   -- 2 = down
						elsif k_left = '1' then
							v.pdir := 3;   -- 3 = left
						elsif k_right = '1' then
							v.pdir := 1;   -- 1 = right
						end if;

						if v.pcnt < MOVE_FRAMES - 1 then
							v.pcnt := v.pcnt + 1;
						elsif k_pump = '0' then
							nx := v.px + dir_dx(v.pdir);
							ny := v.py + dir_dy(v.pdir);
							if player_ok(v, nx, ny) then
								v.px := nx;
								v.py := ny;
								if in_bounds(nx, ny) then
									v.dirt(ny * COLS + nx) := '0';
								end if;
								v.pcnt := 0;
							end if;
						end if;

						-- TODO(C) M2: pump
						has_target := false;
						target_idx := -1;

						if k_pump = '1' then
							v.pcnt := 0; -- no movement
							
							for step_i in 1 to 2 loop
								cx := v.px + step_i * dir_dx(v.pdir);
								cy := v.py + step_i * dir_dy(v.pdir);
								
								if not enemy_ok(v, cx, cy, false) then
									v.hlen := step_i - 1;
									exit;
								else
									v.hlen := step_i;
									for i in 0 to v.ealive'high loop
										if v.ealive(i) = '1' and v.ex(i) = cx and v.ey(i) = cy then
											has_target := true;
											target_idx := i;
											exit;
										end if;
									end loop;
								end if;
							end loop;

							if has_target then
								v.ecnt(target_idx) := 0; -- freeze target enemy deflation/movement
								if v.pcool < PUMP_FRAMES - 1 then
									v.pcool := v.pcool + 1;
								else
									v.pcool := 0;
									if v.einfl(target_idx) < 4 then
										v.einfl(target_idx) := v.einfl(target_idx) + 1;
										if v.einfl(target_idx) >= 4 then
											v.ealive(target_idx) := '0'; -- pop enemy
										end if;
									end if;
								end if;
							else
								v.pcool := 0;
							end if;
						else
							v.hlen := 0;
							v.pcool := 0;
						end if;

						-- TODO(C) M3: enemies
						for i in 0 to v.ealive'high loop
							if v.ealive(i) = '1' then

								-- if not pumped, start deflating if needed
								if (k_pump = '0') or (has_target = false) or (i /= target_idx) then
									if v.einfl(i) > 0 then
										-- Deflating over time if inflated
										if v.ecnt(i) < DEFLATE_FRAMES - 1 then
											v.ecnt(i) := v.ecnt(i) + 1;
										else
											v.ecnt(i) := 0;
											v.einfl(i) := v.einfl(i) - 1;
										end if;
									else
										-- if deflated, move when rdy
										if v.ecnt(i) < ENEMY_FRAMES - 1 then
											v.ecnt(i) := v.ecnt(i) + 1;
										else
											v.ecnt(i) := 0;
											r := enemy_step(v, i);
											v.ex(i) := r.nx;
											v.ey(i) := r.ny;
											v.eghost(i) := r.ghost;
										end if;
									end if;
								end if;
							end if;
						end loop;

						-- TODO(C) M4: rocks
						crushed := false;
						for j in 0 to 1 loop
							case v.rstate(j) is
								when 0 => -- still
									if enemy_ok(v, v.rx(j), v.ry(j) + 1, false) then
										v.rstate(j) := 1;
										v.rtimer(j) := 0;
									end if;

								when 1 => -- wobbling
									if v.rtimer(j) < WOBBLE_FRAMES - 1 then
										v.rtimer(j) := v.rtimer(j) + 1;
									else
										v.rstate(j) := 2;
										v.rtimer(j) := 0;
									end if;

								when 2 => -- falling
									if v.rtimer(j) < FALL_FRAMES - 1 then
										v.rtimer(j) := v.rtimer(j) + 1;
									else
										v.rtimer(j) := 0;
										if enemy_ok(v, v.rx(j), v.ry(j) + 1, false) then
											v.ry(j) := v.ry(j) + 1;
											-- if rock crushes player
											if v.rx(j) = v.px and v.ry(j) = v.py then
												crushed := true;
											end if;
											-- if rock crushes enemy
											for i in 0 to v.ealive'high loop
												if v.ealive(i) = '1' and v.rx(j) = v.ex(i) and v.ry(j) = v.ey(i) then
													v.ealive(i) := '0';
												end if;
											end loop;
										else
											v.rstate(j) := 0;
										end if;
									end if;

								when others =>
									v.rstate(j) := 0;
							end case;
						end loop;

						-- TODO(C) M5: death / win check
						for i in 0 to v.ealive'high loop
							if v.ealive(i) = '1' and v.ex(i) = v.px and v.ey(i) = v.py and v.einfl(i) = 0 then
								crushed := true;
							end if;
						end loop;

						if crushed then
							v.gstate := 1;
							v.gtimer := DEAD_FRAMES;
							v.hlen := 0;
							v.lives := v.lives - 1;
						else
							-- win condition (no enemies alive)
							enemies_alive := false;
							for i in 0 to v.ealive'high loop
								if v.ealive(i) = '1' then
									enemies_alive := true;
								end if;
							end loop;
							if not enemies_alive then
								v.gstate := 3; -- win
							end if;
						end if;

					
					when 1 => 
						-- TODO(C): death pause, then respawn or game over

						-- short pause after dying
						if v.gtimer > 0 then
							v.gtimer := v.gtimer - 1;
						else
							-- if no lives, game over
							if v.lives = 0 then
								v.gstate := 2;
							else
								-- if lives, respawn player & reset alive enemies
								v.px := PLAYER_X0;
								v.py := PLAYER_Y0;
								v.pdir := 1;
								v.pcnt := 0;
								v.pcool := 0;
								v.hlen := 0;

								for i in 0 to v.ealive'high loop
									if v.ealive(i) = '1' then
										v.ex(i) := EX0(i);
										v.ey(i) := EY0(i);
										v.einfl(i) := 0;
										v.eghost(i) := 0;
										v.ecnt(i) := 0;
									end if;
								end loop;

								v.gstate := 0;
							end if;
						end if;

					when others =>
						-- TODO(C): game over / win: restart when k_start = '1'
						if k_start = '1' then
							lf := v.lfsr;
							v := INIT;
							v.lfsr := lf;
						end if;

				end case;

				s <= v;
			end if;
		end if;
	end process;
end arch;
