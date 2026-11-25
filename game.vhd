library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.digger_pkg.all;
use work.level_pkg.all;
use work.ai_pkg.all;

entity game is
	port(
		clk      : in  std_logic;
		rst      : in  std_logic;
		tick     : in  std_logic;
		k_up     : in  std_logic;
		k_down   : in  std_logic;
		k_left   : in  std_logic;
		k_right  : in  std_logic;
		k_pump   : in  std_logic;
		k_start  : in  std_logic;
		gs       : out game_state_t;
		ram_we   : out std_logic;
		ram_addr : out chunk_addr_t;
		ram_din  : out std_logic;
		init_ram : out std_logic;
		init_map : out std_logic_vector(0 to ROWS * COLS - 1)
	);
end game;

architecture arch of game is
	signal s : game_state_t;
	signal q_up, q_down, q_left, q_right, q_pump, q_start : std_logic := '0';

	-- 8-chunk (16-px) full-width tunnel carving burst state
	signal dig_active : std_logic := '0';
	signal dig_horiz  : std_logic := '0'; -- '1' = left/right (step +CHUNK_W), '0' = up/down (step +1)
	signal dig_cnt    : unsigned(2 downto 0) := (others => '0'); -- 0..7
	signal dig_addr   : chunk_addr_t := (others => '0');
