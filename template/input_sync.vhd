-- input_sync.vhd
-- Synchronizer (2 flip-flops) + debouncer for one button.
-- dout is always active-high, whatever the button polarity is.
-- DEBOUNCE = clock cycles the input must stay changed (125000 @ 25 MHz = 5 ms).
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
	signal raw    : std_logic;
	signal m, s   : std_logic := '0';
	signal stable : std_logic := '0';
	signal cnt    : integer range 0 to DEBOUNCE := 0;
begin
	raw <= not din when ACTIVE_LOW else din;

	process(clk)
	begin
		if rising_edge(clk) then
			m <= raw;
			s <= m;
			if s = stable then
				cnt <= 0;
			elsif cnt = DEBOUNCE then
				stable <= s;
				cnt    <= 0;
			else
				cnt <= cnt + 1;
			end if;
		end if;
	end process;

	dout <= stable;
end arch;
