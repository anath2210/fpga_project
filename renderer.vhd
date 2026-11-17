-- renderer.vhd  --  OWNER: Person B (Graphics & Level)
--
-- GOAL: for every pixel the beam is on, decide what color it should be, using the game state.
-- This is called "racing the beam": there is no framebuffer; the color is worked out on the fly.
--
-- HOW IT WORKS (already set up for you below):
--   col, row = which 32x32 cell this pixel is in      (px / 32, py / 32)
--   sx, sy   = which pixel of the 8x8 sprite          (the lower bits, divided by 4)
--   You start with a background color, then paint LAYERS on top. A later layer overwrites
--   an earlier one wherever its sprite pixel is opaque (bit 6 of sprite_px = '1').
--
-- LAYER ORDER (bottom to top):
--   background -> pump line -> rocks -> enemies -> player -> HUD
--
-- DONE FOR YOU: the setup and the background layer (sky / dirt / tunnel).
--
-- TODO(B): add the remaining layers, in this order. Each is "if this pixel's cell matches
-- something in the game state, ask sprite_px for that sprite's pixel; if it is opaque,
-- use its color".
--   1. PUMP LINE (only if gs.hlen > 0). The pump line covers cells next to the player in the
--      direction gs.pdir. With dxx = col - gs.px and dyy = row - gs.py:
--        facing right (1): dyy = 0 and 1 <= dxx <= hlen      -> K_HARP_H
--        facing left  (3): dyy = 0 and -hlen <= dxx <= -1    -> K_HARP_H
--        facing up    (0): dxx = 0 and -hlen <= dyy <= -1    -> K_HARP_V
--        facing down  (2): dxx = 0 and 1 <= dyy <= hlen      -> K_HARP_V
--   2. ROCKS: loop j in 0 to 1. If col = gs.rx(j) and row = gs.ry(j): draw K_ROCK.
--      Extra: while gs.rstate(j) = 1 (wobbling), shift the sprite 1 pixel sideways every few
--      frames, e.g. when (gs.rtimer(j) mod 8) >= 4 use sxw := (sx + 1) mod 8.
--   3. ENEMIES: loop i in 0 to 2. If gs.ealive(i) = '1' and the cell matches (gs.ex(i), gs.ey(i)):
--        inflation >= 2 -> K_BIG;  inflation = 1 -> K_MID;
--        ghost (gs.eghost(i) > 0, or the enemy is inside a dirt cell) -> K_GHOST;
--        otherwise -> K_BLOB.
--   4. PLAYER: if col = gs.px and row = gs.py draw K_PLAYER. Mirror it when facing left
--      (gs.pdir = 3) by using sxw := 7 - sx. Extra: while gs.gstate = 1 (just died) make it
--      blink using a bit of gs.gtimer.
--   5. HUD (row 0 only): draw one K_PLAYER icon per remaining life at columns 0, 1, 2
--      (col < gs.lives), and one K_BLOB icon per live enemy at columns 19, 18, 17.
--   6. EXTRA: make the tunnel (open dirt) color depend on gs.gstate: game over = dark red,
--      win = dark green (already done in the background layer; try your own colors).
--
-- TIMING NOTE: the final color is stored in a register (rgb <= color), so it appears one
-- clock late. hs/vs are delayed by one clock too (hs_o, vs_o) so everything stays aligned.
-- Don't remove those. The color MUST be black ("000000") when 'active' = '0'.
--
-- How to test: set USE_DEMO_STATE := true in digger_top.vhd (uses demo_pkg's fake state).
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.digger_pkg.all;
use work.sprite_pkg.all;

entity renderer is
	port(
		clk    : in  std_logic;
		hs     : in  std_logic;
		vs     : in  std_logic;
		active : in  std_logic;
		px     : in  unsigned(9 downto 0);
		py     : in  unsigned(9 downto 0);
		gs     : in  game_state_t;
		rgb    : out std_logic_vector(5 downto 0);
		hs_o   : out std_logic;
		vs_o   : out std_logic
	);
end renderer;

architecture arch of renderer is
begin
	process(clk)
		variable col, row    : integer;
		variable sx, sy      : integer;
		variable sxw         : integer;                -- sx after mirroring / wobble
		variable dxx, dyy    : integer;
		variable kind        : integer;
		variable p           : std_logic_vector(6 downto 0);
		variable color       : std_logic_vector(5 downto 0);
		variable enemy_count : integer range 0 to 4;
	begin
		if rising_edge(clk) then
			hs_o <= hs;
			vs_o <= vs;

			if active = '0' then
				rgb <= "000000";                       -- black outside the visible area
			else
				col := to_integer(px(9 downto 5));     -- cell column = px / 32
				row := to_integer(py(8 downto 5));     -- cell row    = py / 32
				sx  := to_integer(px(4 downto 2));     -- pixel inside the 8x8 sprite
				sy  := to_integer(py(4 downto 2));

				-- ---------- background layer (DONE) ----------
				if row = 0 then
					color := rgb6(0, 2, 3);                          -- sky
				elsif gs.dirt(row*COLS + col) = '1' then
					p := sprite_px(K_DIRT, sx, sy);
					color := p(5 downto 0);                          -- dirt tile
				else
					case gs.gstate is
						when 2      => color := rgb6(1, 0, 0);       -- game over: dark red
						when 3      => color := rgb6(0, 1, 0);       -- win: dark green
						when others => color := rgb6(0, 0, 0);       -- tunnel: black
					end case;
				end if;

				-- TODO(B): pump line layer
				if gs.hlen > 0 then
					dxx := col - gs.px;
					dyy := row - gs.py;
					if gs.pdir = 1 then 
						if dyy = 0 and dxx >= 1 and dxx <= gs.hlen then
							p := sprite_px(K_HARP_H, sx, sy);
							if p(6) = '1' then
								color := p(5 downto 0);				 -- harpoon right
							end if;
						end if;
					elsif gs.pdir = 3 then 
						if dyy = 0 and dxx >= -gs.hlen and dxx <= -1 then
							p := sprite_px(K_HARP_H, sx, sy);
							if p(6) = '1' then
								color := p(5 downto 0);				 -- harpoon left
							end if;
						end if;
					elsif gs.pdir = 0 then
						if dxx = 0 and dyy >= -gs.hlen and dyy <= -1 then
							p := sprite_px(K_HARP_V, sx, sy);
							if p(6) = '1' then
								color := p(5 downto 0);				 -- harpoon up
							end if;
						end if;
					else 
						if dxx = 0 and dyy >= 1 and dyy <= gs.hlen then
							p := sprite_px(K_HARP_V, sx, sy);
							if p(6) = '1' then
								color := p(5 downto 0);				 -- harpoon down
							end if;
						end if;
					end if;
				end if;

				-- TODO(B): rocks layer
				for j in 0 to 1 loop
					if col = gs.rx(j) and row = gs.ry(j) then
						sxw := sx;
						if gs.rstate(j) = 1 then
							if (gs.rtimer(j) mod 8) >= 4 then
								sxw := (sx + 1) mod 8;				-- wobble
							end if;
						end if;
						p := sprite_px(K_ROCK, sxw, sy);
						if p(6) = '1' then
							color := p(5 downto 0);				 	-- rock
						end if;
					end if;
				end loop;

				-- TODO(B): enemies layer
				for i in 0 to 3 loop
					if (gs.ealive(i) = '1' and col = gs.ex(i) and row = gs.ey(i)) then
						if gs.einfl(i) >= 2 then
							p := sprite_px(K_BIG, sx, sy);
							if p(6) = '1' then
								color := p(5 downto 0);				 -- big enemy
							end if;
						elsif gs.einfl(i) = 1 then
							p := sprite_px(K_MID, sx, sy);
							if p(6) = '1' then
								color := p(5 downto 0);				 -- mid enemy
							end if;
						elsif gs.eghost(i) > 0 or gs.dirt(row*COLS + col) = '1' then
							p := sprite_px(K_GHOST, sx, sy);
							if p(6) = '1' then
								color := p(5 downto 0);				 -- ghost enemy
							end if;
						else
							p := sprite_px(K_BLOB, sx, sy);
							if p(6) = '1' then
								color := p(5 downto 0);				 -- small enemy
							end if;
						end if;
					end if;
				end loop;

				-- TODO(B): player layer
				if col = gs.px and row = gs.py then
					if gs.gstate /= 1 or (gs.gtimer mod 8) < 4 then	 -- blink
						sxw := sx;
						if gs.pdir = 3 then
							sxw := 7 - sx;  						 -- face left
						end if;
						p := sprite_px(K_PLAYER, sxw, sy);
						if p(6) = '1' then
							color := p(5 downto 0);  				 -- player
						end if;
					end if;
				end if;

				-- TODO(B): HUD layer
				if row = 0 then
					if col < gs.lives then
						p := sprite_px(K_PLAYER, sx, sy);
						if p(6) = '1' then
							color := p(5 downto 0);  				 -- life icon
						end if;
					end if;
					enemy_count := 0;									
					for i in 0 to 3 loop
						if gs.ealive(i) = '1' then
							enemy_count := enemy_count + 1;			 -- count enemies
						end if;
					end loop;
					if col >= COLS - enemy_count then
						p := sprite_px(K_BLOB, sx, sy);
						if p(6) = '1' then
							color := p(5 downto 0);  				 -- enemy icon
						end if;
					end if;
				end if;

				-- Pattern for every layer:
				--     p := sprite_px(kind, sx, sy);
				--     if p(6) = '1' then color := p(5 downto 0); end if;

				rgb <= color;
			end if;
		end if;
	end process;
end arch;
