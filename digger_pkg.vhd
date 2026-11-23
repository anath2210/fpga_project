library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package digger_pkg is

	-- ===================== geometry =====================
	constant TILE         : integer := 16;
	constant COLS         : integer := 14;
	constant ROWS         : integer := 18;
	constant PF_W         : integer := COLS * TILE;              -- 224
	constant PF_H         : integer := ROWS * TILE;              -- 288
	constant CHUNK_W      : integer := PF_W / 2;                 -- 112 (2x2 px per chunk)
	constant CHUNK_H      : integer := PF_H / 2;                 -- 144
	constant NUM_CHUNKS   : integer := CHUNK_W * CHUNK_H;        -- 16128 (fits in one RAMB18E1)
	constant CHUNK_ADDR_W : integer := 14;
	constant PF_X0        : integer := 208;
	constant PF_Y0        : integer := 96;
	constant ROW_SURF     : integer := 1;
	constant ROW_DIRT0    : integer := 2;
	constant ROW_DIRT1    : integer := 16;
	constant ROW_HUD1     : integer := 17;

	constant NUM_ENEMIES : integer := 4;
	constant NUM_ROCKS   : integer := 3;
	constant MAX_LIVES   : integer := 5;
	constant START_LIVES : integer := 3;

	-- ===================== tuning =====================
	constant PSPD           : integer := 12;
	constant HOSE_MAX       : integer := 40;
	constant HOSE_STEP      : integer := 4;
	constant PUMP_FRAMES    : integer := 30;
	constant DEFLATE_FRAMES : integer := 40;
	constant WOBBLE_FRAMES  : integer := 40;
	constant FALL_STEP      : integer := 2;
	constant READY_FRAMES   : integer := 90;
	constant DEAD_FRAMES    : integer := 90;
	constant CLEAR_FRAMES   : integer := 120;
	constant BREATH_FRAMES  : integer := 60;
	constant FIRE_FRAMES    : integer := 30;
	constant FIRE_LEN       : integer := 40;
	constant GHOST_FRAMES   : integer := 100;
	constant GHOST_WAIT     : integer := 600;
	constant VEG_FRAMES     : integer := 600;
	constant VEG_COL        : integer := 6;
	constant VEG_ROW        : integer := 9;
	constant HIT            : integer := 12;

	-- ===================== types =====================
	subtype digit_t is integer range 0 to 9;
	type digits_t is array (0 to 5) of digit_t;
	subtype xpos_t is integer range 0 to PF_W - 1;
	subtype ypos_t is integer range 0 to PF_H - 1;
	subtype chunk_addr_t is unsigned(CHUNK_ADDR_W - 1 downto 0);

	type ex_arr    is array (0 to NUM_ENEMIES - 1) of xpos_t;
	type ey_arr    is array (0 to NUM_ENEMIES - 1) of ypos_t;
	type edir_arr  is array (0 to NUM_ENEMIES - 1) of integer range 0 to 3;
	type eacc_arr  is array (0 to NUM_ENEMIES - 1) of integer range 0 to 31;
	type einfl_arr is array (0 to NUM_ENEMIES - 1) of integer range 0 to 3;
	type etmr_arr  is array (0 to NUM_ENEMIES - 1) of integer range 0 to 127;
	type eage_arr  is array (0 to NUM_ENEMIES - 1) of integer range 0 to 1023;
	type ebr_arr   is array (0 to NUM_ENEMIES - 1) of integer range 0 to 63;
	type ekind_arr is array (0 to NUM_ENEMIES - 1) of integer range 0 to 1;
	type rx_arr    is array (0 to NUM_ROCKS - 1) of xpos_t;
	type ry_arr    is array (0 to NUM_ROCKS - 1) of ypos_t;
	type rst_arr   is array (0 to NUM_ROCKS - 1) of integer range 0 to 3;
	type rtm_arr   is array (0 to NUM_ROCKS - 1) of integer range 0 to 63;
	type rk_arr    is array (0 to NUM_ROCKS - 1) of integer range 0 to 7;
	type chunk_dirt_t is array (0 to NUM_CHUNKS - 1) of std_logic;

	-- ===================== THE GAME STATE =====================
	type game_state_t is record
		dirt    : std_logic_vector(0 to ROWS * COLS - 1);
		gstate  : integer range 0 to 4;
		gtimer  : integer range 0 to 127;
		rnd     : integer range 1 to 256;
		lives   : integer range 0 to MAX_LIVES;
		score   : digits_t;
		hiscore : digits_t;
		bonus   : std_logic_vector(0 to 1);
		px      : xpos_t;
		py      : ypos_t;
		pdir    : integer range 0 to 3;
		pacc 	: integer range 0 to 31;
		hlen    : integer range 0 to HOSE_MAX;
		pcool   : integer range 0 to 31;
		pump_hit: integer range -1 to NUM_ENEMIES - 1;
		ex      : ex_arr;
		ey      : ey_arr;
		edir    : edir_arr;
		eacc    : eacc_arr;
		einfl   : einfl_arr;
		eghost  : etmr_arr;
		ecnt    : etmr_arr;
		eage    : eage_arr;
		ebreath : ebr_arr;
		ealive  : std_logic_vector(0 to NUM_ENEMIES - 1);
		ekind   : ekind_arr;
		rx      : rx_arr;
		ry      : ry_arr;
		rstate  : rst_arr;
		rtimer  : rtm_arr;
		rk      : rk_arr;
		rdrops  : integer range 0 to NUM_ROCKS;
		vstate  : integer range 0 to 1;
		vtimer  : integer range 0 to 600;
		vdone   : std_logic;
		gain    : integer range 0 to 16383;
		dead    : std_logic;
		lfsr    : std_logic_vector(15 downto 0);
	end record;

	-- ===================== start positions =====================
	constant PX0 : integer := 96;
	constant PY0 : integer := 32;
	constant EX0    : ex_arr    := (32, 176, 48, 160);
	constant EY0    : ey_arr    := (80, 96, 176, 208);
	constant EKIND0 : ekind_arr := (0, 1, 0, 1);
	constant RX0    : rx_arr    := (112, 64, 160);
	constant RY0    : ry_arr    := (64, 144, 160);

	-- ===================== rectangles =====================
	type rect_t is record
		x0, y0, x1, y1 : integer range -64 to 320;
	end record;
	function in_rect(r : rect_t; x, y : integer) return boolean;
	function rects_overlap(a, b : rect_t) return boolean;
	function player_box(st : game_state_t) return rect_t;
	function hose_rect(st : game_state_t) return rect_t;
	function fire_active(st : game_state_t; i : integer) return boolean;
	function flame_rect(st : game_state_t; i : integer) return rect_t;
	function hose_tip_x(st : game_state_t) return integer;
	function hose_tip_y(st : game_state_t) return integer;

	-- ===================== map & chunk helpers =====================
	function tile_to_px(c : integer) return integer;
	function tile_to_py(r : integer) return integer;
	function tile_center_x(c : integer) return integer;
	function tile_center_y(r : integer) return integer;
	function chunk_addr_of(x, y : integer) return chunk_addr_t;
	function px_is_chunk_dirt(cd : chunk_dirt_t; x, y : integer) return boolean;
	function dir_dx(d : integer) return integer;
	function dir_dy(d : integer) return integer;
	function opposite(d : integer) return integer;
	function cell_open(st : game_state_t; c, r : integer) return boolean;
	function rock_in_cell(st : game_state_t; c, r : integer) return boolean;
	function enemy_cell_ok(st : game_state_t; c, r : integer; ghost : boolean) return boolean;
	function enemy_span_ok(st : game_state_t; x, y : integer; ghost : boolean) return boolean;
	function player_cell_ok(st : game_state_t; c, r : integer) return boolean;
	function hose_cell_ok(st : game_state_t; c, r : integer) return boolean;
	function in_dirt(st : game_state_t; x, y : integer) return boolean;
	function alive_count(st : game_state_t) return integer;
	function cell_of(x : integer) return integer;
	function enemy_box(st : game_state_t; i : integer) return rect_t;
	function overlap(ax, ay, bx, by : integer) return boolean;
	function enemy_at(st : game_state_t; x, y : integer) return integer;

	-- ===================== scoring helpers =====================
	function score_val(d : digits_t) return integer;
	function add_pts(d : digits_t; pts : integer) return digits_t;
	function layer_of_row(r : integer) return integer;
	function pump_pts(kind : integer; row : integer; side : boolean) return integer;
	function rock_pts(n : integer) return integer;
	function veg_pts(rnd : integer) return integer;
	function veg_tier(rnd : integer) return integer;
	function ghost_delay(rnd : integer) return integer;
	function enemy_spd(rnd : integer; ghost : boolean) return integer;

