-- digger_pkg.vhd  --  SHARED CONTRACT (whole team)
--
-- This file is the interface between the three people's code:
--   * Person C's game.vhd WRITES the game_state_t record every frame.
--   * Person B's renderer.vhd READS it to decide pixel colors.
--   * Person A's ai_pkg.vhd READS it to decide where an enemy moves next.
--
-- RULE: do NOT change the record, types or constants below without telling the whole
-- team first. A one-line change here can break everyone else's files.
-- Everything in this file is already finished; nobody has a TODO here.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package digger_pkg is
	constant COLS : integer := 20;   -- the playfield is 20 x 15 cells
	constant ROWS : integer := 15;   -- row 0 = sky / HUD strip, rows 1..14 = dirt area
	                                 -- each cell is 32x32 screen pixels (an 8x8 sprite, 4x zoom)

	-- Sprite kinds (used by sprite_pkg.sprite_px and the renderer)
	constant K_PLAYER : integer := 0;
	constant K_BLOB   : integer := 1;   -- normal enemy
	constant K_MID    : integer := 2;   -- enemy, inflated once
	constant K_BIG    : integer := 3;   -- enemy, inflated twice or more
	constant K_GHOST  : integer := 4;   -- enemy tunnelling through dirt (eyes only)
	constant K_ROCK   : integer := 5;
	constant K_HARP_H : integer := 6;   -- pump line, horizontal piece
	constant K_HARP_V : integer := 7;   -- pump line, vertical piece
	constant K_DIRT   : integer := 8;

	type ex_arr is array (0 to 2) of integer range 0 to 19;   -- 3 enemies
	type ey_arr is array (0 to 2) of integer range 0 to 14;
	type ei_arr is array (0 to 2) of integer range 0 to 4;
	type eg_arr is array (0 to 2) of integer range 0 to 63;
	type ec_arr is array (0 to 2) of integer range 0 to 255;
	type rx_arr is array (0 to 1) of integer range 0 to 19;   -- 2 rocks
	type ry_arr is array (0 to 1) of integer range 0 to 14;
	type rs_arr is array (0 to 1) of integer range 0 to 2;
	type rc_arr is array (0 to 1) of integer range 0 to 255;

	-- ===================== THE GAME STATE (the contract) =====================
	type game_state_t is record
		dirt   : std_logic_vector(0 to ROWS*COLS-1);
		         -- '1' = dirt, '0' = open. Index = row*COLS + col. Row 0 is always '0'.
		gstate : integer range 0 to 3;
		         -- 0 = playing, 1 = just died (short pause), 2 = game over, 3 = win
		gtimer : integer range 0 to 127;   -- countdown used in the "just died" pause
		lives  : integer range 0 to 3;     -- lives remaining (HUD shows this many icons)
		px     : integer range 0 to 19;    -- player cell
		py     : integer range 0 to 14;    -- (playable rows are 1..14)
		pdir   : integer range 0 to 3;     -- facing: 0 up, 1 right, 2 down, 3 left
		pcnt   : integer range 0 to 31;    -- player move timer (frames since last step)
		pcool  : integer range 0 to 31;    -- pump timer (frames since last inflation step)
		hlen   : integer range 0 to 3;     -- pump line length in cells; 0 = pump line not shown
		ex     : ex_arr;                   -- enemy cell x
		ey     : ey_arr;                   -- enemy cell y
		einfl  : ei_arr;                   -- enemy inflation 0..3 (reaching 4 = popped)
		eghost : eg_arr;                   -- ghost-mode moves left (0 = not a ghost)
		ecnt   : ec_arr;                   -- enemy move / deflate timer
		ealive : std_logic_vector(0 to 2); -- '1' = enemy exists
		rx     : rx_arr;                   -- rock cell x
		ry     : ry_arr;                   -- rock cell y
		rstate : rs_arr;                   -- 0 = still, 1 = wobbling, 2 = falling
		rtimer : rc_arr;                   -- rock timer
		lfsr   : std_logic_vector(15 downto 0);   -- random bits (never let this become all zeros!)
	end record;

	-- Where things start (used by level_pkg and by game.vhd when respawning)
	constant EX0 : ex_arr := (3, 16, 10);
	constant EY0 : ey_arr := (6, 8, 12);
	constant PLAYER_X0 : integer := 10;
	constant PLAYER_Y0 : integer := 1;

	-- Direction helpers: direction code -> step in x / y (up = row-1, down = row+1)
	function dir_dx(d : integer) return integer;
	function dir_dy(d : integer) return integer;

	-- Cell-test helpers shared by game.vhd and ai_pkg.vhd.
	-- in_bounds : inside the playfield (columns 0..19, rows 1..14)
	-- has_rock  : a rock currently occupies this cell
	-- enemy_ok  : an enemy / the pump line / a falling rock may occupy this cell
	--             (in bounds, no rock, and dirt = '0' unless ghost = true)
	-- player_ok : the player may step here (in bounds, no rock; dirt is fine, he digs it)
	function in_bounds(x, y : integer) return boolean;
	function has_rock(st : game_state_t; x, y : integer) return boolean;
	function enemy_ok(st : game_state_t; x, y : integer; ghost : boolean) return boolean;
	function player_ok(st : game_state_t; x, y : integer) return boolean;
end package;

package body digger_pkg is

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

	function in_bounds(x, y : integer) return boolean is
	begin
		return (x >= 0 and x < COLS and y >= 1 and y < ROWS);
	end function;

	function has_rock(st : game_state_t; x, y : integer) return boolean is
	begin
		for j in 0 to 1 loop
			if st.rx(j) = x and st.ry(j) = y then
				return true;
			end if;
		end loop;
		return false;
	end function;

	function enemy_ok(st : game_state_t; x, y : integer; ghost : boolean) return boolean is
	begin
		if not in_bounds(x, y) then
			return false;
		end if;
		if has_rock(st, x, y) then
			return false;
		end if;
		if ghost then
			return true;
		end if;
		return st.dirt(y*COLS + x) = '0';
	end function;

	function player_ok(st : game_state_t; x, y : integer) return boolean is
	begin
		return in_bounds(x, y) and not has_rock(st, x, y);
	end function;

end package body;
