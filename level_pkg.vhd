-- level_pkg.vhd  --  the starting layout (same every round, as in the arcade)
-- make_level : dirt map only (used at the start of every round)
-- make_init  : a complete fresh state (round 1, new game); the high score is kept by game.vhd
library IEEE;
use IEEE.std_logic_1164.all;
use work.digger_pkg.all;

package level_pkg is
	function make_level return std_logic_vector;
	-- fresh round: map, player, enemies, rocks, vegetable reset. Score, lives, round, bonus untouched.
	function new_round(st : game_state_t) return game_state_t;
	-- after the player dies: player and surviving enemies go back to their start, map stays
	function respawn(st : game_state_t) return game_state_t;
	function make_init return game_state_t;
end package;

package body level_pkg is

	function make_level return std_logic_vector is
		variable d : std_logic_vector(0 to ROWS * COLS - 1) := (others => '0');
		procedure carve(c, r : integer) is
		begin
			d(r * COLS + c) := '0';
		end procedure;
	begin
		-- every cell in the dirt rows starts as dirt
		for r in ROW_DIRT0 to ROW_DIRT1 loop
			for c in 0 to COLS - 1 loop
				d(r * COLS + c) := '1';
			end loop;
		end loop;
		-- player's start tunnel (cells (6,2) and (6,3))
		carve(6, 2);  carve(6, 3);
		-- one small pocket per enemy (3 cells wide, centred on the enemy)
		carve(1, 5);  carve(2, 5);  carve(3, 5);
		carve(10, 6); carve(11, 6); carve(12, 6);
		carve(2, 11); carve(3, 11); carve(4, 11);
		carve(9, 13); carve(10, 13); carve(11, 13);
		-- DO NOT carve the cell under a rock: it would drop at once.
		-- Rocks start at cells (7,4) (4,9) (10,10).
		return d;
	end function;

	function respawn(st : game_state_t) return game_state_t is
		variable v : game_state_t := st;
	begin
		v.px := PX0;  v.py := PY0;  v.pdir := 2;  v.pacc := 0;
		v.hlen := 0;  v.pcool := PUMP_FRAMES;  v.pump_hit := -1;
		for i in 0 to NUM_ENEMIES - 1 loop
			v.ex(i) := EX0(i);  v.ey(i) := EY0(i);
			v.edir(i) := 1;  v.eacc(i) := 0;  v.einfl(i) := 0;
			v.eghost(i) := 0;  v.ecnt(i) := 0;  v.ebreath(i) := 0;  v.eage(i) := 0;
		end loop;
		v.gain := 0;  v.dead := '0';
		return v;
	end function;

	function new_round(st : game_state_t) return game_state_t is
		variable v : game_state_t := st;
	begin
		v := respawn(st);
		v.dirt := make_level;
		for i in 0 to NUM_ENEMIES - 1 loop
			v.ealive(i) := '1';
			v.ekind(i)  := EKIND0(i);
		end loop;
		for j in 0 to NUM_ROCKS - 1 loop
			v.rx(j) := RX0(j);  v.ry(j) := RY0(j);
			v.rstate(j) := 0;   v.rtimer(j) := 0;  v.rk(j) := 0;
		end loop;
		v.rdrops := 0;
		v.vstate := 0;  v.vtimer := 0;  v.vdone := '0';
		v.gstate := 4;  v.gtimer := READY_FRAMES;
		return v;
	end function;

	function make_init return game_state_t is
		variable v : game_state_t;
	begin
		v.gstate := 4;  v.gtimer := READY_FRAMES;
		v.rnd := 1;  v.lives := START_LIVES;
		v.score := (others => 0);  v.hiscore := (others => 0);
		v.bonus := "00";
		v.lfsr := x"ACE1";
		v := new_round(v);
		return v;
	end function;

end package body;