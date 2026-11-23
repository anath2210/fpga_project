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
	type edec_t is record
		go      : boolean;
		dir     : integer range 0 to 3;
		ghost   : boolean;
		breathe : boolean;
	end record;
	function enemy_decide(st : game_state_t; i : integer; r : std_logic_vector(7 downto 0)) return edec_t;
end package;

package body ai_pkg is

	--  distance between two cells' corners
	function dist(ax, ay, bx, by : integer) return integer is
		variable dx, dy : integer range 0 to 511;
	begin
		if ax >= bx then dx := ax - bx; else dx := bx - ax; end if;
		if ay >= by then dy := ay - by; else dy := by - ay; end if;
		return dx + dy;
	end function;

	function enemy_decide(st : game_state_t; i : integer; r : std_logic_vector(7 downto 0)) return edec_t is
		variable d         : edec_t;
		variable c, rw     : integer range 0 to 17;
		variable tx, ty    : integer range 0 to 288;
		variable ghost     : boolean;
		variable best      : integer range 0 to 1023;
		variable score     : integer range 0 to 1023;
		variable nc, nr    : integer;
		variable found     : boolean;
		variable rev       : integer range 0 to 3;
		variable pd        : integer range 0 to 3;
		variable n         : integer range 0 to 4;
		variable gok       : boolean;
		variable last_enem : boolean;
	begin
		d.go := true;  d.dir := st.edir(i);  d.ghost := false;  d.breathe := false;
		c  := st.ex(i) / TILE;
		rw := st.ey(i) / TILE;
		rev := opposite(st.edir(i));
		ghost := st.eghost(i) > 0;
		gok := st.eage(i) >= ghost_delay(st.rnd);
		last_enem := (alive_count(st) = 1);

		-- target the player or the top-left corner when this is the last enemy
		if last_enem then
			tx := 0;  ty := ROW_SURF * TILE;
			d.ghost := true;  ghost := true;
		else
			tx := st.px;  ty := st.py;
		end if;

		-- fire-breather breathe when the player is lined up in front horizontally and close
		if st.ekind(i) = 1 and not ghost and not last_enem and r(1 downto 0) = "00" then
			if (st.edir(i) = 1 and st.py = st.ey(i) and st.px > st.ex(i) and st.px - st.ex(i) <= 3 * TILE) or
			   (st.edir(i) = 3 and st.py = st.ey(i) and st.px < st.ex(i) and st.ex(i) - st.px <= 3 * TILE) then
				d.breathe := true;
				d.go := false;
				return d;
			end if;
		end if;

		-- ghost mode head straight for the target through anything but rocks
		if ghost then
			best := 1023;  found := false;
			for k in 0 to 3 loop
				nc := c  + dir_dx(k);
				nr := rw + dir_dy(k);
				if enemy_cell_ok(st, nc, nr, true) then
					score := dist(nc * TILE, nr * TILE, tx, ty);
					if k = rev and score < 1015 then score := score + 8; end if; -- small bias against turning back
					if score < best then best := score; d.dir := k; found := true; end if;
				end if;
			end loop;
			d.go := found;
			return d;
		end if;

		-- normal mode move through tunnels and prefer the way that gets closer
		best := 1023;  found := false;  n := 0;
		for k in 0 to 3 loop
			nc := c  + dir_dx(k);
			nr := rw + dir_dy(k);
			if k /= rev and enemy_cell_ok(st, nc, nr, false) then
				n := n + 1;
				score := dist(nc * TILE, nr * TILE, tx, ty);
				if k = st.edir(i) and score >= 4 then score := score - 4; end if; -- tiny bias to keep going straight
				if score < best then best := score; d.dir := k; found := true; end if;
			end if;
		end loop;

		-- sometimes pick another open way so enemies are not perfectly predictable
		if n >= 2 and r(4 downto 2) = "000" then
			pd := to_integer(unsigned(r(7 downto 6)));
			for k in 0 to 3 loop
				nc := c  + dir_dx((pd + k) mod 4);
				nr := rw + dir_dy((pd + k) mod 4);
				if (pd + k) mod 4 /= rev and enemy_cell_ok(st, nc, nr, false) then
					d.dir := (pd + k) mod 4;
					exit;
				end if;
			end loop;
		end if;

		if not found then
			-- dead end turn back if possible or become ghost
			if enemy_cell_ok(st, c + dir_dx(rev), rw + dir_dy(rev), false) and (r(3 downto 2) /= "00" or not gok) then
				d.dir := rev;
			else
				d.ghost := true;
				best := 1023;  found := false;
				for k in 0 to 3 loop
					nc := c  + dir_dx(k);
					nr := rw + dir_dy(k);
					if enemy_cell_ok(st, nc, nr, true) then
						score := dist(nc * TILE, nr * TILE, tx, ty);
						if score < best then best := score; d.dir := k; found := true; end if;
					end if;
				end loop;
				d.go := found;
			end if;
		elsif gok and n = 1 and r(7 downto 5) = "000" then
			d.ghost := true;
		end if;
		return d;
	end function;

end package body;