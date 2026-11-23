-- level_pkg.vhd  --  the starting layout (same every round, as in the arcade)
-- make_level : dirt map only (used at the start of every round)
-- make_init  : a complete fresh state (round 1, new game); the high score is kept by game.vhd
library IEEE;
use IEEE.std_logic_1164.all;
use work.digger_pkg.all;

package level_pkg is
	function make_level(level : integer) return std_logic_vector;
	-- fresh round: map, player, enemies, rocks, vegetable reset. Score, lives, round, bonus untouched.
	function new_round(st : game_state_t) return game_state_t;
	-- after the player dies: player and surviving enemies go back to their start, map stays
	function respawn(st : game_state_t) return game_state_t;
	function make_init return game_state_t;
	type level_start_t is record
		px          : integer;
		py          : integer;
		num_enemies : integer range 0 to MAX_ENEMIES;
		num_rocks   : integer range 0 to MAX_ROCKS;
		ex          : ex_arr;
		ey          : ey_arr;
		ekind       : ekind_arr;
		rx          : rx_arr;
		ry          : ry_arr;
	end record;
	function level_start(level : integer) return level_start_t;
end package;

package body level_pkg is

	function level_start(level : integer) return level_start_t is
		variable s : level_start_t;
	begin
		s.px := tile_to_px(6);
		s.py := tile_to_py(8);

		s.num_enemies := 0;
		s.ex := (others => 0);
		s.ey := (others => 0);
		s.ekind := (others => 0);

		s.num_rocks := 0;
		s.rx := (others => 0);
		s.ry := (others => 0);

		case level is

			when 1 =>
				s.num_enemies := 4;
				s.num_rocks := 3;

				s.ex(0 to 3) := (16, 48, 144, 176);
				s.ey(0 to 3) := (48, 176, 208, 48);
				s.ekind(0 to 3) := (0, 1, 0, 0);

				s.rx := (48, 64, 160);
				s.ry := (192, 64, 160);

			when 2 =>
				s.num_enemies := 5;
				s.num_rocks := 4;

				s.ex(0 to 4) := (16, 32, 112, 176, 176);
				s.ey(0 to 4) := (176, 112, 160, 64, 192);
				s.ekind(0 to 4) := (0, 0, 0, 1, 1);

				s.rx := (32, 64, 128, 192);
				s.ry := (48, 192, 64, 144);

			when others =>
				null;

		end case;

		return s;
	end function;

	function make_level(level : integer) return std_logic_vector is
		variable d : std_logic_vector(0 to ROWS * COLS - 1) := (others => '0');

		procedure carve(c, r : integer) is
		begin
			if c >= 0 and c < COLS and r >= 0 and r < ROWS then
				d(r * COLS + c) := '0';
			end if;
		end procedure;

	begin
		-- Fill dirt rows
		for r in ROW_DIRT0 to ROW_DIRT1 loop
			for c in 0 to COLS - 1 loop
				d(r * COLS + c) := '1';
			end loop;
		end loop;

		-- Common player starting tunnel
		for i in 0 to 8 loop 
			carve(6, i);
		end loop;
		carve(5, 8);
		carve(7, 8);

		-- Different layout depending on level
		case level is

			when 1 =>
				-- level 1
				for c in 2 to 5 loop
					carve(c, 11);
				end loop;
				
				for r in 3 to 7 loop
					carve(1, r);
				end loop;

				for c in 9 to 12 loop
					carve(c, 3);
				end loop;

				for r in 10 to 14 loop
					carve(9, r);
				end loop;

			when 2 =>
				-- level 2
				for r in 10 to 12 loop
					carve(1, r);
				end loop;

				for c in 1 to 3 loop
					carve(c, 7);
				end loop;

				for c in 6 to 8 loop
					carve(c, 10);
				end loop;

				for c in 10 to 12 loop
					carve(c, 4);
				end loop;

				for c in 10 to 12 loop
					carve(c, 12);
				end loop;

			when others =>
				null;

		end case;

		return d;
	end function;

	function respawn(st : game_state_t) return game_state_t is
		variable v : game_state_t := st;
		variable s : level_start_t;
	begin
		s := level_start(((st.rnd - 1) mod 2) + 1);

		-- Reset player position
		v.px := s.px;
		v.py := s.py;
		v.pdir := 2;
		v.pacc := 0;

		v.hlen := 0;
		v.pcool := PUMP_FRAMES;
		v.pump_hit := -1;

		-- Reset enemy positions
		v.ex := s.ex;
		v.ey := s.ey;

		for i in 0 to MAX_ENEMIES - 1 loop
			v.edir(i) := 1;
			v.eacc(i) := 0;
			v.einfl(i) := 0;
			v.eghost(i) := 0;
			v.ecnt(i) := 0;
			v.ebreath(i) := 0;
			v.eage(i) := 0;
		end loop;

		v.gain := 0;
		v.dead := '0';

		return v;
	end function;

	function new_round(st : game_state_t) return game_state_t is
		variable v : game_state_t := st;
		variable s : level_start_t;
		variable level : integer;
	begin
		level := ((st.rnd - 1) mod 2) + 1;
		s := level_start(level);

		v := respawn(st);
		v.dirt := make_level(level);

		-- Activate only the enemies used by this level
		for i in 0 to MAX_ENEMIES - 1 loop
			if i < s.num_enemies then
				v.ealive(i) := '1';
			else
				v.ealive(i) := '0';
			end if;
		end loop;

		v.ekind := s.ekind;

		-- Reset rocks to level-specific positions
		v.rx := s.rx;
		v.ry := s.ry;

		-- Activate only the rocks used by this level
		for j in 0 to MAX_ROCKS - 1 loop
			if j < s.num_rocks then
				v.rstate(j) := 0;
			else
				v.rstate(j) := 3;
			end if;

			v.rtimer(j) := 0;
			v.rk(j) := 0;
		end loop;

		v.rdrops := 0;

		-- Reset vegetable
		v.vstate := 0;
		v.vtimer := 0;
		v.vdone := '0';

		-- Ready state
		v.gstate := 4;
		v.gtimer := READY_FRAMES;

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