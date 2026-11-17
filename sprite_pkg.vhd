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
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.digger_pkg.all;

package sprite_pkg is
	function rgb6(r, g, b : integer) return std_logic_vector;
	function sprite_px(kind, sx, sy : integer) return std_logic_vector;
end package;

package body sprite_pkg is

	-- 2 bits per channel -> 6-bit color {R1 R0 G1 G0 B1 B0}   (DONE)
	function rgb6(r, g, b : integer) return std_logic_vector is
	begin
		return std_logic_vector(to_unsigned(r, 2)) &
		       std_logic_vector(to_unsigned(g, 2)) &
		       std_logic_vector(to_unsigned(b, 2));
	end function;

	type sprite_t is array (0 to 7) of string(1 to 8);

	-- Worked example (DONE): the dirt tile. '1' = brown, '2' = darker speckles.
	constant S_DIRT : sprite_t := (
		"11111111",
		"11211111",
		"11111121",
		"11111111",
		"12111111",
		"11111211",
		"11121111",
		"11111111");

	-- TODO(B): constant S_PLAYER : sprite_t := ( 8 strings of 8 characters );
	-- TODO(B): constant S_BLOB, S_MID, S_BIG, S_GHOST, S_ROCK, S_HARP_H, S_HARP_V ...
	
	-- 1 = white, 2 = blue, 3 = red
	constant S_PLAYER : sprite_t := ( 
		"00111100",
		"01122110",
		"21222200",
		"21222233",
		"21122333",
		"21111100",
		"01000100",
		"02200220");

	-- 1 = red, 2 = black
	constant S_BLOB : sprite_t := ( 
		"00000000",
		"00111100",
		"01111110",
		"01211210",
		"01111110",
		"01111110",
		"00111100",
		"00000000");

	-- 1 = red, 2 = black
	constant S_MID : sprite_t := ( 
		"00111100",
		"01111110",
		"11211211",
		"11211211",
		"11111111",
		"11111111",
		"01111110",
		"00111100");

	-- 1 = red, 2 = black
	constant S_BIG : sprite_t := ( 
		"11111111",
		"11111111",
		"12211221",
		"12211221",
		"11111111",
		"11111111",
		"11111111",
		"11111111");

	-- 1 = white, 2 = black
	constant S_GHOST : sprite_t := ( 
		"00000000",
		"00000000",
		"01100110",
		"01200210",
		"00000000",
		"00000000",
		"00000000",
		"00000000");

	-- 1 = light gray, 2 = slate blue, 3 = dark gray
	constant S_ROCK : sprite_t := ( 
		"00111100",
		"01311110",
		"22113321",
		"21121111",
		"11111121",
		"12111221",
		"13111131",
		"01122110");

	-- 1 = light gray, 2 = dark gray
	constant S_HARP_H : sprite_t := ( 
		"00000000",
		"00000000",
		"00000000",
		"12112112",
		"21121121",
		"00000000",
		"00000000",
		"00000000");

	-- 1 = light gray, 2 = dark gray
	constant S_HARP_V : sprite_t := ( 
		"00021000",
		"00012000",
		"00011000",
		"00021000",
		"00012000",
		"00011000",
		"00021000",
		"00012000");

	-- Returns {opaque, R1 R0 G1 G0 B1 B0} for pixel (sx, sy) of sprite 'kind'
	function sprite_px(kind, sx, sy : integer) return std_logic_vector is
		variable ch  : character := '0';
		variable c   : integer;
		variable res : std_logic_vector(6 downto 0) := "0000000";
	begin
		-- Step 1: pick the character for this pixel.
		-- S_DIRT(sy)(sx + 1) means: row sy of the sprite, character number sx+1 (strings start at 1).
		-- TODO(B): turn this into a  case kind is ... when K_PLAYER => ch := S_PLAYER(sy)(sx+1); ...
		case kind is
			when K_DIRT =>
				ch := S_DIRT(sy)(sx + 1);
			when K_PLAYER =>
				ch := S_PLAYER(sy)(sx + 1);
			when K_BLOB =>
				ch := S_BLOB(sy)(sx + 1);
			when K_MID =>
				ch := S_MID(sy)(sx + 1);
			when K_BIG =>
				ch := S_BIG(sy)(sx + 1);
			when K_GHOST =>
				ch := S_GHOST(sy)(sx + 1);
			when K_ROCK =>
				ch := S_ROCK(sy)(sx + 1);
			when K_HARP_H =>
				ch := S_HARP_H(sy)(sx + 1);
			when K_HARP_V =>
				ch := S_HARP_V(sy)(sx + 1);
			when others =>
				ch := '0';
		end case;

		-- Step 2: character -> number 0..3
		c := character'pos(ch) - character'pos('0');

		-- Step 3: number -> color. 0 = transparent (res stays "0000000").
		if c /= 0 then
			res(6) := '1';   -- opaque
			-- TODO(B): make this a  case kind is ...  with a palette per sprite kind.
			-- Only the dirt palette exists so far:
			case kind is 
				when K_DIRT =>
					if c = 1 then
						res(5 downto 0) := rgb6(2, 1, 0);   -- brown
					else
						res(5 downto 0) := rgb6(1, 0, 0);   -- dark brown
					end if;
				when K_PLAYER =>
					case c is
						when 1 =>
							res(5 downto 0) := rgb6(3, 3, 3); -- white
						when 2 =>
							res(5 downto 0) := rgb6(0, 2, 3); -- light blue
						when 3 =>
							res(5 downto 0) := rgb6(3, 0, 0); -- red
						when others =>
							null;
					end case;
				when K_BLOB | K_MID | K_BIG =>
					case c is
						when 1 =>
							res(5 downto 0) := rgb6(3, 0, 0); -- red
						when 2 =>
							res(5 downto 0) := rgb6(0, 0, 0); -- black
						when others =>
							null;
					end case;
				when K_GHOST =>
					case c is
						when 1 =>
							res(5 downto 0) := rgb6(3, 3, 3); -- white
						when 2 =>
							res(5 downto 0) := rgb6(0, 0, 0); -- black
						when others =>
							null;
					end case;
				when K_ROCK =>
					case c is
						when 1 =>
							res(5 downto 0) := rgb6(2, 2, 2); -- light gray
						when 2 =>
							res(5 downto 0) := rgb6(1, 1, 2); -- slate blue
						when 3 =>
							res(5 downto 0) := rgb6(1, 1, 1); -- dark gray
						when others =>
							null;
					end case;
				when K_HARP_H | K_HARP_V =>
					case c is
						when 1 =>
							res(5 downto 0) := rgb6(2, 2, 2); -- light gray
						when 2 =>
							res(5 downto 0) := rgb6(1, 1, 1); -- dark gray
						when others =>
							null;
					end case;
				when others => 
					null;
			end case;
		end if;
		return res;
	end function;

end package body;
