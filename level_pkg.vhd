-- level_pkg.vhd  --  OWNER: Person B (Graphics & Level)
--
-- GOAL: design the starting level. make_init returns the game_state_t the game starts from
-- (and returns to on reset / restart). Person C's game.vhd uses it as:  constant INIT := make_init;
--
-- RULES for a playable level (check these, they are easy to get wrong):
--   * Row 0 (the sky strip) must stay '0' in s.dirt. Playable rows are 1..14.
--   * The player's start cell (PLAYER_X0, PLAYER_Y0) must be open ('0'), and so should the
--     cells next to it, or he can't move except by digging.
--   * Each enemy's start cell (EX0(i), EY0(i)) must be open. Give each a small pocket
--     (2-3 open cells) so it has room to move at the start. The start cells are in
--     digger_pkg.vhd; if you want different ones, tell the team and change them there.
--   * A rock sits in an OPEN cell (its own dirt bit is '0') with DIRT directly below it.
--     If the cell below a rock is open, the rock starts falling immediately!
--   * Don't put an enemy pocket right under a rock unless you want that on purpose.
--
-- TODO(B):
--   1. Carve the player's starting corridor (a few open cells in row 1 around column 10).
--   2. Carve a pocket for each of the three enemies.
--   3. Carve the cell for each of the two rocks and set s.rx / s.ry to match.
--      (dirt index of cell (x, y) is  y*COLS + x )
--   4. Play-test the layout with Person C once the game moves. Make it fun: how far apart
--      are the enemies? Are the rocks above places the player will want to dig under?
--
-- Everything not marked TODO is already filled in so the project compiles.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.digger_pkg.all;

package level_pkg is
	function make_init return game_state_t;
end package;

package body level_pkg is

	function make_init return game_state_t is
		variable s : game_state_t;
	begin
		s.dirt := (others => '1');
		for x in 0 to COLS-1 loop
			s.dirt(x) := '0';                      -- row 0 = sky / HUD, never dirt
		end loop;

		-- TODO(B): carve the player's corridor, e.g.
		--   for x in 8 to 12 loop s.dirt(1*COLS + x) := '0'; end loop;
		-- TODO(B): carve one pocket for each enemy (around EX0(i), EY0(i)).
		-- TODO(B): carve the two rock cells (the same cells you give s.rx / s.ry below).

		s.gstate := 0;
		s.gtimer := 0;
		s.lives  := 3;
		s.px     := PLAYER_X0;
		s.py     := PLAYER_Y0;
		s.pdir   := 1;
		s.pcnt   := 0;
		s.pcool  := 0;
		s.hlen   := 0;
		s.ex     := EX0;
		s.ey     := EY0;
		s.einfl  := (others => 0);
		s.eghost := (others => 0);
		s.ecnt   := (others => 0);
		s.ealive := (others => '1');
		s.rx     := (6, 13);          -- TODO(B): choose your rock positions
		s.ry     := (4, 9);
		s.rstate := (others => 0);
		s.rtimer := (others => 0);
		s.lfsr   := x"ACE1";          -- must never be all zeros
		return s;
	end function;

end package body;
