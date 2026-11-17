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
	signal rh, rt, ro : integer range 0 to 9 := 0;      -- the three digits of the round number

	constant BLACK  : std_logic_vector(5 downto 0) := "000000";
	constant WHITE  : std_logic_vector(5 downto 0) := "111111";
	constant YELLOW : std_logic_vector(5 downto 0) := "111100";
	constant RED    : std_logic_vector(5 downto 0) := "110000";
	constant GRAY   : std_logic_vector(5 downto 0) := "010101";

	function dirt_color(layer : integer; dark : boolean) return std_logic_vector is
	begin
		case layer is
			when 1 =>      if dark then return "110100"; else return "111000"; end if;   -- yellow
			when 2 =>      if dark then return "100100"; else return "110100"; end if;   -- orange
			when 3 =>      if dark then return "100000"; else return "110000"; end if;   -- red
			when others => if dark then return "010001"; else return "100001"; end if;   -- maroon
		end case;
	end function;
begin
	-- round-number digits (registered; the game state only changes once per frame)
	process(clk)
	begin
		if rising_edge(clk) then
			rh <= gs.rnd / 100;
			rt <= (gs.rnd / 10) mod 10;
			ro <= gs.rnd mod 10;
		end if;
	end process;

	process(clk)
		variable x, y     : integer;
		variable lx, ly   : integer;                  -- position inside the playfield
		variable c, r     : integer;                  -- cell
		variable sx, sy   : integer;                  -- pixel inside the cell
		variable col      : std_logic_vector(5 downto 0);
		variable cx, ch   : integer;
		variable idx      : integer;
		variable wx       : integer;
		variable dx, dy   : integer;
		variable r2       : integer;
		variable bcol     : std_logic_vector(5 downto 0);
		variable fr       : rect_t;

		-- draw one 16x16 sprite whose top-left corner is (ox, oy) in the playfield
		procedure put(kind, ox, oy : integer; mirror : boolean) is
			variable ax, ay, i : integer;
		begin
			if lx >= ox and lx < ox + TILE and ly >= oy and ly < oy + TILE then
				ax := lx - ox;
				ay := ly - oy;
				if mirror then ax := TILE - 1 - ax; end if;
				i := spr_px(kind, ax, ay);
				if i /= 0 then col := pal(i); end if;
			end if;
		end procedure;
	begin
		if rising_edge(clk) then
			hs_o <= hs;                                  -- sync is delayed by the same one clock
			vs_o <= vs;
			col  := BLACK;
			x := to_integer(px);
			y := to_integer(py);

			if active = '1' then
				if x >= PF_X0 and x < PF_X0 + PF_W and y >= PF_Y0 and y < PF_Y0 + PF_H then
					lx := x - PF_X0;   ly := y - PF_Y0;
					c  := lx / TILE;   r  := ly / TILE;
					sx := lx mod TILE; sy := ly mod TILE;

					-- 1. terrain
					if r = ROW_SURF then
						if sy >= 13 then col := "001100"; else col := "000111"; end if;   -- grass / sky
					elsif r >= ROW_DIRT0 and r <= ROW_DIRT1 then
						if gs.dirt(r * COLS + c) = '1' then
							col := dirt_color(layer_of_row(r), ((sx + 2 * sy + 3 * c + 5 * r) mod 7) = 0);
						end if;
					end if;

					-- 2. rocks 
					for j in 0 to NUM_ROCKS - 1 loop
						if gs.rstate(j) < 3 then
							wx := gs.rx(j);
							if gs.rstate(j) = 1 then                         -- wobble left / right
								if (gs.rtimer(j) / 3) mod 2 = 0 then wx := wx + 1; else wx := wx - 1; end if;
							end if;
							put(SPR_ROCK, wx, gs.ry(j), false);
						end if;
					end loop;

					-- 3. vegetable
					if gs.vstate = 1 and not (gs.vtimer < 150 and (gs.vtimer / 8) mod 2 = 0) then
						if lx >= VEG_COL * TILE and lx < VEG_COL * TILE + TILE and
						   ly >= VEG_ROW * TILE and ly < VEG_ROW * TILE + TILE then
							idx := spr_px(SPR_VEG, lx - VEG_COL * TILE, ly - VEG_ROW * TILE);
							if idx = 4 then
								col := veg_color(veg_tier(gs.rnd));
							elsif idx /= 0 then
								col := pal(idx);
							end if;
						end if;
					end if;

					-- 4. enemies
					for i in 0 to NUM_ENEMIES - 1 loop
						if gs.ealive(i) = '1' then
							if gs.einfl(i) > 0 then
								-- inflated: a round balloon that grows with every pump
								dx := lx - (gs.ex(i) + 8);
								dy := ly - (gs.ey(i) + 8);
								case gs.einfl(i) is
									when 1      => r2 := 36;
									when 2      => r2 := 49;
									when others => r2 := 64;
								end case;
								if dx * dx + dy * dy <= r2 then
									if gs.ekind(i) = 1 then bcol := pal(5); else bcol := pal(2); end if;
									if gs.einfl(i) = 3 and (gs.ecnt(i) / 4) mod 2 = 0 then bcol := WHITE; end if;
									col := bcol;
									if (dx = -3 or dx = 2) and (dy = -2 or dy = -1) then col := WHITE; end if;
								end if;
							elsif gs.eghost(i) > 0 and in_dirt(gs, gs.ex(i), gs.ey(i)) then
								put(SPR_GHOST, gs.ex(i), gs.ey(i), false);
							elsif gs.ekind(i) = 1 then
								put(SPR_BREATHER, gs.ex(i), gs.ey(i), false);
							else
								put(SPR_WALKER, gs.ex(i), gs.ey(i), false);
							end if;

							-- 5. flame
							if fire_active(gs, i) then
								fr := flame_rect(gs, i);
								if in_rect(fr, lx, ly) then
									if ((lx + ly) / 3) mod 2 = 0 then col := YELLOW; else col := pal(6); end if;
								end if;
							end if;
						end if;
					end loop;

					-- 6. pump hose
					if gs.hlen > 0 and gs.gstate = 0 then
						if in_rect(hose_rect(gs), lx, ly) then
							if ((lx + ly) / 2) mod 2 = 0 then col := WHITE; else col := pal(7); end if;
						end if;
					end if;

					-- 7. the digger
					if gs.gstate /= 2 and not (gs.gstate = 1 and (gs.gtimer / 6) mod 2 = 1) then
						case gs.pdir is
							when 1      => put(SPR_PLAYER_R, gs.px, gs.py, false);
							when 3      => put(SPR_PLAYER_R, gs.px, gs.py, true);
							when 0      => put(SPR_PLAYER_U, gs.px, gs.py, false);
							when others => put(SPR_PLAYER_D, gs.px, gs.py, false);
						end case;
					end if;

					-- HUD: top row (score, high score)
					if r = 0 then
						cx := lx / 8;
						ch := CH_BLANK;
						if cx <= 5 then
							ch := gs.score(5 - cx);
						elsif cx = 19 then
							ch := 10;
						elsif cx = 20 then
							ch := 11;
						elsif cx >= 22 and cx <= 27 then
							ch := gs.hiscore(27 - cx);
						end if;
						if font_px(ch, lx mod 8, sy / 2) then
							if cx = 19 or cx = 20 then col := RED;
							elsif cx >= 22 then col := YELLOW;
							else col := WHITE; end if;
						end if;
					end if;

					-- HUD: bottom row (lives, round)
					if r = ROW_HUD1 then
						if c < 5 and c < gs.lives then
							put(SPR_PLAYER_D, c * TILE, ROW_HUD1 * TILE, false);
						end if;
						cx := lx / 8;
						ch := CH_BLANK;
						if cx = 24 then
							ch := 12;
						elsif cx = 25 and rh > 0 then
							ch := rh;
						elsif cx = 26 and (rh > 0 or rt > 0) then
							ch := rt;
						elsif cx = 27 then
							ch := ro;
						end if;
						if font_px(ch, lx mod 8, sy / 2) then
							if cx = 24 then col := RED; else col := WHITE; end if;
						end if;
					end if;

					-- messages
					if ly >= 7 * TILE and ly < 8 * TILE then
						cx := lx / 8;
						ch := CH_BLANK;
						if gs.gstate = 4 then                                  -- READY
							case cx is
								when 11 => ch := 12;  when 12 => ch := 16;  when 13 => ch := 14;
								when 14 => ch := 19;  when 15 => ch := 20;
								when others => null;
							end case;
						elsif gs.gstate = 2 then                               -- GAME OVER
							case cx is
								when 9  => ch := 13;  when 10 => ch := 14;  when 11 => ch := 15;
								when 12 => ch := 16;  when 14 => ch := 17;  when 15 => ch := 18;
								when 16 => ch := 16;  when 17 => ch := 12;
								when others => null;
							end case;
						end if;
						if font_px(ch, lx mod 8, sy / 2) then col := YELLOW; end if;
					end if;

				elsif x >= PF_X0 - 2 and x < PF_X0 + PF_W + 2 and y >= PF_Y0 - 2 and y < PF_Y0 + PF_H + 2 then
					col := GRAY;                                               -- thin frame around the playfield
				end if;
			end if;

			rgb <= col;
		end if;
	end process;
end arch;