begin
	gs <= s;

	process(clk)
	begin
		if rising_edge(clk) then
			q_up <= k_up;  q_down <= k_down;  q_left <= k_left;
			q_right <= k_right;  q_pump <= k_pump;  q_start <= k_start;
		end if;
	end process;

	process(clk)
		variable v          : game_state_t;
		variable start_dig  : boolean;
		variable dig_h_v    : std_logic;
		variable start_cx_v : integer range 0 to CHUNK_W - 1;
		variable start_cy_v : integer range 0 to CHUNK_H - 1;
		variable n_alive    : integer range 0 to MAX_ENEMIES;
		variable pb         : rect_t;

		procedure do_player is
			variable want    : integer range -1 to 3;
			variable nd      : integer range 0 to 3;
			variable aligned : boolean;
			variable can     : boolean;
			variable hr      : rect_t;
			variable lx, ly  : integer;
			variable i       : integer range 0 to MAX_ENEMIES - 1;
			variable c, r    : integer range 0 to 17;
		begin
			aligned := (v.px mod TILE = 0) and (v.py mod TILE = 0);

			if q_pump = '1' then
				for k in 1 to HOSE_STEP loop
					if v.hlen < HOSE_MAX then
						v.hlen := v.hlen + 1;
						lx := hose_tip_x(v) - dir_dx(v.pdir);
						ly := hose_tip_y(v) - dir_dy(v.pdir);
						if not hose_cell_ok(v, cell_of(lx), cell_of(ly)) then
							v.hlen := v.hlen - 1;
							exit;
						end if;
					end if;
				end loop;

				v.pump_hit := -1;
				if v.hlen > 0 then
					hr := hose_rect(v);
					for e in 0 to MAX_ENEMIES - 1 loop
						if v.ealive(e) = '1' and v.pump_hit < 0 and rects_overlap(hr, enemy_box(v, e)) then
							v.pump_hit := e;
						end if;
					end loop;
				end if;

				if v.pump_hit >= 0 then
					i := v.pump_hit;
					v.ecnt(i)    := DEFLATE_FRAMES;
					v.eghost(i)  := 0;
					v.ebreath(i) := 0;
					if v.pcool >= PUMP_FRAMES then
						v.pcool := 0;
						if v.einfl(i) = 3 then
							v.ealive(i) := '0';
							v.einfl(i)  := 0;
							v.gain := v.gain + pump_pts(v.ekind(i), (v.ey(i) + 8) / TILE,
							                            v.pdir = 1 or v.pdir = 3);
							v.pump_hit := -1;
							v.hlen := 0;
						else
							v.einfl(i) := v.einfl(i) + 1;
						end if;
					elsif v.pcool < 31 then
						v.pcool := v.pcool + 1;
					end if;
				end if;
			else
				v.hlen := 0;
				v.pump_hit := -1;
				v.pcool := PUMP_FRAMES;

				want := -1;
				if    q_up    = '1' then want := 0;
				elsif q_down  = '1' then want := 2;
				elsif q_left  = '1' then want := 3;
				elsif q_right = '1' then want := 1;
				end if;

				if want >= 0 then
					if want = v.pdir or want = opposite(v.pdir) or aligned then
						nd := want;
					else
						nd := v.pdir;
					end if;
					v.pdir := nd;

					v.pacc := v.pacc + PSPD;
					if v.pacc >= 16 then
						v.pacc := v.pacc - 16;
						can := true;
						if v.px mod TILE = 0 and v.py mod TILE = 0 then
							can := player_cell_ok(v, v.px / TILE + dir_dx(nd), v.py / TILE + dir_dy(nd));
						elsif nd = 1 or nd = 3 then
							if v.px mod TILE = 0 then
								can := player_cell_ok(v, v.px / TILE + dir_dx(nd), v.py / TILE);
							end if;
						else
							if v.py mod TILE = 0 then
								can := player_cell_ok(v, v.px / TILE, v.py / TILE + dir_dy(nd));
							end if;
						end if;
						if can then
							v.px := v.px + dir_dx(nd);
							v.py := v.py + dir_dy(nd);
							start_dig := true;
							if dir_dx(nd) /= 0 then
								dig_h_v := '1';
								if dir_dx(nd) > 0 then
									start_cx_v := (v.px + TILE - 1) / 2;
								else
									start_cx_v := v.px / 2;
								end if;
								start_cy_v := v.py / 2;
							else
								dig_h_v := '0';
								start_cx_v := v.px / 2;
								if dir_dy(nd) > 0 then
									start_cy_v := (v.py + TILE - 1) / 2;
								else
									start_cy_v := v.py / 2;
								end if;
							end if;
						end if;
					end if;

					if v.px mod TILE = 0 and v.py mod TILE = 0 then
						c := (v.px + 8) / TILE;
						r := (v.py + 8) / TILE;
						if r >= ROW_DIRT0 and r <= ROW_DIRT1 then
							v.dirt(r * COLS + c) := '0';
						end if;
					end if;
				end if;
			end if;
		end procedure;

		procedure do_enemies(alive_n : integer) is
			variable dec     : edec_t;
			variable r8      : std_logic_vector(7 downto 0);
			variable aligned : boolean;
			variable moving  : boolean;
			variable nx, ny  : integer range 0 to 288;
			variable spd     : integer range 0 to 15;
		begin
			for i in 0 to MAX_ENEMIES - 1 loop
				if v.ealive(i) = '1' then
					if v.einfl(i) > 0 then
						if v.pump_hit /= i then
							if v.ecnt(i) > 0 then v.ecnt(i) := v.ecnt(i) - 1; end if;
							if v.ecnt(i) = 0 then
								v.einfl(i) := v.einfl(i) - 1;
								v.ecnt(i)  := DEFLATE_FRAMES;
							end if;
						end if;

					elsif v.ebreath(i) > 0 then
						v.ebreath(i) := v.ebreath(i) - 1;

					else
						r8 := std_logic_vector(unsigned(v.lfsr(7 downto 0)) + to_unsigned(i * 59, 8));
						aligned := (v.ex(i) mod TILE = 0) and (v.ey(i) mod TILE = 0);
						moving  := not aligned;

						if v.eghost(i) > 1 then v.eghost(i) := v.eghost(i) - 1; end if;
						if v.eghost(i) = 0 and v.eage(i) < 1023 then v.eage(i) := v.eage(i) + 1; end if;

						if aligned then
							if alive_n = 1 and v.eghost(i) = 0 then
								v.eghost(i) := 1;
							end if;
							if v.eghost(i) = 1 and alive_n > 1 and
							   v.dirt((v.ey(i) / TILE) * COLS + v.ex(i) / TILE) = '0' then
								v.eghost(i) := 0;
								v.eage(i) := ghost_delay(v.rnd) / 2;
							end if;

							if alive_n = 1 and v.ex(i) = 0 and v.ey(i) = ROW_SURF * TILE then
								v.ealive(i) := '0';
							else
								dec := enemy_decide(v, i, r8);
								if dec.ghost and v.eghost(i) = 0 then
									v.eghost(i) := GHOST_FRAMES;
								end if;
								if dec.breathe then
									v.ebreath(i) := BREATH_FRAMES;
								elsif dec.go then
									v.edir(i) := dec.dir;
									moving := true;
								end if;
							end if;
						end if;

						if moving and v.ealive(i) = '1' then
							spd := enemy_spd(v.rnd, v.eghost(i) > 0);
							v.eacc(i) := v.eacc(i) + spd;
							if v.eacc(i) >= 16 then
								v.eacc(i) := v.eacc(i) - 16;
								nx := v.ex(i) + dir_dx(v.edir(i));
								ny := v.ey(i) + dir_dy(v.edir(i));
								if nx < PF_W - TILE + 1 and ny < PF_H - TILE + 1 then
									v.ex(i) := nx;
									v.ey(i) := ny;
								end if;
							end if;
						end if;
					end if;
				end if;
			end loop;
		end procedure;

		procedure do_rocks is
			variable c, r   : integer range 0 to 17;
			variable landed : boolean;
			variable rr     : rect_t;
		begin
			for j in 0 to MAX_ROCKS - 1 loop
				c := v.rx(j) / TILE;
				r := v.ry(j) / TILE;
				case v.rstate(j) is
					when 0 =>
						if r < ROW_DIRT1 and cell_open(v, c, r + 1) and not rock_in_cell(v, c, r + 1) then
							v.rstate(j) := 1;
							v.rtimer(j) := WOBBLE_FRAMES;
						end if;

					when 1 =>
						if v.rtimer(j) > 0 then
							v.rtimer(j) := v.rtimer(j) - 1;
						else
							v.rstate(j) := 2;
							v.rk(j) := 0;
							if v.rdrops < MAX_ROCKS then
								v.rdrops := v.rdrops + 1;
							end if;
							if v.rdrops = 2 and v.vdone = '0' then
								v.vstate := 1;
								v.vtimer := VEG_FRAMES;
								v.vdone  := '1';
							end if;
						end if;

					when 2 =>
						landed := false;
						for k in 1 to FALL_STEP loop
							if not landed then
								if v.ry(j) mod TILE = 0 then
									c := v.rx(j) / TILE;
									r := v.ry(j) / TILE;
									if r >= ROW_DIRT1 or not cell_open(v, c, r + 1) or rock_in_cell(v, c, r + 1) then
										landed := true;
									end if;
								end if;
								if not landed then
									v.ry(j) := v.ry(j) + 1;
								end if;
							end if;
						end loop;

						rr.x0 := v.rx(j) + 1;  rr.x1 := v.rx(j) + 14;
						rr.y0 := v.ry(j) + 1;  rr.y1 := v.ry(j) + 14;
						for e in 0 to MAX_ENEMIES - 1 loop
							if v.ealive(e) = '1' and rects_overlap(rr, enemy_box(v, e)) then
								v.ealive(e) := '0';
								v.einfl(e)  := 0;
								if v.rk(j) < 7 then v.rk(j) := v.rk(j) + 1; end if;
							end if;
						end loop;
						if rects_overlap(rr, pb) then
							v.dead := '1';
						end if;

						if landed then
							v.gain := v.gain + rock_pts(v.rk(j));
							v.rstate(j) := 3;
						end if;

					when others => null;
				end case;
			end loop;
		end procedure;

		procedure do_veg is
			variable vr : rect_t;
		begin
			if v.vstate = 1 then
				if v.vtimer > 0 then
					v.vtimer := v.vtimer - 1;
				else
					v.vstate := 0;
				end if;
				vr.x0 := VEG_COL * TILE + 2;  vr.x1 := VEG_COL * TILE + 13;
				vr.y0 := VEG_ROW * TILE + 2;  vr.y1 := VEG_ROW * TILE + 13;
				if v.vstate = 1 and rects_overlap(vr, pb) then
					v.gain   := v.gain + veg_pts(v.rnd);
					v.vstate := 0;
				end if;
			end if;
		end procedure;

		procedure do_score is
			variable sc_val, hi_val : integer range 0 to 999999;
		begin
			if v.gain > 0 then
				v.score := add_pts(v.score, v.gain);
				v.gain  := 0;
				sc_val := score_val(v.score);
				hi_val := score_val(v.hiscore);
				if sc_val > hi_val then
					v.hiscore := v.score;
				end if;
				if v.bonus(0) = '0' and sc_val >= 20000 then
					v.bonus(0) := '1';
					if v.lives < MAX_LIVES then v.lives := v.lives + 1; end if;
				end if;
				if v.bonus(1) = '0' and sc_val >= 60000 then
					v.bonus(1) := '1';
					if v.lives < MAX_LIVES then v.lives := v.lives + 1; end if;
				end if;
			end if;
		end procedure;

		variable fb : std_logic;
		variable hi : digits_t;
		variable lf : std_logic_vector(15 downto 0);
	begin
		if rising_edge(clk) then
			ram_we    <= '0';
			init_ram  <= '0';
			start_dig := false;
			dig_h_v   := '0';
			start_cx_v := 0;
			start_cy_v := 0;

			if rst = '1' then
				s          <= make_init;
				init_ram   <= '1';
				init_map   <= LEVEL1_MAP;
				dig_active <= '0';
				dig_cnt    <= (others => '0');
			elsif tick = '1' then
				v := s;

				for k in 1 to 8 loop
					fb := v.lfsr(15) xor v.lfsr(13) xor v.lfsr(12) xor v.lfsr(10);
					v.lfsr := v.lfsr(14 downto 0) & fb;
				end loop;

				case v.gstate is
					when 0 =>
						v.dead  := '0';
						n_alive := alive_count(v);
						do_player;
						do_enemies(n_alive);
						pb := player_box(v);
						do_rocks;
						do_veg;

						for e in 0 to MAX_ENEMIES - 1 loop
							if v.ealive(e) = '1' then
								if v.einfl(e) = 0 and rects_overlap(pb, enemy_box(v, e)) then
									v.dead := '1';
								end if;
								if rects_overlap(pb, flame_rect(v, e)) then
									v.dead := '1';
								end if;
							end if;
						end loop;

						do_score;
						n_alive := alive_count(v);

						if v.dead = '1' then
							v.gstate := 1;
							v.gtimer := DEAD_FRAMES;
							v.hlen := 0;
							v.pump_hit := -1;
							if v.lives > 0 then v.lives := v.lives - 1; end if;
						elsif n_alive = 0 then
							v.gstate := 3;
							v.gtimer := CLEAR_FRAMES;
							v.hlen := 0;
							v.pump_hit := -1;
						end if;

					when 1 =>
						if v.gtimer > 0 then
							v.gtimer := v.gtimer - 1;
						elsif v.lives = 0 then
							v.gstate := 2;
						else
							v := respawn(v);
							v.gstate := 4;
							v.gtimer := READY_FRAMES;
						end if;

					when 2 =>
						if q_start = '1' then
							hi := v.hiscore;
							lf := v.lfsr;
							v := make_init;
							v.hiscore := hi;
							v.lfsr := lf;
							init_ram <= '1';
							init_map <= v.dirt;
						end if;

					when 3 =>
						if v.gtimer > 0 then
							v.gtimer := v.gtimer - 1;
						else
							if v.rnd < 256 then v.rnd := v.rnd + 1; end if;
							v := new_round(v);
							init_ram <= '1';
							init_map <= v.dirt;
						end if;

					when others =>
						if v.gtimer > 0 then
							v.gtimer := v.gtimer - 1;
						else
							v.gstate := 0;
						end if;
				end case;

				if q_start = '1' then
					hi := v.hiscore;
					lf := v.lfsr;
					v := make_init;
					v.hiscore := hi;
					v.lfsr := lf;
					init_ram <= '1';
					init_map <= v.dirt;
				end if;

				s <= v;

				if start_dig then
					dig_active <= '1';
					dig_horiz  <= dig_h_v;
					dig_cnt    <= (others => '0');
					dig_addr   <= to_unsigned(start_cy_v * CHUNK_W + start_cx_v, CHUNK_ADDR_W);
				end if;
			elsif dig_active = '1' then
				ram_we   <= '1';
				ram_addr <= dig_addr;
				ram_din  <= '0';

				if dig_cnt = to_unsigned(7, 3) then
					dig_active <= '0';
					dig_cnt    <= (others => '0');
				else
					dig_cnt <= dig_cnt + 1;
					if dig_horiz = '1' then
						dig_addr <= resize(dig_addr + to_unsigned(CHUNK_W, CHUNK_ADDR_W), CHUNK_ADDR_W);
					else
						dig_addr <= resize(dig_addr + to_unsigned(1, CHUNK_ADDR_W), CHUNK_ADDR_W);
					end if;
				end if;
			end if;
		end if;
	end process;
end arch;