end package;

package body digger_pkg is

	function in_rect(r : rect_t; x, y : integer) return boolean is
	begin
		return x >= r.x0 and x <= r.x1 and y >= r.y0 and y <= r.y1;
	end function;

	function rects_overlap(a, b : rect_t) return boolean is
	begin
		return a.x0 <= b.x1 and b.x0 <= a.x1 and a.y0 <= b.y1 and b.y0 <= a.y1;
	end function;

	function player_box(st : game_state_t) return rect_t is
		variable r : rect_t;
	begin
		r.x0 := st.px + 3;  r.x1 := st.px + 12;
		r.y0 := st.py + 3;  r.y1 := st.py + 12;
		return r;
	end function;

	function hose_rect(st : game_state_t) return rect_t is
		variable r : rect_t;
	begin
		case st.pdir is
			when 1 =>
				r.x0 := st.px + TILE;           r.x1 := st.px + TILE + st.hlen - 1;
				r.y0 := st.py + 6;              r.y1 := st.py + 9;
			when 3 =>
				r.x1 := st.px - 1;              r.x0 := st.px - st.hlen;
				r.y0 := st.py + 6;              r.y1 := st.py + 9;
			when 0 =>
				r.y1 := st.py - 1;              r.y0 := st.py - st.hlen;
				r.x0 := st.px + 6;              r.x1 := st.px + 9;
			when others =>
				r.y0 := st.py + TILE;           r.y1 := st.py + TILE + st.hlen - 1;
				r.x0 := st.px + 6;              r.x1 := st.px + 9;
		end case;
		return r;
	end function;

	function hose_tip_x(st : game_state_t) return integer is
	begin
		case st.pdir is
			when 1      => return st.px + TILE + st.hlen;
			when 3      => return st.px - 1 - st.hlen;
			when others => return st.px + 8;
		end case;
	end function;

	function hose_tip_y(st : game_state_t) return integer is
	begin
		case st.pdir is
			when 0      => return st.py - 1 - st.hlen;
			when 2      => return st.py + TILE + st.hlen;
			when others => return st.py + 8;
		end case;
	end function;

	function fire_active(st : game_state_t; i : integer) return boolean is
	begin
		return st.ealive(i) = '1' and st.einfl(i) = 0 and
		       st.ebreath(i) > 0 and st.ebreath(i) <= FIRE_FRAMES;
	end function;

	-- Horizontal-only Fygar flame rectangle (left/right only)
	function flame_rect(st : game_state_t; i : integer) return rect_t is
		variable r : rect_t;
	begin
		r.x0 := 1; r.x1 := 0; r.y0 := 1; r.y1 := 0;
		if fire_active(st, i) then
			if st.edir(i) = 1 then
				r.x0 := st.ex(i) + TILE;        r.x1 := st.ex(i) + TILE + FIRE_LEN - 1;
				r.y0 := st.ey(i) + 4;           r.y1 := st.ey(i) + 11;
			elsif st.edir(i) = 3 then
				r.x1 := st.ex(i) - 1;           r.x0 := st.ex(i) - FIRE_LEN;
				r.y0 := st.ey(i) + 4;           r.y1 := st.ey(i) + 11;
			end if;
		end if;
		return r;
	end function;

	function tile_to_px(c : integer) return integer is
	begin
		return c * TILE;
	end function;

	function tile_to_py(r : integer) return integer is
	begin
		return r * TILE;
	end function;

	function tile_center_x(c : integer) return integer is
	begin
		return c * TILE + TILE / 2;
	end function;

	function tile_center_y(r : integer) return integer is
	begin
		return r * TILE + TILE / 2;
	end function;

	function chunk_addr_of(x, y : integer) return chunk_addr_t is
		variable idx : integer range 0 to NUM_CHUNKS - 1;
	begin
		idx := (y / 2) * CHUNK_W + (x / 2);
		return to_unsigned(idx, CHUNK_ADDR_W);
	end function;

	function px_is_chunk_dirt(cd : chunk_dirt_t; x, y : integer) return boolean is
		variable idx : integer range 0 to NUM_CHUNKS - 1;
	begin
		if x < 0 or x >= PF_W or y < 0 or y >= PF_H then
			return false;
		end if;
		idx := (y / 2) * CHUNK_W + (x / 2);
		return cd(idx) = '1';
	end function;

	function dir_dx(d : integer) return integer is
	begin
		if d = 1 then return 1;
		elsif d = 3 then return -1;
		else return 0;
		end if;
	end function;

	function dir_dy(d : integer) return integer is
	begin
		if d = 2 then return 1;
		elsif d = 0 then return -1;
		else return 0;
		end if;
	end function;

	function opposite(d : integer) return integer is
	begin
		return (d + 2) mod 4;
	end function;

	function cell_open(st : game_state_t; c, r : integer) return boolean is
	begin
		if c < 0 or c >= COLS or r < ROW_SURF or r > ROW_DIRT1 then
			return false;
		end if;
		return st.dirt(r * COLS + c) = '0';
	end function;

	function rock_in_cell(st : game_state_t; c, r : integer) return boolean is
	begin
		if c < 0 or c >= COLS or r < 0 or r >= ROWS then
			return false;
		end if;
		for j in 0 to NUM_ROCKS - 1 loop
			if (st.rstate(j) = 0 or st.rstate(j) = 1) and
			   st.rx(j) / TILE = c and st.ry(j) / TILE = r then
				return true;
			end if;
		end loop;
		return false;
	end function;

	function enemy_cell_ok(st : game_state_t; c, r : integer; ghost : boolean) return boolean is
	begin
		if c < 0 or c >= COLS then
			return false;
		end if;
		if ghost then
			if r < ROW_SURF or r > ROW_DIRT1 then return false; end if;
		else
			if r < ROW_DIRT0 or r > ROW_DIRT1 then return false; end if;
		end if;
		if rock_in_cell(st, c, r) then
			return false;
		end if;
		if ghost then
			return true;
		end if;
		return st.dirt(r * COLS + c) = '0';
	end function;

	-- Checks 16x16 enemy footprint against thin walls (<= 4 px / <= 2 chunks) and rocks
	function enemy_span_ok(st : game_state_t; x, y : integer; ghost : boolean) return boolean is
		variable c0, r0 : integer range 0 to 17;
		variable c1, r1 : integer range 0 to 17;
		variable r_min  : integer range 0 to 17;
	begin
		if x < 0 or y < 0 or x + TILE > PF_W or y + TILE > PF_H then
			return false;
		end if;
		c0 := x / TILE;
		r0 := y / TILE;
		if (x + TILE - 1) >= (c0 + 1) * TILE then c1 := c0 + 1; else c1 := c0; end if;
		if (y + TILE - 1) >= (r0 + 1) * TILE then r1 := r0 + 1; else r1 := r0; end if;

		if ghost then r_min := ROW_SURF; else r_min := ROW_DIRT0; end if;
		if r0 < r_min or r1 > ROW_DIRT1 then
			return false;
		end if;

		if not ghost then
			if st.dirt(r0 * COLS + c0) = '1' or st.dirt(r0 * COLS + c1) = '1' or
			   st.dirt(r1 * COLS + c0) = '1' or st.dirt(r1 * COLS + c1) = '1' then
				return false;
			end if;
		end if;

		for j in 0 to NUM_ROCKS - 1 loop
			if (st.rstate(j) = 0 or st.rstate(j) = 1) and
			   (st.rx(j) / TILE = c0 or st.rx(j) / TILE = c1) and
			   (st.ry(j) / TILE = r0 or st.ry(j) / TILE = r1) then
				return false;
			end if;
		end loop;

		return true;
	end function;

	function player_cell_ok(st : game_state_t; c, r : integer) return boolean is
	begin
		if c < 0 or c >= COLS or r < ROW_SURF or r > ROW_DIRT1 then
			return false;
		end if;
		return not rock_in_cell(st, c, r);
	end function;

	function hose_cell_ok(st : game_state_t; c, r : integer) return boolean is
	begin
		return player_cell_ok(st, c, r) and cell_open(st, c, r);
	end function;

	function in_dirt(st : game_state_t; x, y : integer) return boolean is
		variable c, r : integer;
	begin
		c := (x + 8) / TILE;
		r := (y + 8) / TILE;
		if c < 0 or c >= COLS or r < 0 or r >= ROWS then
			return false;
		end if;
		return st.dirt(r * COLS + c) = '1';
	end function;

	function alive_count(st : game_state_t) return integer is
		variable n : integer range 0 to NUM_ENEMIES := 0;
	begin
		for i in 0 to NUM_ENEMIES - 1 loop
			if st.ealive(i) = '1' then n := n + 1; end if;
		end loop;
		return n;
	end function;

	function cell_of(x : integer) return integer is
	begin
		if x < 0 then
			return -1;
		end if;
		return x / TILE;
	end function;

	function enemy_box(st : game_state_t; i : integer) return rect_t is
		variable r : rect_t;
	begin
		r.x0 := st.ex(i) + 3;  r.x1 := st.ex(i) + 12;
		r.y0 := st.ey(i) + 3;  r.y1 := st.ey(i) + 12;
		return r;
	end function;

	function overlap(ax, ay, bx, by : integer) return boolean is
	begin
		return abs(ax - bx) < HIT and abs(ay - by) < HIT;
	end function;

	function enemy_at(st : game_state_t; x, y : integer) return integer is
	begin
		for i in 0 to NUM_ENEMIES - 1 loop
			if st.ealive(i) = '1' and
			   x >= st.ex(i) and x < st.ex(i) + TILE and
			   y >= st.ey(i) and y < st.ey(i) + TILE and
			   not in_dirt(st, st.ex(i), st.ey(i)) then
				return i;
			end if;
		end loop;
		return -1;
	end function;

	function score_val(d : digits_t) return integer is
	begin
		return d(0) + 10 * d(1) + 100 * d(2) + 1000 * d(3) + 10000 * d(4) + 100000 * d(5);
	end function;

	function add_pts(d : digits_t; pts : integer) return digits_t is
		variable r     : digits_t := d;
		variable p     : integer range 0 to 16383 := pts;
		variable carry : integer range 0 to 2 := 0;
		variable t     : integer range 0 to 21;
		variable d0, d1, d2, d3, d4 : integer range 0 to 9;
	begin
		d4 := p / 10000;
		p  := p - d4 * 10000;
		d3 := p / 1000;
		p  := p - d3 * 1000;
		d2 := p / 100;
		p  := p - d2 * 100;
		d1 := p / 10;
		d0 := p - d1 * 10;

		t := r(0) + d0 + carry;
		if t >= 10 then r(0) := t - 10; carry := 1; else r(0) := t; carry := 0; end if;
		t := r(1) + d1 + carry;
		if t >= 10 then r(1) := t - 10; carry := 1; else r(1) := t; carry := 0; end if;
		t := r(2) + d2 + carry;
		if t >= 10 then r(2) := t - 10; carry := 1; else r(2) := t; carry := 0; end if;
		t := r(3) + d3 + carry;
		if t >= 10 then r(3) := t - 10; carry := 1; else r(3) := t; carry := 0; end if;
		t := r(4) + d4 + carry;
		if t >= 10 then r(4) := t - 10; carry := 1; else r(4) := t; carry := 0; end if;
		if carry = 1 then
			if r(5) < 9 then r(5) := r(5) + 1; else r(5) := 0; end if;
		end if;
		return r;
	end function;

	function layer_of_row(r : integer) return integer is
		variable l : integer;
	begin
		if r < ROW_DIRT0 then
			return 1;
		end if;
		l := (r - ROW_DIRT0) / 4 + 1;
		if l > 4 then l := 4; end if;
		return l;
	end function;

	function pump_pts(kind : integer; row : integer; side : boolean) return integer is
		variable p : integer;
	begin
		p := 100 * (layer_of_row(row) + 1);
		if kind = 1 and side then
			p := p * 2;
		end if;
		return p;
	end function;

	function rock_pts(n : integer) return integer is
	begin
		case n is
			when 0      => return 0;
			when 1      => return 1000;
			when 2      => return 2500;
			when 3      => return 4000;
			when 4      => return 6000;
			when 5      => return 8000;
			when 6      => return 10000;
			when others => return 12000;
		end case;
	end function;

	function veg_pts(rnd : integer) return integer is
	begin
		if    rnd <= 1  then return 400;
		elsif rnd = 2   then return 600;
		elsif rnd = 3   then return 800;
		elsif rnd <= 5  then return 1000;
		elsif rnd <= 7  then return 2000;
		elsif rnd <= 9  then return 3000;
		elsif rnd <= 11 then return 4000;
		elsif rnd <= 13 then return 5000;
		elsif rnd <= 15 then return 6000;
		elsif rnd <= 17 then return 7000;
		else                 return 8000;
		end if;
	end function;

	function veg_tier(rnd : integer) return integer is
	begin
		if    rnd <= 1  then return 0;
		elsif rnd = 2   then return 1;
		elsif rnd = 3   then return 2;
		elsif rnd <= 5  then return 3;
		elsif rnd <= 7  then return 4;
		elsif rnd <= 9  then return 5;
		elsif rnd <= 11 then return 6;
		elsif rnd <= 13 then return 7;
		elsif rnd <= 15 then return 8;
		elsif rnd <= 17 then return 9;
		else                 return 10;
		end if;
	end function;

	function ghost_delay(rnd : integer) return integer is
		variable d : integer;
	begin
		d := GHOST_WAIT - 30 * (rnd - 1);
		if d < 180 then d := 180; end if;
		return d;
	end function;

	function enemy_spd(rnd : integer; ghost : boolean) return integer is
		variable s : integer;
	begin
		s := 8 + (rnd - 1) / 2;
		if s > 14 then s := 14; end if;
		if ghost then s := s - 2; end if;
		return s;
	end function;

end package body;