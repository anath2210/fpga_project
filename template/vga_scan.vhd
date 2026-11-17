-- vga_scan.vhd
-- PIN-FINDER for the VGA Pmod in header JA. Use it when you don't know which Pmod pin carries
-- which signal. It needs clk_gen.vhd, vga_timing.vhd and input_sync.vhd (the finished one from
-- the full project) in the same Vivado project, and digger.xdc UNCHANGED (same port names).
-- To use: add this file, right-click it -> "Set as Top", rebuild, program.
--
-- The 8 outputs are treated as "JA signals" 1..8, which are Pmod pins 1,2,3,4,7,8,9,10:
--     signal #:    1  2  3  4  5  6  7  8
--     Pmod pin:    1  2  3  4  7  8  9  10
--
-- STAGE 1: find HSYNC and VSYNC
--   The design tries every (HSYNC pin, VSYNC pin) pair, 6 seconds each (56 pairs, ~5.6 min).
--   All six other pins carry the same picture: a white frame, and two rows of white squares.
--   When the pair is right the monitor stops saying "no signal" and you see the picture.
--   Then press BTN1 at once to FREEZE (LED1 turns on). Read the squares:
--       upper row: number of squares = signal # that is HSYNC   (1..8)
--       lower row: number of squares = signal # that is VSYNC   (1..8)
--   (BTN0 while scanning skips to the next pair immediately.)
--   If the picture vanishes before you press BTN1, press BTN1 anyway to freeze, then press BTN1
--   again to resume and wait for the next lap. It will come around again.
--
-- STAGE 2: find the color pins (only after the sync pair is frozen)
--   While frozen, each press of BTN0 switches to the next of the six remaining pins and drives
--   ONLY that pin high over the whole screen. Look at the colour:
--       red / green / blue tells you the channel; the BRIGHTER of the two pins of a channel is
--       the MSB ([1]), the dimmer one is the LSB ([0]). (Nothing at all = black screen means that
--       pin is not connected to a color.)
--   The probe order is: the remaining pins in increasing signal # (HSYNC and VSYNC skipped).
--   After 6 presses BTN0 returns to the full picture (squares).
--   BTN1 resumes the scan.
--
-- Then edit the 8 lines of the VGA section of digger.xdc so each port is on the pin you found.
--
-- LED0: pixel clock locked.   LED1: frozen (stage 2 available).
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity vga_scan is
	port(
		sysclk    : in  std_logic;
		btn       : in  std_logic_vector(1 downto 0);
		led       : out std_logic_vector(1 downto 0);
		vga_r     : out std_logic_vector(1 downto 0);
		vga_g     : out std_logic_vector(1 downto 0);
		vga_b     : out std_logic_vector(1 downto 0);
		vga_hs    : out std_logic;
		vga_vs    : out std_logic;
		key_up    : in  std_logic;
		key_down  : in  std_logic;
		key_left  : in  std_logic;
		key_right : in  std_logic;
		key_pump  : in  std_logic
	);
end vga_scan;

architecture arch of vga_scan is
	signal pix_clk, locked      : std_logic;
	signal lock_m, lock_s       : std_logic := '0';
	signal hs, vs, active, tick : std_logic;
	signal px, py               : unsigned(9 downto 0);
	signal d0, d1               : std_logic;                 -- debounced buttons
	signal p0, p1               : std_logic := '0';          -- previous values (edge detect)
	signal n                    : integer range 0 to 55 := 0;    -- which (h,v) pair
	signal frames               : integer range 0 to 359 := 0;   -- 6 s at 60 Hz
	signal hold                 : std_logic := '0';
	signal probe                : integer range 0 to 6 := 0;     -- 0 = squares, 1..6 = single pin
	signal h_idx, v_idx         : integer range 0 to 7 := 0;     -- 0-based signal # of HSYNC / VSYNC
	signal ja                   : std_logic_vector(7 downto 0) := (others => '0');
