-- demo_pkg.vhd  --  OWNER: Person B (Graphics & Level)
--
-- GOAL: a hard-coded, frozen "fake game state" so you can test your artwork and renderer
-- WITHOUT waiting for Person C's game logic. In digger_top.vhd set
--     constant USE_DEMO_STATE : boolean := true;
-- and the renderer draws THIS state instead of the real one.
--
-- The state below already compiles and shows a few things. TODO(B): extend it so that
-- EVERY thing the renderer can draw is on screen at once, then check each one looks right:
--   * the player facing each of the 4 directions (edit pdir and rebuild; left is mirrored)
--   * the pump line pointing in each direction, with hlen = 1, 2 and 3
--   * enemies at inflation 0, 1, 2 and a ghost (eghost > 0) so all 4 enemy sprites show
--   * a still rock and a wobbling rock (rstate = 1 and different rtimer values)
--   * the HUD: lives = 0..3 and 0..3 enemies alive
--   * the three game modes (gstate = 0, 2, 3) change the tunnel color; gstate = 1 blinks the player
-- Tip: change one value, rebuild, look at the monitor. Keep a copy of what each setting does.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.digger_pkg.all;

package demo_pkg is
	function make_demo return game_state_t;
end package;

package body demo_pkg is

	function make_demo return game_state_t is
		variable s : game_state_t;
	begin
		-- all dirt, row 0 open (sky)
		s.dirt := (others => '1');
		for x in 0 to COLS-1 loop
			s.dirt(x) := '0';
		end loop;

		-- a horizontal tunnel on row 3 and a vertical shaft down column 10
		for x in 2 to 17 loop
			s.dirt(3*COLS + x) := '0';
		end loop;
		for y in 1 to 10 loop
			s.dirt(y*COLS + 10) := '0';
		end loop;
		-- TODO(B): carve more tunnels / pockets so enemies and rocks have somewhere to sit.

		s.gstate := 0;
		s.gtimer := 0;
		s.lives  := 3;

		s.px := 5;  s.py := 3;  s.pdir := 3;      -- player on the tunnel, facing left
		s.pcnt := 0;  s.pcool := 0;
		s.hlen := 2;                              -- pump line 2 cells long

		s.ex     := (8, 12, 10);
		s.ey     := (3, 3, 8);
		s.einfl  := (0, 1, 0);                    -- enemy 1 slightly inflated
		s.eghost := (0, 0, 10);                   -- enemy 2 is a ghost
		s.ecnt   := (others => 0);
		s.ealive := (others => '1');

		s.rx     := (14, 4);
		s.ry     := (3, 6);
		s.rstate := (0, 1);                       -- rock 1 wobbling
		s.rtimer := (0, 4);

		s.lfsr := x"ACE1";
		return s;
	end function;

end package body;
