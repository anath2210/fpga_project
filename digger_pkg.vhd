-- digger_pkg.vhd  --  SHARED CONTRACT (the whole team)
--
-- This file is the interface between everyone's code:
--   * game.vhd (C) and world_pkg.vhd (A) WRITE the game_state_t record every frame.
--   * renderer.vhd (B) READS it to decide pixel colors.
--   * ai_pkg.vhd (A) READS it to decide where an enemy goes next.
-- RULE: do NOT change the record, types, constants or helper functions below without telling
-- the whole team. One changed line here can break everybody else's files.
--
-- PLAYFIELD (one cell = 16 x 16 pixels, drawn 1:1, centered on the 640x480 screen)
--      row  0      score and high score
--      row  1      surface (sky / open air, the player can walk on it)
--      rows 2-5    dirt layer 1   (200 pts per pump kill)
--      rows 6-9    dirt layer 2   (300)
--      rows 10-13  dirt layer 3   (400)
--      rows 14-16  dirt layer 4   (500)   -- the deepest layer is only 3 rows deep
--      row 17      lives left and round number
--  14 columns x 18 rows = 224 x 288 pixels.
--
-- POSITIONS: the player, enemies and rocks have PIXEL positions (top-left corner of their
-- 16x16 box, measured inside the playfield). Dirt is stored per 16x16 cell.
-- GRID-LOCKED TURNING: something may only turn (change axis) when BOTH x and y are multiples
-- of 16, i.e. exactly on a cell. Reversing direction is allowed any time.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package digger_pkg is

	-- ===================== geometry =====================
	constant TILE      : integer := 16;
	constant COLS      : integer := 14;
	constant ROWS      : integer := 18;
	constant PF_W      : integer := COLS * TILE;   -- 224
	constant PF_H      : integer := ROWS * TILE;   -- 288
	constant PF_X0     : integer := 208;           -- left edge of the playfield on the screen
	constant PF_Y0     : integer := 96;            -- top edge of the playfield on the screen
	constant ROW_SURF  : integer := 1;             -- surface row
	constant ROW_DIRT0 : integer := 2;             -- first dirt row
	constant ROW_DIRT1 : integer := 16;            -- last dirt row
	constant ROW_HUD1  : integer := 17;            -- bottom HUD row

	constant NUM_ENEMIES : integer := 4;
	constant NUM_ROCKS   : integer := 3;
	constant MAX_LIVES   : integer := 5;
	constant START_LIVES : integer := 3;

	-- ===================== tuning (all in one place) =====================
	-- Time is measured in frames (1 frame = 1/60 s). Speeds are in 1/16 pixel per frame
	-- (16 = one pixel every frame = 60 pixels per second).
	constant PSPD           : integer := 12;   -- player speed
	constant HOSE_MAX       : integer := 40;   -- pump hose length in pixels
	constant HOSE_STEP      : integer := 4;    -- hose grows this many pixels per frame
	constant PUMP_FRAMES    : integer := 14;   -- frames between inflation steps while pumping
	constant DEFLATE_FRAMES : integer := 40;   -- frames for an inflated enemy to shrink one stage
	constant WOBBLE_FRAMES  : integer := 40;   -- rock wobble before it falls
	constant FALL_STEP      : integer := 2;    -- rock falls this many pixels per frame
	constant READY_FRAMES   : integer := 90;   -- frozen "get ready" time at the start of a round
	constant DEAD_FRAMES    : integer := 90;   -- pause after the player dies
	constant CLEAR_FRAMES   : integer := 120;  -- pause after a round is cleared
	constant BREATH_FRAMES  : integer := 60;   -- fire-breather: total breath time (wind-up + fire)
	constant FIRE_FRAMES    : integer := 30;   -- ... of which the last 30 frames are real flame
	constant FIRE_LEN       : integer := 40;   -- flame length in pixels
	constant GHOST_FRAMES   : integer := 100;  -- how long an enemy tunnels through dirt (minimum)
	constant GHOST_WAIT     : integer := 600;  -- frames a normal enemy must walk before it may ghost (round 1; see ghost_delay()); shorter later
	constant VEG_FRAMES     : integer := 600;  -- the vegetable stays 10 seconds
	constant VEG_COL        : integer := 6;    -- where the vegetable appears (cell)
	constant VEG_ROW        : integer := 9;
	constant HIT            : integer := 12;   -- two 16x16 boxes "touch" if closer than this (px)

	-- ===================== types =====================
	subtype digit_t is integer range 0 to 9;
	type digits_t is array (0 to 5) of digit_t;      -- index 0 = least significant digit
	subtype xpos_t is integer range 0 to PF_W - 1;
	subtype ypos_t is integer range 0 to PF_H - 1;

	type ex_arr    is array (0 to NUM_ENEMIES - 1) of xpos_t;
	type ey_arr    is array (0 to NUM_ENEMIES - 1) of ypos_t;
	type edir_arr  is array (0 to NUM_ENEMIES - 1) of integer range 0 to 3;
	type eacc_arr  is array (0 to NUM_ENEMIES - 1) of integer range 0 to 31;
	type einfl_arr is array (0 to NUM_ENEMIES - 1) of integer range 0 to 3;
	type etmr_arr  is array (0 to NUM_ENEMIES - 1) of integer range 0 to 255;
	type eage_arr  is array (0 to NUM_ENEMIES - 1) of integer range 0 to 1023;
	type ebr_arr   is array (0 to NUM_ENEMIES - 1) of integer range 0 to 127;
	type ekind_arr is array (0 to NUM_ENEMIES - 1) of integer range 0 to 1;
	type rx_arr    is array (0 to NUM_ROCKS - 1) of xpos_t;
	type ry_arr    is array (0 to NUM_ROCKS - 1) of ypos_t;
	type rst_arr   is array (0 to NUM_ROCKS - 1) of integer range 0 to 3;
	type rtm_arr   is array (0 to NUM_ROCKS - 1) of integer range 0 to 255;
	type rk_arr    is array (0 to NUM_ROCKS - 1) of integer range 0 to 7;

	-- ===================== THE GAME STATE =====================
	type game_state_t is record
		-- map
		dirt    : std_logic_vector(0 to ROWS * COLS - 1);
		          -- '1' = dirt, '0' = open. Index = row*COLS + col. Rows 0, 1 and 17 are always '0'.
		-- game flow
		gstate  : integer range 0 to 4;
		          -- 0 = playing, 1 = player just died, 2 = game over, 3 = round cleared, 4 = get ready
		gtimer  : integer range 0 to 255;      -- countdown used by states 1, 3 and 4
		rnd     : integer range 1 to 256;      -- round number
		lives   : integer range 0 to MAX_LIVES;
		score   : digits_t;                    -- 6 digits, wraps 999,990 -> 0
		hiscore : digits_t;
		bonus   : std_logic_vector(0 to 1);    -- extra-life awards already given (20,000 and 60,000)
		-- player
		px      : xpos_t;                      -- pixel position of the top-left corner
		py      : ypos_t;
		pdir    : integer range 0 to 3;        -- facing: 0 up, 1 right, 2 down, 3 left
		pacc    : integer range 0 to 31;       -- speed accumulator
		hlen    : integer range 0 to HOSE_MAX; -- pump hose length in pixels (0 = not pumping)
		pcool   : integer range 0 to 31;       -- frames since the last inflation step
		pump_hit: integer range -1 to NUM_ENEMIES - 1;   -- enemy the hose is touching (-1 = none)
		-- enemies (kind 0 = walker, kind 1 = fire-breather)
		ex      : ex_arr;
		ey      : ey_arr;
		edir    : edir_arr;                    -- direction it faces / is moving
		eacc    : eacc_arr;                    -- speed accumulator
		einfl   : einfl_arr;                   -- inflation stage 0..3 (a 4th pump pops it)
		eghost  : etmr_arr;                    -- frames of ghost mode left (0 = not a ghost)
		ecnt    : etmr_arr;                    -- deflate timer
		eage    : eage_arr;                    -- frames walked as a normal enemy (ghosting is only allowed after GHOST_WAIT)
		ebreath : ebr_arr;                     -- fire-breather timer: >FIRE_FRAMES wind-up, 1..FIRE_FRAMES flame
		ealive  : std_logic_vector(0 to NUM_ENEMIES - 1);
		ekind   : ekind_arr;
		-- rocks
		rx      : rx_arr;
		ry      : ry_arr;
		rstate  : rst_arr;                     -- 0 = still, 1 = wobbling, 2 = falling, 3 = broken (gone)
		rtimer  : rtm_arr;
		rk      : rk_arr;                      -- enemies crushed by this rock during its fall
		rdrops  : integer range 0 to NUM_ROCKS;   -- rocks dropped this round
		-- vegetable
		vstate  : integer range 0 to 1;        -- 1 = on screen
		vtimer  : integer range 0 to 1023;
		vdone   : std_logic;                   -- already shown this round
		-- bookkeeping used while one frame of game logic is computed (game.vhd)
		gain    : integer range 0 to 65535;    -- points earned this frame
		dead    : std_logic;                   -- the player died this frame
		lfsr    : std_logic_vector(15 downto 0);   -- random bits (must never be all zeros)
	end record;

	-- ===================== start positions =====================
	constant PX0 : integer := 96;              -- player start: cell (6, 2)
	constant PY0 : integer := 32;
	constant EX0    : ex_arr    := (32, 176, 48, 160);
	constant EY0    : ey_arr    := (80, 96, 176, 208);
	constant EKIND0 : ekind_arr := (0, 1, 0, 1);
	constant RX0    : rx_arr    := (112, 64, 160);
	constant RY0    : ry_arr    := (64, 144, 160);

	-- ===================== rectangles =====================
	type rect_t is record
		x0, y0, x1, y1 : integer;              -- inclusive corners; empty if x1 < x0 or y1 < y0
	end record;
	function in_rect(r : rect_t; x, y : integer) return boolean;
	function rects_overlap(a, b : rect_t) return boolean;
	function player_box(st : game_state_t) return rect_t;      -- the player's hit box
	function hose_rect(st : game_state_t) return rect_t;       -- the pump hose (empty if hlen = 0)
	function fire_active(st : game_state_t; i : integer) return boolean;
	function flame_rect(st : game_state_t; i : integer) return rect_t;
	function hose_tip_x(st : game_state_t) return integer;     -- pixel just beyond the hose end
	function hose_tip_y(st : game_state_t) return integer;

	-- ===================== map helpers =====================
	function dir_dx(d : integer) return integer;
	function dir_dy(d : integer) return integer;
	function opposite(d : integer) return integer;
	-- dirt = '0' and inside rows 1..16
	function cell_open(st : game_state_t; c, r : integer) return boolean;
	-- a rock that is not falling (still or wobbling) sits in this cell
	function rock_in_cell(st : game_state_t; c, r : integer) return boolean;
	-- may an enemy stand in this cell?  ghost = true ignores dirt and may use the surface row
	function enemy_cell_ok(st : game_state_t; c, r : integer; ghost : boolean) return boolean;
	-- may the player enter this cell? (dirt is fine, he digs it) -- not rocks, not outside rows 1..16
	function player_cell_ok(st : game_state_t; c, r : integer) return boolean;
	-- may the pump hose pass through this cell? (open tunnel, no rock)
	function hose_cell_ok(st : game_state_t; c, r : integer) return boolean;
	-- is the centre of the box at pixel (x, y) inside a dirt cell?
	function in_dirt(st : game_state_t; x, y : integer) return boolean;
	function alive_count(st : game_state_t) return integer;
	-- cell number of a pixel coordinate (floor division, so -1 .. -16 is cell -1)
	function cell_of(x : integer) return integer;
	function enemy_box(st : game_state_t; i : integer) return rect_t;   -- enemy hit box
	-- boxes at (ax, ay) and (bx, by) touch (closer than HIT pixels on both axes)
	function overlap(ax, ay, bx, by : integer) return boolean;
	-- index of a live enemy standing in open tunnel whose box contains pixel (x, y), or -1
	function enemy_at(st : game_state_t; x, y : integer) return integer;

	-- ===================== scoring helpers =====================
	function score_val(d : digits_t) return integer;                   -- digits -> number
	function add_pts(d : digits_t; pts : integer) return digits_t;     -- decimal add, wraps after 999,990
	function layer_of_row(r : integer) return integer;                 -- dirt layer 1..4 of a row
	function pump_pts(kind : integer; row : integer; side : boolean) return integer;
	function rock_pts(n : integer) return integer;                     -- n enemies crushed by one rock
	function veg_pts(rnd : integer) return integer;
	function veg_tier(rnd : integer) return integer;                   -- 0..10, picks the vegetable look
	function ghost_delay(rnd : integer) return integer;                -- walking time before an enemy may ghost
	function enemy_spd(rnd : integer; ghost : boolean) return integer; -- speed in 1/16 px per frame

