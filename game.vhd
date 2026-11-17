-- game.vhd  --  all the game rules. Runs ONCE PER FRAME, on the 'tick' pulse (60 Hz).
--
-- Pattern used everywhere in this file:
--     v := s;          -- copy the state into a variable (a variable changes immediately)
--     ... change v step by step ...
--     s <= v;          -- publish the new state at the end of the frame
-- The renderer only ever sees s, so it never sees a half-finished frame.
--
-- ORDER OF ONE FRAME (gstate = 0, playing):
--     random numbers -> player (move / dig / pump) -> enemies -> rocks -> vegetable
--     -> collisions that kill the player -> score -> round clear / death
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
		tick    : in  std_logic;
		k_up    : in  std_logic;
		k_down  : in  std_logic;
		k_left  : in  std_logic;
		k_right : in  std_logic;
		k_pump  : in  std_logic;
		k_start : in  std_logic;
		gs      : out game_state_t
	);
end game;

architecture arch of game is
	signal s : game_state_t;
	-- the keys are copied into flip-flops every clock; the game logic only ever reads the copies
	signal q_up, q_down, q_left, q_right, q_pump, q_start : std_logic := '0';
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
		variable v : game_state_t;

		-- PLAYER
		procedure do_player is
			variable want    : integer range -1 to 3;
			variable nd      : integer range 0 to 3;
			variable aligned : boolean;
			variable can     : boolean;
			variable hr      : rect_t;
			variable lx, ly  : integer;
			variable i       : integer;
			variable c, r    : integer;
		begin
			aligned := (v.px mod TILE = 0) and (v.py mod TILE = 0);

			if q_pump = '1' then
				-- pumping the digger stands still and the hose grows
				for k in 1 to HOSE_STEP loop
					if v.hlen < HOSE_MAX then
						v.hlen := v.hlen + 1;
						lx := hose_tip_x(v) - dir_dx(v.pdir);    -- last pixel of the hose
						ly := hose_tip_y(v) - dir_dy(v.pdir);
						if not hose_cell_ok(v, cell_of(lx), cell_of(ly)) then
							v.hlen := v.hlen - 1;                -- dirt, rock or edge stop growing
							exit;
						end if;
					end if;
				end loop;

				-- does the hose touch an enemy
				v.pump_hit := -1;
				if v.hlen > 0 then
					hr := hose_rect(v);
					for e in 0 to NUM_ENEMIES - 1 loop
						if v.ealive(e) = '1' and v.pump_hit < 0 and rects_overlap(hr, enemy_box(v, e)) then
							v.pump_hit := e;
						end if;
					end loop;
				end if;

				if v.pump_hit >= 0 then
					i := v.pump_hit;
					v.ecnt(i)    := DEFLATE_FRAMES;       -- being pumped it does not shrink
					v.eghost(i)  := 0;                    -- a pumped ghost is a normal enemy again
					v.ebreath(i) := 0;
					if v.pcool >= PUMP_FRAMES then
						v.pcool := 0;
						if v.einfl(i) = 3 then            -- 4th pump pops
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
				-- walking
				v.hlen := 0;
				v.pump_hit := -1;
				v.pcool := PUMP_FRAMES;                   -- the first pump of a hit is immediate

				want := -1;
				if    q_up    = '1' then want := 0;
				elsif q_down  = '1' then want := 2;
				elsif q_left  = '1' then want := 3;
				elsif q_right = '1' then want := 1;
				end if;

				if want >= 0 then
					-- changing axis is only allowed exactly on a cell
					if want = v.pdir or want = opposite(v.pdir) or aligned then
						nd := want;
					else
						nd := v.pdir;                     -- keep going until we are on a cell
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
						end if;
					end if;

					-- digging: the cell under the middle of the digger becomes tunnel
					c := (v.px + 8) / TILE;
					r := (v.py + 8) / TILE;
					if r >= ROW_DIRT0 and r <= ROW_DIRT1 then
						v.dirt(r * COLS + c) := '0';
					end if;
				end if;
			end if;
		end procedure;

		-- ENEMIES
		procedure do_enemies is
			variable dec     : edec_t;
			variable r8      : std_logic_vector(7 downto 0);
			variable aligned : boolean;
			variable moving  : boolean;
			variable nx, ny  : integer;
			variable spd     : integer;
		begin
			for i in 0 to NUM_ENEMIES - 1 loop
				if v.ealive(i) = '1' then
					if v.einfl(i) > 0 then
						-- inflation frozen, slowly shrinks again unless the hose still holds it
						if v.pump_hit /= i then
							if v.ecnt(i) > 0 then v.ecnt(i) := v.ecnt(i) - 1; end if;
							if v.ecnt(i) = 0 then
								v.einfl(i) := v.einfl(i) - 1;
								v.ecnt(i)  := DEFLATE_FRAMES;
							end if;
						end if;

					elsif v.ebreath(i) > 0 then
						v.ebreath(i) := v.ebreath(i) - 1;      -- wind up, then flame

					else
						-- normal movement
						r8 := std_logic_vector(unsigned(v.lfsr(7 downto 0)) + to_unsigned(i * 59, 8));
						aligned := (v.ex(i) mod TILE = 0) and (v.ey(i) mod TILE = 0);
						moving  := not aligned;

						if v.eghost(i) > 1 then v.eghost(i) := v.eghost(i) - 1; end if;
						if v.eghost(i) = 0 and v.eage(i) < 1023 then v.eage(i) := v.eage(i) + 1; end if;

						if aligned then
							-- a lone enemy always runs for the top-left corner as a ghost
							if alive_count(v) = 1 and v.eghost(i) = 0 then
								v.eghost(i) := 1;
							end if;
							-- ghost turns back to normal on the first open cell, once its time is up
							if v.eghost(i) = 1 and alive_count(v) > 1 and
							   v.dirt((v.ey(i) / TILE) * COLS + v.ex(i) / TILE) = '0' then
								v.eghost(i) := 0;
								v.eage(i) := ghost_delay(v.rnd) / 2;   -- walks a while before the next ghost trip
							end if;

							if alive_count(v) = 1 and v.ex(i) = 0 and v.ey(i) = ROW_SURF * TILE then
								v.ealive(i) := '0';            -- escaped: no points
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
								if nx >= 0 and nx < PF_W - TILE + 1 and ny >= 0 and ny < PF_H - TILE + 1 then
									v.ex(i) := nx;
									v.ey(i) := ny;
								end if;
							end if;
						end if;
					end if;
				end if;
			end loop;
		end procedure;

		-- rocks
		procedure do_rocks is
			variable c, r   : integer;
			variable landed : boolean;
			variable rr     : rect_t;
		begin
			for j in 0 to NUM_ROCKS - 1 loop
				c := v.rx(j) / TILE;
				r := v.ry(j) / TILE;
				case v.rstate(j) is
					when 0 =>                                  -- sitting: is there a hole under it?
						if r < ROW_DIRT1 and cell_open(v, c, r + 1) and not rock_in_cell(v, c, r + 1) then
							v.rstate(j) := 1;
							v.rtimer(j) := WOBBLE_FRAMES;
						end if;

					-- wobbling
					when 1 =>
						if v.rtimer(j) > 0 then
							v.rtimer(j) := v.rtimer(j) - 1;
						else
							v.rstate(j) := 2;
							v.rk(j) := 0;
							v.dirt(r * COLS + c) := '0';       -- its own cell becomes open
							if v.rdrops < NUM_ROCKS then
								v.rdrops := v.rdrops + 1;
							end if;
							-- vegetable appears after the SECOND rock has dropped
							if v.rdrops = 2 and v.vdone = '0' then
								v.vstate := 1;
								v.vtimer := VEG_FRAMES;
								v.vdone  := '1';
								v.dirt(VEG_ROW * COLS + VEG_COL) := '0';
							end if;
						end if;

					when 2 =>                                  -- falling
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

						-- crush enemies and the player
						rr.x0 := v.rx(j) + 1;  rr.x1 := v.rx(j) + 14;
						rr.y0 := v.ry(j) + 1;  rr.y1 := v.ry(j) + 14;
						for e in 0 to NUM_ENEMIES - 1 loop
							if v.ealive(e) = '1' and rects_overlap(rr, enemy_box(v, e)) then
								v.ealive(e) := '0';
								v.einfl(e)  := 0;
								if v.rk(j) < 7 then v.rk(j) := v.rk(j) + 1; end if;
							end if;
						end loop;
						if rects_overlap(rr, player_box(v)) then
							v.dead := '1';
						end if;

						if landed then
							v.gain := v.gain + rock_pts(v.rk(j));
							v.rstate(j) := 3;                  -- the rock breaks and disappears
						end if;

					when others => null;
				end case;
			end loop;
		end procedure;

		-- vegetable
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
				if v.vstate = 1 and rects_overlap(vr, player_box(v)) then
					v.gain   := v.gain + veg_pts(v.rnd);
					v.vstate := 0;
				end if;
			end if;
		end procedure;

		-- score
		procedure do_score is
		begin
			if v.gain > 0 then
				v.score := add_pts(v.score, v.gain);
				v.gain  := 0;
				if score_val(v.score) > score_val(v.hiscore) then
					v.hiscore := v.score;
				end if;
				if v.bonus(0) = '0' and score_val(v.score) >= 20000 then
					v.bonus(0) := '1';
					if v.lives < MAX_LIVES then v.lives := v.lives + 1; end if;
				end if;
				if v.bonus(1) = '0' and score_val(v.score) >= 60000 then
					v.bonus(1) := '1';
					if v.lives < MAX_LIVES then v.lives := v.lives + 1; end if;
				end if;
			end if;
		end procedure;

		variable fb  : std_logic;
		variable hi  : digits_t;
		variable lf  : std_logic_vector(15 downto 0);
		variable pb  : rect_t;
	begin
		if rising_edge(clk) then
			if rst = '1' then
				s <= make_init;
			elsif tick = '1' then
				v := s;

				for k in 1 to 8 loop
					fb := v.lfsr(15) xor v.lfsr(13) xor v.lfsr(12) xor v.lfsr(10);
					v.lfsr := v.lfsr(14 downto 0) & fb;
				end loop;

				case v.gstate is

					-- playing
					when 0 =>
						v.dead := '0';
						do_player;
						do_enemies;
						do_rocks;
						do_veg;

						-- things that kill the digger
						pb := player_box(v);
						for e in 0 to NUM_ENEMIES - 1 loop
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

						if v.dead = '1' then
							v.gstate := 1;
							v.gtimer := DEAD_FRAMES;
							v.hlen := 0;
							v.pump_hit := -1;
							if v.lives > 0 then v.lives := v.lives - 1; end if;
						elsif alive_count(v) = 0 then
							v.gstate := 3;
							v.gtimer := CLEAR_FRAMES;
							v.hlen := 0;
							v.pump_hit := -1;
						end if;

					-- digger just died
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

					-- game over
					when 2 =>
						if q_start = '1' then
							hi := v.hiscore;
							lf := v.lfsr;
							v := make_init;
							v.hiscore := hi;
							v.lfsr := lf;
						end if;

					when 3 =>                                  -- round cleared
						if v.gtimer > 0 then
							v.gtimer := v.gtimer - 1;
						else
							if v.rnd < 256 then v.rnd := v.rnd + 1; end if;
							v := new_round(v);
						end if;

					when others =>                             -- "get ready" 
						if v.gtimer > 0 then
							v.gtimer := v.gtimer - 1;
						else
							v.gstate := 0;
						end if;
				end case;

				--  restart: new game, but keep the high score and random bits
				if q_start = '1' then
					hi := v.hiscore;
					lf := v.lfsr;
					v := make_init;
					v.hiscore := hi;
					v.lfsr := lf;
				end if;

				s <= v;
			end if;
		end if;
	end process;
end arch;