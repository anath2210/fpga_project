library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.digger_pkg.all;

entity digger_top is
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
end digger_top;

architecture arch of digger_top is
	signal pix_clk, locked          : std_logic;
	signal lock_m, lock_s           : std_logic := '0';
	signal hs, vs, active, tick     : std_logic;
	signal hs_o, vs_o               : std_logic;
	signal px, py                   : unsigned(9 downto 0);
	signal rgb                      : std_logic_vector(5 downto 0);
	signal d_up, d_down, d_left     : std_logic;
	signal d_right, d_pump          : std_logic;
	signal d_start, d_rst           : std_logic;
	signal rst                      : std_logic;
	signal gs                       : game_state_t;
	signal ram_we_s                 : std_logic;
	signal ram_addr_a_s             : chunk_addr_t;
	signal ram_addr_b_s             : chunk_addr_t;
	signal ram_din_s                : std_logic;
	signal ram_dout_b_s             : std_logic;
	signal init_ram_s               : std_logic;
	signal init_map_s               : std_logic_vector(0 to ROWS * COLS - 1);
	signal ram_busy_s               : std_logic;
begin
	clkgen: entity work.clk_gen
		port map(clk_in => sysclk, clk_out => pix_clk, locked => locked);

	process(pix_clk)
	begin
		if rising_edge(pix_clk) then
			lock_m <= locked;
			lock_s <= lock_m;
		end if;
	end process;
	rst <= d_rst or (not lock_s);

	timing: entity work.vga_timing
		port map(clk => pix_clk, hs => hs, vs => vs, active => active,
		         tick => tick, px => px, py => py);

	s_up:    entity work.input_sync generic map(ACTIVE_LOW => true)
		port map(clk => pix_clk, din => key_up,    dout => d_up);
	s_down:  entity work.input_sync generic map(ACTIVE_LOW => true)
		port map(clk => pix_clk, din => key_down,  dout => d_down);
	s_left:  entity work.input_sync generic map(ACTIVE_LOW => true)
		port map(clk => pix_clk, din => key_left,  dout => d_left);
	s_right: entity work.input_sync generic map(ACTIVE_LOW => true)
		port map(clk => pix_clk, din => key_right, dout => d_right);
	s_pump:  entity work.input_sync generic map(ACTIVE_LOW => true)
		port map(clk => pix_clk, din => key_pump,  dout => d_pump);
	s_start: entity work.input_sync generic map(ACTIVE_LOW => false)
		port map(clk => pix_clk, din => btn(0),    dout => d_start);
	s_rst:   entity work.input_sync generic map(ACTIVE_LOW => false)
		port map(clk => pix_clk, din => btn(1),    dout => d_rst);

	logic: entity work.game
		port map(clk => pix_clk, rst => rst, tick => tick,
		         k_up => d_up, k_down => d_down, k_left => d_left,
		         k_right => d_right, k_pump => d_pump, k_start => d_start,
		         gs => gs, ram_we => ram_we_s, ram_addr => ram_addr_a_s,
		         ram_din => ram_din_s, init_ram => init_ram_s, init_map => init_map_s);

	dirt_bram: entity work.px_dirt_bram
		port map(clk => pix_clk, init_trig => init_ram_s, init_dirt => init_map_s,
		         we_a => ram_we_s, addr_a => ram_addr_a_s, din_a => ram_din_s,
		         addr_b => ram_addr_b_s, dout_b => ram_dout_b_s, busy => ram_busy_s);

	draw: entity work.renderer
		port map(clk => pix_clk, hs => hs, vs => vs, active => active,
		         px => px, py => py, gs => gs, dirt_px => ram_dout_b_s,
		         ram_addr => ram_addr_b_s, rgb => rgb, hs_o => hs_o, vs_o => vs_o);

	vga_r  <= rgb(5 downto 4);
	vga_g  <= rgb(3 downto 2);
	vga_b  <= rgb(1 downto 0);
	vga_hs <= hs_o;
	vga_vs <= vs_o;

	led(0) <= lock_s;
	led(1) <= '1' when gs.gstate = 0 else '0';
end arch;