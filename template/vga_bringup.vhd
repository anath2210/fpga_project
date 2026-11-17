-- vga_bringup.vhd
-- Minimal VGA test: 12 MHz -> 25.2 MHz clock, VGA timing, 8 color bars + white border.
-- No game, no game buttons, no renderer. Use it to find out whether the clock, the sync signals
-- and the VGA Pmod pin mapping work.
--
-- It has the SAME port names as digger_top, so digger.xdc works unchanged.
-- Needs clk_gen.vhd and vga_timing.vhd from the full project in the same Vivado project.
-- To use: add this file, right-click it -> "Set as Top", rebuild, program.
--
-- What you should see:
--   LED0 ON            : the MMCM locked, so the pixel clock is running
--   LED1 blinking 1 Hz : vga_timing is counting and producing its 60 Hz frame tick
--   Monitor            : 8 vertical bars (white, yellow, cyan, green, magenta, red, blue, black)
--                        with a thin white border around the whole picture
--
-- Checking the color pins (the Pmod pin order in digger.xdc is an assumption):
--   hold BTN0 only -> the whole screen should turn solid RED
--   hold BTN1 only -> solid GREEN
--   hold both      -> solid BLUE
--   If a button shows the wrong color, the matching vga_r / vga_g / vga_b lines in digger.xdc
--   are on the wrong Pmod pins. If the picture is there but the colors are dim or wrong in
--   shade, a [1] / [0] (MSB / LSB) pair is swapped.
--   If the monitor says "no signal", suspect the vga_hs / vga_vs pins first.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity vga_bringup is
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
end vga_bringup;

architecture arch of vga_bringup is
	signal pix_clk, locked      : std_logic;
	signal lock_m, lock_s       : std_logic := '0';
	signal hs, vs, active, tick : std_logic;
	signal hs_o, vs_o           : std_logic := '1';
	signal px, py               : unsigned(9 downto 0);
	signal rgb                  : std_logic_vector(5 downto 0) := "000000";
	signal btn_m, btn_s         : std_logic_vector(1 downto 0) := "00";
	signal tcnt                 : integer range 0 to 29 := 0;
	signal blink                : std_logic := '0';
begin
	clkgen: entity work.clk_gen
		port map(clk_in => sysclk, clk_out => pix_clk, locked => locked);

	timing: entity work.vga_timing
		port map(clk => pix_clk, hs => hs, vs => vs, active => active,
		         tick => tick, px => px, py => py);

	-- picture, registered; hs/vs delayed by the same one clock to stay aligned
	process(pix_clk)
		variable bar : integer range 0 to 15;
	begin
		if rising_edge(pix_clk) then
			btn_m <= btn;                                 -- 2 flip-flops: buttons are asynchronous
			btn_s <= btn_m;
			hs_o  <= hs;
			vs_o  <= vs;

			if active = '0' then
				rgb <= "000000";                          -- black in blanking
			elsif btn_s = "01" then
				rgb <= "110000";                          -- BTN0: solid red
			elsif btn_s = "10" then
				rgb <= "001100";                          -- BTN1: solid green
			elsif btn_s = "11" then
				rgb <= "000011";                          -- both: solid blue
			elsif px = 0 or px = 639 or py = 0 or py = 479 then
				rgb <= "111111";                          -- white border
			else
				bar := to_integer(px) / 80;               -- 0..7, each bar 80 pixels wide
				case bar is
					when 0      => rgb <= "111111";       -- white
					when 1      => rgb <= "111100";       -- yellow
					when 2      => rgb <= "001111";       -- cyan
					when 3      => rgb <= "001100";       -- green
					when 4      => rgb <= "110011";       -- magenta
					when 5      => rgb <= "110000";       -- red
					when 6      => rgb <= "000011";       -- blue
					when others => rgb <= "000000";       -- black
				end case;
			end if;
		end if;
	end process;

	-- LEDs: lock indicator, and a 1 Hz blink derived from the 60 Hz frame tick
	process(pix_clk)
	begin
		if rising_edge(pix_clk) then
			lock_m <= locked;
			lock_s <= lock_m;
			if tick = '1' then
				if tcnt = 29 then
					tcnt  <= 0;
					blink <= not blink;
				else
					tcnt <= tcnt + 1;
				end if;
			end if;
		end if;
	end process;

	led(0) <= lock_s;
	led(1) <= blink;

	vga_r  <= rgb(5 downto 4);
	vga_g  <= rgb(3 downto 2);
	vga_b  <= rgb(1 downto 0);
	vga_hs <= hs_o;
	vga_vs <= vs_o;
end arch;