begin
	clkgen: entity work.clk_gen
		port map(clk_in => sysclk, clk_out => pix_clk, locked => locked);

	timing: entity work.vga_timing
		port map(clk => pix_clk, hs => hs, vs => vs, active => active,
		         tick => tick, px => px, py => py);

	b0: entity work.input_sync generic map(ACTIVE_LOW => false)
		port map(clk => pix_clk, din => btn(0), dout => d0);
	b1: entity work.input_sync generic map(ACTIVE_LOW => false)
		port map(clk => pix_clk, din => btn(1), dout => d1);

	-- pair number n (0..55) -> (h_idx, v_idx), h_idx /= v_idx, all 56 ordered pairs
	h_idx <= n / 7;
	v_idx <= (n mod 7) when (n mod 7) < (n / 7) else (n mod 7) + 1;

	-- control: auto-step, freeze, probe
	process(pix_clk)
	begin
		if rising_edge(pix_clk) then
			p0 <= d0;
			p1 <= d1;

			if d1 = '1' and p1 = '0' then                     -- BTN1 pressed: freeze / resume
				hold   <= not hold;
				probe  <= 0;
				frames <= 0;
			elsif d0 = '1' and p0 = '0' then                  -- BTN0 pressed
				if hold = '1' then                            -- frozen: next probe pin
					if probe = 6 then
						probe <= 0;
					else
						probe <= probe + 1;
					end if;
				else                                          -- scanning: skip to next pair
					frames <= 0;
					if n = 55 then n <= 0; else n <= n + 1; end if;
				end if;
			elsif tick = '1' and hold = '0' then              -- auto-advance every 6 s
				if frames = 359 then
					frames <= 0;
					if n = 55 then n <= 0; else n <= n + 1; end if;
				else
					frames <= frames + 1;
				end if;
			end if;
		end if;
	end process;

	-- picture + pin drive (all registered together, so sync and video stay aligned)
	process(pix_clk)
		variable xi, yi  : integer range 0 to 1023;
		variable vid     : std_logic;
		variable cnt     : integer range 0 to 8;
		variable pin_sel : integer range 0 to 7;
	begin
		if rising_edge(pix_clk) then
			xi := to_integer(px);
			yi := to_integer(py);

			-- full picture: white frame + two rows of squares
			vid := '0';
			if active = '1' then
				if xi < 2 or xi > 637 or yi < 2 or yi > 477 then
					vid := '1';
				elsif yi >= 100 and yi < 140 then              -- upper row: h_idx + 1 squares
					for k in 0 to 7 loop
						if k <= h_idx and xi >= 100 + k*60 and xi < 140 + k*60 then
							vid := '1';
						end if;
					end loop;
				elsif yi >= 200 and yi < 240 then              -- lower row: v_idx + 1 squares
					for k in 0 to 7 loop
						if k <= v_idx and xi >= 100 + k*60 and xi < 140 + k*60 then
							vid := '1';
						end if;
					end loop;
				end if;
			end if;

			-- which pin is the probe-th non-sync pin (increasing order)?
			cnt     := 0;
			pin_sel := 0;
			for i in 0 to 7 loop
				if i /= h_idx and i /= v_idx then
					cnt := cnt + 1;
					if cnt = probe then
						pin_sel := i;
					end if;
				end if;
			end loop;

			for i in 0 to 7 loop
				if i = h_idx then
					ja(i) <= hs;
				elsif i = v_idx then
					ja(i) <= vs;
				elsif probe = 0 then
					ja(i) <= vid;
				elsif i = pin_sel then
					ja(i) <= active;               -- only this pin high, whole screen
				else
					ja(i) <= '0';
				end if;
			end loop;

			lock_m <= locked;
			lock_s <= lock_m;
		end if;
	end process;

	-- signal # 1..8 = ja(0)..ja(7)  =  Pmod pins 1,2,3,4,7,8,9,10  (same as digger.xdc)
	vga_r  <= ja(0) & ja(1);
	vga_g  <= ja(2) & ja(3);
	vga_b  <= ja(4) & ja(5);
	vga_hs <= ja(6);
	vga_vs <= ja(7);

	led(0) <= lock_s;
	led(1) <= hold;
end arch;
