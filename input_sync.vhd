-- input_sync.vhd  --  OWNER: Person A (Hardware & Video)
--
-- GOAL: make one pushbutton safe to use inside the FPGA.
-- A mechanical button has two problems:
--   (1) it is asynchronous to our clock -> can cause metastability in a flip-flop;
--   (2) it "bounces" (flickers 0/1) for a few milliseconds when pressed.
--
-- TODO(A):
--   1. Synchronize: pass 'raw' through TWO flip-flops in a row (m then s).
--   2. Debounce: keep a 'stable' output. If s differs from stable, count clock cycles;
--      if s stays different for DEBOUNCE cycles in a row, copy s into stable.
--      If s equals stable again, reset the counter to 0.
--      (125000 cycles at 25 MHz = 5 ms)
--   3. Output dout = stable. It is ALWAYS active-high ('1' = pressed).
--   4. DELETE the placeholder at the bottom.
--
-- The ACTIVE_LOW generic is already handled for you: the external game buttons connect to
-- GND, so they read '0' when pressed; the 'raw' signal flips that so downstream logic
-- sees '1' = pressed.
library IEEE;
use IEEE.std_logic_1164.all;

entity input_sync is
	generic(
		ACTIVE_LOW : boolean := false;
		DEBOUNCE   : integer := 125000
	);
	port(
		clk  : in  std_logic;
		din  : in  std_logic;
		dout : out std_logic
	);
end input_sync;

architecture arch of input_sync is
	signal raw : std_logic;
	-- TODO(A): signals for the 2-flip-flop synchronizer, the stable value and the counter
	--          (counter: integer range 0 to DEBOUNCE).
begin
	raw <= not din when ACTIVE_LOW else din;

	-- TODO(A): the synchronizer + debounce process goes here.

	-- PLACEHOLDER (delete once implemented): no sync, no debounce
	dout <= raw;
end arch;
