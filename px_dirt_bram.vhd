library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.VComponents.all;
use work.digger_pkg.all;

entity px_dirt_bram is
	port(
		clk       : in  std_logic;
		init_trig : in  std_logic;
		init_dirt : in  std_logic_vector(0 to ROWS * COLS - 1);
		we_a      : in  std_logic;
		addr_a    : in  chunk_addr_t;
		din_a     : in  std_logic;
		addr_b    : in  chunk_addr_t;
		dout_b    : out std_logic;
		busy      : out std_logic
	);
end px_dirt_bram;

architecture arch of px_dirt_bram is
	signal init_active : std_logic := '0';
	signal init_addr   : integer range 0 to NUM_CHUNKS - 1 := 0;
	signal init_map    : std_logic_vector(0 to ROWS * COLS - 1) := (others => '0');
	signal init_cx : integer range 0 to CHUNK_W - 1 := 0;
	signal init_cy : integer range 0 to CHUNK_H - 1 := 0;

	signal port_a_en   : std_logic := '0';
	signal port_a_we   : std_logic_vector(1 downto 0) := (others => '0');
	signal port_a_addr : std_logic_vector(13 downto 0) := (others => '0');
	signal port_a_di   : std_logic_vector(15 downto 0) := (others => '0');

	signal port_b_addr : std_logic_vector(13 downto 0) := (others => '0');
	signal port_b_do   : std_logic_vector(15 downto 0);
	signal port_b_dop  : std_logic_vector(1 downto 0);
begin
	busy   <= init_active;
	dout_b <= port_b_do(0);

	process(clk)
		variable tile_c   : integer range 0 to COLS - 1;
		variable tile_r   : integer range 0 to ROWS - 1;
		variable ibit     : std_logic;
	begin
		if rising_edge(clk) then
			port_a_en <= '0';
			port_a_we <= "00";

			if init_trig = '1' then
				init_active <= '1';
				init_addr <= 0;
				init_map <= init_dirt;
				init_cx <= 0;
				init_cy <= 0;
			elsif init_active = '1' then
				tile_c := init_cx / 8;
				tile_r := init_cy / 8;
				if tile_r >= ROW_DIRT0 and tile_r <= ROW_DIRT1 then
					ibit := init_map(tile_r * COLS + tile_c);
				else
					ibit := '0';
				end if;

				port_a_en   <= '1';
				port_a_we   <= "01";
				port_a_addr <= std_logic_vector(to_unsigned(init_addr, 14));
				port_a_di   <= (0 => ibit, others => '0');

				if init_addr = NUM_CHUNKS - 1 then
					init_active <= '0';
				else
					init_addr <= init_addr + 1;
					if init_cx = CHUNK_W - 1 then
						init_cx <= 0;
						init_cy <= init_cy + 1;
					else
						init_cx <= init_cx + 1;
					end if;
				end if;
			elsif we_a = '1' then
				port_a_en   <= '1';
				port_a_we   <= "01";
				port_a_addr <= std_logic_vector(addr_a);
				port_a_di   <= (0 => din_a, others => '0');
			end if;
		end if;
	end process;

	port_b_addr <= std_logic_vector(addr_b);

	dirt_ramb18 : RAMB18E1
		generic map(
			RAM_MODE                => "TDP",
			READ_WIDTH_A            => 1,
			WRITE_WIDTH_A           => 1,
			READ_WIDTH_B            => 1,
			WRITE_WIDTH_B           => 1,
			DOA_REG                 => 0,
			DOB_REG                 => 0,
			INIT_A                  => X"00000",
			INIT_B                  => X"00000",
			SRVAL_A                 => X"00000",
			SRVAL_B                 => X"00000",
			WRITE_MODE_A            => "NO_CHANGE",
			WRITE_MODE_B            => "NO_CHANGE",
			RDADDR_COLLISION_HWCONFIG => "DELAYED_WRITE",
			SIM_COLLISION_CHECK     => "ALL",
			SIM_DEVICE              => "7SERIES"
		)
		port map(
			CLKARDCLK     => clk,
			CLKBWRCLK     => clk,
			ENARDEN       => port_a_en,
			ENBWREN       => '1',
			REGCEAREGCE   => '0',
			REGCEB        => '0',
			RSTRAMARSTRAM => '0',
			RSTRAMB       => '0',
			RSTREGARSTREG => '0',
			RSTREGB       => '0',
			ADDRARDADDR   => port_a_addr,
			ADDRBWRADDR   => port_b_addr,
			DIADI         => port_a_di,
			DIBDI         => (others => '0'),
			DIPADIP       => "00",
			DIPBDIP       => "00",
			WEA           => port_a_we,
			WEBWE         => (others => '0'),
			DOADO         => open,
			DOBDO         => port_b_do,
			DOPADOP       => open,
			DOPBDOP       => port_b_dop
		);
end arch;