end package;

package body digger_pkg is

	-- ---------------------------------------------------------------- rectangles
	function in_rect(r : rect_t; x, y : integer) return boolean is
	begin
		return x >= r.x0 and x <= r.x1 and y >= r.y0 and y <= r.y1;
	end function;

	function rects_overlap(a, b : rect_t) return boolean is
	begin
		return a.x0 <= b.x1 and b.x0 <= a.x1 and a.y0 <= b.y1 and b.y0 <= a.y1 and
		       a.x1 >= a.x0 and a.y1 >= a.y0 and b.x1 >= b.x0 and b.y1 >= b.y0;
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

	function flame_rect(st : game_state_t; i : integer) return rect_t is
		variable r : rect_t;
	begin
		r.x0 := 1; r.x1 := 0; r.y0 := 1; r.y1 := 0;          -- empty
		if fire_active(st, i) then
			case st.edir(i) is
				when 1 =>
					r.x0 := st.ex(i) + TILE;        r.x1 := st.ex(i) + TILE + FIRE_LEN - 1;
					r.y0 := st.ey(i) + 4;           r.y1 := st.ey(i) + 11;
				when 3 =>
					r.x1 := st.ex(i) - 1;           r.x0 := st.ex(i) - FIRE_LEN;
					r.y0 := st.ey(i) + 4;           r.y1 := st.ey(i) + 11;
				when 0 =>
					r.y1 := st.ey(i) - 1;           r.y0 := st.ey(i) - FIRE_LEN;
					r.x0 := st.ex(i) + 4;           r.x1 := st.ex(i) + 11;
				when others =>
					r.y0 := st.ey(i) + TILE;        r.y1 := st.ey(i) + TILE + FIRE_LEN - 1;
					r.x0 := st.ex(i) + 4;           r.x1 := st.ex(i) + 11;
			end case;
		end if;
		return r;
	end function;

	-- ---------------------------------------------------------------- map helpers
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
		variable n : integer := 0;
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

	-- ---------------------------------------------------------------- scoring helpers
	function score_val(d : digits_t) return integer is
	begin
		return d(0) + 10 * d(1) + 100 * d(2) + 1000 * d(3) + 10000 * d(4) + 100000 * d(5);
	end function;

	function add_pts(d : digits_t; pts : integer) return digits_t is
		variable r     : digits_t := d;
		variable p     : integer  := pts;
		variable carry : integer  := 0;
		variable t     : integer;
	begin
		for i in 0 to 5 loop
			t := r(i) + (p mod 10) + carry;
			p := p / 10;
			if t >= 10 then
				r(i) := t - 10;
				carry := 1;
			else
				r(i) := t;
				carry := 0;
			end if;
		end loop;
		return r;                       -- a carry out of the top digit is dropped: 999,990 + 10 = 0
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

	-- walker: 200/300/400/500 by layer. Fire-breather: same from above/below, double from the side.
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
		d := GHOST_WAIT - 30 * (rnd - 1);       -- later rounds ghost sooner, never below 3 seconds
		if d < 180 then d := 180; end if;
		return d;
	end function;

	function enemy_spd(rnd : integer; ghost : boolean) return integer is
		variable s : integer;
	begin
		s := 8 + (rnd - 1) / 2;          -- later rounds are faster
		if s > 14 then s := 14; end if;
		if ghost then s := s - 2; end if;
		return s;
	end function;

end package body;