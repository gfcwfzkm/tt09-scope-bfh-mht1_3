library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
	port (
		clk_50MHz	: in std_logic;
		BTN_S1		: in std_logic;
		BTN_S2		: in std_logic;
		
		uiIn		: in std_logic_vector(7 downto 0);
		uo_out		: out std_logic_vector(7 downto 0);
		uio_out		: out std_logic_vector(7 downto 0)
	);
end entity top;

architecture rtl of top is
	signal enabled : std_logic := '1';
	signal rst_n : std_logic;
	signal clk_25MHz : std_logic;
	component tt_um_gfcwfzkm_scope_bfh_mht1_3
		port (
		  	ui_in : in std_logic_vector(7 downto 0);
		  	uo_out : out std_logic_vector(7 downto 0);
		  	uio_in : in std_logic_vector(7 downto 0);
		  	uio_out : out std_logic_vector(7 downto 0);
		  	uio_oe : out std_logic_vector(7 downto 0);
		  	ena : in std_logic;
		  	clk : in std_logic;
		  	rst_n : in std_logic
		);
	end component;
begin

	CLKDIV : process (clk_50MHz, rst_n) begin
		if rst_n = '0' then
			clk_25MHz <= '0';
		elsif rising_edge(clk_50MHz) then
			clk_25MHz <= not clk_25MHz;
		end if;
	end process CLKDIV;

	-- Init the tiny-tapeout style top file
	rst_n <= not BTN_S1;
	enabled <= '1';

	TinyTapeout_Test : tt_um_gfcwfzkm_scope_bfh_mht1_3
	port map (
		ui_in	=> uiIn,
		uo_out	=> uo_out,
		uio_in	=> "00000000",
		uio_out	=> uio_out,
		uio_oe	=> open,
		ena		=> enabled,
		clk		=> clk_25MHz,
		rst_n	=> rst_n
	);

end architecture;