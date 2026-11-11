-- ai_pkg.vhd  --  OWNER: Person A (Hardware & Video; this is your second job once video works)
--
-- GOAL: decide where ONE enemy moves next. This is a PURE FUNCTION: it reads the game state
-- and returns the enemy's new cell. It never changes the state itself; Person C's game.vhd
-- calls it and applies the result:
--
--      r := enemy_step(v, i);   v.ex(i) := r.nx;  v.ey(i) := r.ny;  v.eghost(i) := r.ghost;
--
-- game.vhd only calls this when enemy i is alive, not inflated, and its move timer expired
-- (about once every 16 frames), so you don't need to worry about timing here.
--
-- BEHAVIOR TO IMPLEMENT (greedy chase with a ghost mode):
--   1. Ghost mode is ON if st.eghost(i) > 0  OR  the enemy is standing in a dirt cell
--      (st.dirt(y*COLS + x) = '1'). Ghosts may move through dirt; normal enemies may not.
--   2. Look at the 4 neighbours (use dir_dx(d), dir_dy(d) for d = 0..3). A neighbour is
--      allowed if enemy_ok(st, nx, ny, ghost_mode). For each allowed neighbour compute the
--      Manhattan distance to the player: abs(nx - st.px) + abs(ny - st.py). Remember the
--      direction with the SMALLEST distance (best_d, best_dist).
--   3. Random wander: using st.lfsr, about 1 move in 8 pick a random direction instead
--      (e.g. if st.lfsr(2 downto 0) = "000", direction := to_integer(unsigned(st.lfsr(4 downto 3)))
--      and use it if that neighbour is allowed). This stops enemies being perfectly predictable.
--   4. Move if there is an allowed neighbour AND (ghost_mode OR the best distance is smaller
--      than the current distance). Otherwise the enemy is stuck in a dead end:
--      stay put and start ghost mode (ghost := 24).
--   5. When a ghost moves, decrement its ghost timer (if it is above 0).
--   6. Random ghost trigger: if st.lfsr(11 downto 6) = "000000" then ghost := 16
--      (about 1 move in 64 turns an enemy into a ghost for a while).
--
-- HOW TO TEST: this is plain combinational code, so a tiny testbench is easy: build a
-- game_state_t (e.g. from level_pkg.make_init), put the player and one enemy somewhere,
-- call enemy_step and check r.nx / r.ny. Or integrate it with game.vhd and watch the
-- enemies on screen once the video works.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.digger_pkg.all;

package ai_pkg is
	type enemy_move_t is record
		nx    : integer range 0 to 19;   -- new x cell
		ny    : integer range 0 to 14;   -- new y cell
		ghost : integer range 0 to 63;   -- new value for st.eghost(i)
	end record;

	-- i = enemy index (0..2)
	function enemy_step(st : game_state_t; i : integer) return enemy_move_t;
end package;

package body ai_pkg is

	function enemy_step(st : game_state_t; i : integer) return enemy_move_t is
		variable r : enemy_move_t;
		-- TODO(A): declare the variables you need (ghost-mode flag, best direction,
		--          best distance, current distance, random direction, ...).
	begin
		-- PLACEHOLDER: the enemy stays where it is. Replace with the algorithm above.
		r.nx    := st.ex(i);
		r.ny    := st.ey(i);
		r.ghost := st.eghost(i);

		-- TODO(A): implement steps 1-6 here.

		return r;
	end function;

end package body;
