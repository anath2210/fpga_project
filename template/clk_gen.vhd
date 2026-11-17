-- clk_gen.vhd
-- 12 MHz board clock -> 25.175 MHz pixel clock using an MMCM (instantiated directly,
-- so there is no Clocking Wizard IP to create). Same numbers as the earlier VGA lab:
--   VCO = 12 MHz * 50.875 = 610.5 MHz   (legal range is 600-1200 MHz)
--   out = 610.5 MHz / 24.25 = 25.175 MHz (the VESA 640x480@60 pixel clock)
library IEEE;
use IEEE.std_logic_1164.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity clk_gen is
	port(
		clk_in  : in  std_logic;
		clk_out : out std_logic;
		locked  : out std_logic
	);
end clk_gen;

architecture arch of clk_gen is
	signal fb_u, fb_b, out_u : std_logic;
begin
	mmcm: MMCME2_BASE
		generic map(
			BANDWIDTH        => "OPTIMIZED",
			CLKFBOUT_MULT_F  => 50.875,
			CLKIN1_PERIOD    => 83.333,
			CLKOUT0_DIVIDE_F => 24.250,
			DIVCLK_DIVIDE    => 1,
			STARTUP_WAIT     => FALSE)
		port map(
			CLKIN1   => clk_in,
			CLKFBIN  => fb_b,
			CLKFBOUT => fb_u,
			CLKOUT0  => out_u,
			LOCKED   => locked,
			PWRDWN   => '0',
			RST      => '0');

	fb_buf:  BUFG port map(I => fb_u,  O => fb_b);
	out_buf: BUFG port map(I => out_u, O => clk_out);
end arch;
