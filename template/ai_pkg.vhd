-- ai_pkg.vhd  --  enemy decisions (pure functions, no state of their own)
--
-- game.vhd calls enemy_decide(st, i, r) ONLY when enemy i stands exactly on a cell
-- (x and y are both multiples of 16) -- that is the grid-locked turning rule.
-- Between cells the enemy just keeps going in the direction it chose.
--
-- RETURNS:
--   go      : false = stay where it is this frame
--   dir     : 0 up, 1 right, 2 down, 3 left
--   ghost   : true = turn into a ghost and tunnel straight at the player
--   breathe : true = (fire-breather only) start breathing fire
-- INPUT r is 8 random bits from game.vhd.
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

	-- Manhattan distance (in pixels) between two cells' corners
	function dist(ax, ay, bx, by : integer) return integer is
	begin
		return abs(ax - bx) + abs(ay - by);
	end function;

	function enemy_decide(st : game_state_t; i : integer; r : std_logic_vector(7 downto 0)) return edec_t is
		variable d      : edec_t;
		variable c, rw  : integer;            -- this enemy's cell
		variable tx, ty : integer;            -- target (pixels)
		variable ghost  : boolean;
		variable best   : integer;
		variable score  : integer;
		variable nc, nr : integer;
		variable found  : boolean;
		variable rev    : integer;
		variable pd     : integer;
		variable n      : integer;
	begin
		d.go := true;  d.dir := st.edir(i);  d.ghost := false;  d.breathe := false;
		c  := st.ex(i) / TILE;
		rw := st.ey(i) / TILE;
		rev := opposite(st.edir(i));
		ghost := st.eghost(i) > 0;

		-- ----- target: the player, or the top-left corner when this is the last enemy -----
		if alive_count(st) = 1 then
			tx := 0;  ty := ROW_SURF * TILE;
			d.ghost := true;  ghost := true;       -- the last enemy runs away through the dirt
		else
			tx := st.px;  ty := st.py;
		end if;

		-- ----- fire-breather: breathe when the player is lined up in front and close -----
		if st.ekind(i) = 1 and not ghost and alive_count(st) > 1 and r(1 downto 0) = "00" then
			if (st.edir(i) = 1 and st.py = st.ey(i) and st.px > st.ex(i) and st.px - st.ex(i) <= 3 * TILE) or
			   (st.edir(i) = 3 and st.py = st.ey(i) and st.px < st.ex(i) and st.ex(i) - st.px <= 3 * TILE) or
			   (st.edir(i) = 0 and st.px = st.ex(i) and st.py < st.ey(i) and st.ey(i) - st.py <= 3 * TILE) or
			   (st.edir(i) = 2 and st.px = st.ex(i) and st.py > st.ey(i) and st.py - st.ey(i) <= 3 * TILE) then
				d.breathe := true;
				d.go := false;
				return d;
			end if;
		end if;

		-- ----- ghost mode: head straight for the target through anything but rocks -----
		if ghost then
			best := 100000;  found := false;
			for k in 0 to 3 loop
				nc := c  + dir_dx(k);
				nr := rw + dir_dy(k);
				if enemy_cell_ok(st, nc, nr, true) then
					score := dist(nc * TILE, nr * TILE, tx, ty);
					if k = rev then score := score + 8; end if;       -- small bias against turning back
					if score < best then best := score; d.dir := k; found := true; end if;
				end if;
			end loop;
			d.go := found;
			return d;
		end if;

		-- ----- normal mode: move through tunnels, prefer the way that gets closer -----
		best := 100000;  found := false;  n := 0;
		for k in 0 to 3 loop
			nc := c  + dir_dx(k);
			nr := rw + dir_dy(k);
			if k /= rev and enemy_cell_ok(st, nc, nr, false) then
				n := n + 1;
				score := dist(nc * TILE, nr * TILE, tx, ty);
				if k = st.edir(i) then score := score - 4; end if;    -- tiny bias to keep going straight
				if score < best then best := score; d.dir := k; found := true; end if;
			end if;
		end loop;

		-- sometimes pick another open way, so enemies are not perfectly predictable
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
			-- dead end: turn back if possible, and often become a ghost instead
			if enemy_cell_ok(st, c + dir_dx(rev), rw + dir_dy(rev), false) and r(3 downto 2) /= "00" then
				d.dir := rev;
			else
				d.ghost := true;
				best := 100000;  found := false;
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
		elsif n = 1 and r(7 downto 5) = "000" then
			d.ghost := true;                       -- rare spontaneous ghosting
		end if;
		return d;
	end function;

end package body;
