-- sprite_pkg.vhd  --  OWNER: Person B (Graphics & Level)
--
-- GOAL: the artwork. Every sprite is 8x8 pixels, stored as 8 text strings of 8 characters.
-- Each character is a palette index:
--     '0' = transparent (the background shows through)
--     '1','2','3' = three colors that YOU choose per sprite kind (see the palette section)
-- The renderer shows each sprite pixel as a 4x4 block, so an 8x8 sprite fills one 32x32 cell.
--
-- sprite_px(kind, sx, sy) returns 7 bits:  bit 6 = opaque?   bits 5..0 = color (R1 R0 G1 G0 B1 B0)
--
-- DONE FOR YOU: rgb6() and the dirt tile (S_DIRT) as a worked example, so you can see
-- brown dirt as soon as the video works.
--
-- TODO(B): design ORIGINAL art for the rest (this is your game's look; make it yours):
--   K_PLAYER  your digger. It is mirrored automatically when facing left, so design it
--             facing RIGHT. Idea: helmet, face, body in 3 colors.
--   K_BLOB    normal enemy (e.g. a round creature with eyes)
--   K_MID     the enemy slightly inflated (bigger)
--   K_BIG     the enemy very inflated (fills the whole 8x8)
--   K_GHOST   enemy moving through dirt: just a pair of eyes on a transparent background
--   K_ROCK    a boulder
--   K_HARP_H  pump line, horizontal piece (e.g. a 2-pixel-thick line across the middle rows)
--   K_HARP_V  pump line, vertical piece
-- For each: (a) declare a constant S_xxx : sprite_t, (b) add it to the first case in
-- sprite_px, (c) add its palette to the second case (which RGB for '1', '2', '3').
--
-- Colors: rgb6(r, g, b) with each channel 0..3, e.g. rgb6(3,0,0) = bright red,
-- rgb6(3,3,0) = yellow, rgb6(0,0,0) = black, rgb6(3,3,3) = white.
-- TIP: copy the sprite strings into a text editor with a grid, or draw on graph paper first.
-- sprite_pkg.vhd  --  GENERATED: 16x16 sprites (palette indices) and the 8x8 text font
-- Sprite pixel characters:  0 = transparent  1 white  2 red  3 blue  4 yellow  5 green
--                           6 orange  7 gray  8 black  9 skin
library IEEE;
use IEEE.std_logic_1164.all;

package sprite_pkg is
	type spr_t is array (0 to 15) of string(1 to 16);
	constant SPR_PLAYER_R : integer := 0;
	constant SPR_PLAYER_U : integer := 1;
	constant SPR_PLAYER_D : integer := 2;
	constant SPR_WALKER : integer := 3;
	constant SPR_BREATHER : integer := 4;
	constant SPR_GHOST : integer := 5;
	constant SPR_ROCK : integer := 6;
	constant SPR_VEG : integer := 7;
	function spr_px(kind, sx, sy : integer) return integer;      -- palette index 0..9 (0 = see-through)
	function pal(i : integer) return std_logic_vector;           -- palette index -> rrggbb (2 bits each)
	function veg_color(tier : integer) return std_logic_vector;   -- colour of the vegetable body
	constant CH_BLANK : integer := 21;                           -- char codes: 0-9 digits, 10 H, 11 I, 12 R, 13 G,
	                                                             --   14 A, 15 M, 16 E, 17 O, 18 V, 19 D, 20 Y, 21 blank
	function font_px(ch, fx, fy : integer) return boolean;       -- one pixel of an 8x8 glyph
end package;

package body sprite_pkg is
	constant D_PLAYER_R : spr_t := (
		"0000011111000000",
		"0000111111100000",
		"0001111111110000",
		"0001133333311000",
		"0001133833811000",
		"0001133333311000",
		"0000113333110000",
		"0000111111112222",
		"0000113311332222",
		"0000111111110000",
		"0000111331110000",
		"0000011111100000",
		"0000011001100000",
		"0000011001100000",
		"0000333003330000",
		"0000000000000000"
	);
	constant D_PLAYER_U : spr_t := (
		"0000000220000000",
		"0000000220000000",
		"0000011111100000",
		"0000111111110000",
		"0001111111111000",
		"0001111111111000",
		"0000111111110000",
		"0000113333110000",
		"0000113333110000",
		"0000113333110000",
		"0000111111110000",
		"0000011111100000",
		"0000011001100000",
		"0000011001100000",
		"0000333003330000",
		"0000000000000000"
	);
	constant D_PLAYER_D : spr_t := (
		"0000011111100000",
		"0000111111110000",
		"0001111111111000",
		"0001133333311000",
		"0001138338311000",
		"0001133333311000",
		"0000113333110000",
		"0000111111110000",
		"0000113333110000",
		"0000113333110000",
		"0000111111110000",
		"0000011111100000",
		"0000011001100000",
		"0000011001100000",
		"0000333003330000",
		"0000000220000000"
	);
	constant D_WALKER : spr_t := (
		"0000000000000000",
		"0000002222000000",
		"0000222222220000",
		"0002212222222000",
		"0022222222222200",
		"0022211221122200",
		"0222218228122220",
		"0222218228122220",
		"0222211221122220",
		"0222222222222220",
		"0222228888222220",
		"0022222222222200",
		"0002222222222000",
		"0000222222220000",
		"0004440000444000",
		"0044440000444400"
	);
	constant D_BREATHER : spr_t := (
		"0444888558884440",
		"0844511551154480",
		"0085518558155800",
		"0055555555555500",
		"0055558888555500",
		"0085581221855800",
		"0828582112858280",
		"8225558888555228",
		"2225555555555222",
		"2225558118555222",
		"2255551881555522",
		"2555558118555552",
		"0055551881555500",
		"0005555555555000",
		"0022222552222200",
		"0222220000222220"
	);
	constant D_GHOST : spr_t := (
		"0000000000000000",
		"0000000000000000",
		"0000000000000000",
		"0001111001111000",
		"0011111001111100",
		"0011881001881100",
		"0011881001881100",
		"0011881001881100",
		"0011111001111100",
		"0001111001111000",
		"0000000000000000",
		"0000000000000000",
		"0000000000000000",
		"0000000000000000",
		"0000000000000000",
		"0000000000000000"
	);
	constant D_ROCK : spr_t := (
		"0000088888800000",
		"0088771117778800",
		"0887711777777880",
		"8877117777777788",
		"8777777777777778",
		"8777788777777378",
		"8777778777777338",
		"8777777877777738",
		"8777777788777338",
		"8777777777877338",
		"0877777777773380",
		"0887777777733880",
		"0088777777338800",
		"0008887777788800",
		"0000088888888000",
		"0000000000000000"
	);
	constant D_VEG : spr_t := (
		"0000050000500000",
		"0000055005500000",
		"0000005555000000",
		"0000000550000000",
		"0000044554400000",
		"0000444444440000",
		"0004411444444000",
		"0004414444444000",
		"0044444444444400",
		"0044444444444400",
		"0044444444444400",
		"0004444444444000",
		"0004444444444000",
		"0000444444440000",
		"0000088888800000",
		"0000000000000000"
	);
	function spr_px(kind, sx, sy : integer) return integer is
		variable ch : character := '0';
	begin
		case kind is
			when 0 => ch := D_PLAYER_R(sy)(sx + 1);
			when 1 => ch := D_PLAYER_U(sy)(sx + 1);
			when 2 => ch := D_PLAYER_D(sy)(sx + 1);
			when 3 => ch := D_WALKER(sy)(sx + 1);
			when 4 => ch := D_BREATHER(sy)(sx + 1);
			when 5 => ch := D_GHOST(sy)(sx + 1);
			when 6 => ch := D_ROCK(sy)(sx + 1);
			when 7 => ch := D_VEG(sy)(sx + 1);
			when others => null;
		end case;
		return character'pos(ch) - character'pos('0');
	end function;

	function pal(i : integer) return std_logic_vector is
	begin
		case i is
			when 0 => return "000000";
			when 1 => return "111111";
			when 2 => return "110000";
			when 3 => return "000111";
			when 4 => return "111100";
			when 5 => return "001100";
			when 6 => return "110100";
			when 7 => return "101010";
			when 8 => return "000000";
			when 9 => return "111001";
			when others => return "000000";
		end case;
	end function;

	function veg_color(tier : integer) return std_logic_vector is
	begin
		case tier is
			when 0 => return "110000";
			when 1 => return "110100";
			when 2 => return "111100";
			when 3 => return "001100";
			when 4 => return "001111";
			when 5 => return "000111";
			when 6 => return "110011";
			when 7 => return "111111";
			when 8 => return "101010";
			when 9 => return "111001";
			when 10 => return "110101";
			when others => return "111111";
		end case;
	end function;

	type glyph_t is array (0 to 7) of std_logic_vector(7 downto 0);
	type font_t is array (0 to 21) of glyph_t;
	constant FONT : font_t := (
		(x"3C", x"66", x"6E", x"76", x"66", x"66", x"3C", x"00"),  -- 0
		(x"18", x"38", x"18", x"18", x"18", x"18", x"7E", x"00"),  -- 1
		(x"3C", x"66", x"06", x"0C", x"18", x"30", x"7E", x"00"),  -- 2
		(x"3C", x"66", x"06", x"1C", x"06", x"66", x"3C", x"00"),  -- 3
		(x"0C", x"1C", x"3C", x"6C", x"7E", x"0C", x"0C", x"00"),  -- 4
		(x"7E", x"60", x"7C", x"06", x"06", x"66", x"3C", x"00"),  -- 5
		(x"3C", x"66", x"60", x"7C", x"66", x"66", x"3C", x"00"),  -- 6
		(x"7E", x"06", x"0C", x"18", x"30", x"30", x"30", x"00"),  -- 7
		(x"3C", x"66", x"66", x"3C", x"66", x"66", x"3C", x"00"),  -- 8
		(x"3C", x"66", x"66", x"3E", x"06", x"66", x"3C", x"00"),  -- 9
		(x"66", x"66", x"66", x"7E", x"66", x"66", x"66", x"00"),  -- H
		(x"3C", x"18", x"18", x"18", x"18", x"18", x"3C", x"00"),  -- I
		(x"7C", x"66", x"66", x"7C", x"6C", x"66", x"66", x"00"),  -- R
		(x"3C", x"66", x"60", x"6E", x"66", x"66", x"3C", x"00"),  -- G
		(x"18", x"3C", x"66", x"66", x"7E", x"66", x"66", x"00"),  -- A
		(x"63", x"77", x"7F", x"6B", x"63", x"63", x"63", x"00"),  -- M
		(x"7E", x"60", x"60", x"7C", x"60", x"60", x"7E", x"00"),  -- E
		(x"3C", x"66", x"66", x"66", x"66", x"66", x"3C", x"00"),  -- O
		(x"66", x"66", x"66", x"66", x"66", x"3C", x"18", x"00"),  -- V
		(x"78", x"6C", x"66", x"66", x"66", x"6C", x"78", x"00"),  -- D
		(x"66", x"66", x"3C", x"18", x"18", x"18", x"18", x"00"),  -- Y
		(others => x"00")   -- blank
	);
	function font_px(ch, fx, fy : integer) return boolean is
	begin
		if ch < 0 or ch > 21 then return false; end if;
		return FONT(ch)(fy)(7 - fx) = '1';
	end function;
end package body;