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
		"0000044444000000",
		"0000444444400000",
		"0000444444400000",
		"0000444444444000",
		"0000099999900000",
		"0000099998900000",
		"0000099999900000",
		"0000333333777777",
		"0000333333777777",
		"0000333333000000",
		"0000333333000000",
		"0000333333000000",
		"0000066066000000",
		"0000066066000000",
		"0000666066600000",
		"0000000000000000"
	);
	constant D_PLAYER_U : spr_t := (
		"0000044774400000",
		"0000444774440000",
		"0000444774440000",
		"0000444774440000",
		"0000444774440000",
		"0000444774440000",
		"0000444774440000",
		"0000333773330000",
		"0000333333330000",
		"0000333333330000",
		"0000333333330000",
		"0000333333330000",
		"0000666006660000",
		"0000666006660000",
		"0000666006660000",
		"0000000000000000"
	);
	constant D_PLAYER_D : spr_t := (
		"0000044444400000",
		"0000444444440000",
		"0000444444440000",
		"0000444444440000",
		"0000099999900000",
		"0000098998900000",
		"0000099999900000",
		"0000333333330000",
		"0000333773330000",
		"0000333773330000",
		"0000333773330000",
		"0000333773330000",
		"0000666776660000",
		"0000666776660000",
		"0000666776660000",
		"0000000770000000"
	);
	constant D_WALKER : spr_t := (
		"0000000000000000",
		"0000000000000000",
		"0000000000000000",
		"0000022222200000",
		"0002222222222000",
		"0022222222222200",
		"0022111221112200",
		"0222181221812220",
		"0222111221112220",
		"0222222222222220",
		"0222222222222220",
		"0022288888822200",
		"0022222222222200",
		"0002222222222000",
		"0066662222666600",
		"0066660000666600"
	);
	constant D_BREATHER : spr_t := (
		"0000000000000000",
		"0000000000000000",
		"0004400000044000",
		"0000455555540000",
		"0005555555555000",
		"0055555555555500",
		"0055111551115500",
		"0555181551815550",
		"0555111551115550",
		"0555555555555550",
		"0555555555555550",
		"0055566666655500",
		"0055566666655500",
		"0005555555555000",
		"0044445555444400",
		"0044440000444400"
	);
	constant D_GHOST : spr_t := (
		"0000000000000000",
		"0000000000000000",
		"0000000000000000",
		"0000000000000000",
		"0000000000000000",
		"0011111001111100",
		"0011881001188100",
		"0011881001188100",
		"0011881001188100",
		"0011111001111100",
		"0000000000000000",
		"0000000000000000",
		"0000000000000000",
		"0000000000000000",
		"0000000000000000",
		"0000000000000000"
	);
	constant D_ROCK : spr_t := (
		"0000000000000000",
		"0000008888000000",
		"0000887777880000",
		"0088777777778800",
		"0081117777777800",
		"0871117777777780",
		"0877177777777780",
		"8777777777777778",
		"8777777777777778",
		"8777777777677778",
		"0877777776767780",
		"0877777767777780",
		"0087777677677800",
		"0088777777778800",
		"0000887777880000",
		"0000008888000000"
	);
	constant D_VEG : spr_t := (
		"0000000000000000",
		"0000055005500000",
		"0000055555500000",
		"0000000550000000",
		"0000044554400000",
		"0000444444440000",
		"0004411444444000",
		"0004411444444000",
		"0044444444444400",
		"0044444444444400",
		"0044444444444400",
		"0004444444444000",
		"0004444444444000",
		"0000444444440000",
		"0000044444400000",
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
