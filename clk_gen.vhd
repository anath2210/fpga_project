-- clk_gen.vhd  --  OWNER: Person A (Hardware & Video)
--
-- GOAL: turn the 12 MHz board clock into a 25 MHz pixel clock for VGA 640x480.
--
-- HOW: use an MMCM (a programmable clock synthesizer inside the FPGA).
--   VCO frequency  = clk_in * CLKFBOUT_MULT_F / DIVCLK_DIVIDE
--   output freq    = VCO / CLKOUT0_DIVIDE_F
--   The VCO must stay between 600 and 1200 MHz for this chip (Artix-7, speed grade -1).
--   Pick CLKFBOUT_MULT_F and CLKOUT0_DIVIDE_F so the output is 25.0 MHz.
--   (Check your answer: MULT = 62.5 and DIVIDE = 30.0 with DIVCLK_DIVIDE = 1.)
--   CLKIN1_PERIOD is the INPUT clock period in ns (12 MHz -> 83.333).
--
-- TODO(A):
--   1. Instantiate the UNISIM primitive MMCME2_BASE (generic map + port map).
--      Needed port connections: CLKIN1, CLKFBIN, CLKFBOUT, CLKOUT0, LOCKED,
--      PWRDWN => '0', RST => '0'. Leave the other outputs unconnected.
--   2. Put a BUFG on the feedback path (CLKFBOUT -> BUFG -> CLKFBIN) and a BUFG on
--      CLKOUT0 (-> clk_out). BUFG = routes a clock onto the FPGA's global clock network.
--   3. Drive 'locked' from the MMCM's LOCKED output (goes high when the clock is stable).
--   4. DELETE the two placeholder lines at the bottom. They pass the 12 MHz clock
--      straight through just so the project compiles; VGA will NOT work with them.
--
-- Hint: UNISIM primitives need these lines at the top (already added below):
--       library UNISIM;  use UNISIM.vcomponents.all;
library IEEE;
use IEEE.std_logic_1164.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity clk_gen is
	port(
		clk_in  : in  std_logic;    -- 12 MHz from the board
		clk_out : out std_logic;    -- 25 MHz pixel clock
		locked  : out std_logic     -- '1' once clk_out is stable
	);
end clk_gen;

architecture arch of clk_gen is
	-- TODO(A): declare the signals you need (unbuffered feedback, buffered feedback,
	--          unbuffered output clock).
begin
	-- TODO(A): MMCME2_BASE instance and the two BUFGs go here.

	-- PLACEHOLDER (delete once the MMCM works):
	clk_out <= clk_in;
	locked  <= '1';
end arch;
