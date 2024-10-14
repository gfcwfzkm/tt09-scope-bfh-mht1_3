library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
	port (
		clk_27MHz		: in std_logic;
		BTN_S1			: in std_logic;
		BTN_S2			: in std_logic;
		on_board_leds	: out std_logic_vector(5 downto 0);

		pmod_buttons	: in std_logic_vector(3 downto 0);

		pmod_switches	: in std_logic_vector(3 downto 0);

		pmod_ad1_cs		: out std_logic;
		pmod_ad1_sck	: out std_logic;
		pmod_ad1_miso1	: in std_logic;

		pmod_da2_cs		: out std_logic;
		pmod_da2_sck	: out std_logic;
		pmod_da2_mosi1	: out std_logic;
		pmod_da2_mosi2	: out std_logic;

		pmod_fram_cs	: out std_logic;
		pmod_fram_sck	: out std_logic;
		pmod_fram_miso	: in std_logic;
		pmod_fram_mosi	: out std_logic;

		pmod_hdmi_green	: out std_logic;
		pmod_hdmi_red	: out std_logic;
		pmod_hdmi_blue	: out std_logic;
		pmod_hdmi_clk	: out std_logic;
		pmod_hdmi_hsync	: out std_logic;
		pmod_hdmi_vsync	: out std_logic;
		pmod_hdmi_de	: out std_logic
	);
end entity top;

architecture rtl of top is
	signal enabled : std_logic := '1';
	signal rst_n : std_logic;
	signal clk_25MHz : std_logic;
	signal clk_50MHz : std_logic;

	signal ui_in, uio_out, uo_out : std_logic_vector(7 downto 0);

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
	component Gowin_rPLL
    	port (
    	    clkout: out std_logic;
    	    clkin: in std_logic
   		);
	end component;
begin

	PLL_TO_50MHZ: Gowin_rPLL
    	port map (
    	    clkout => clk_50MHz,
    	    clkin => clk_27MHz
    );

	CLKDIV2 : process (clk_50MHz, rst_n) begin
		if rst_n = '0' then
			clk_25MHz <= '0';
		elsif rising_edge(clk_50MHz) then
			clk_25MHz <= not clk_25MHz;
		end if;
	end process CLKDIV2;

	-- Init the tiny-tapeout style top file
	rst_n <= BTN_S1;
	enabled <= '1';

	-- Connect the tiny-tapeout style top file
	-- Input pmod pins
	ui_in <= (pmod_ad1_miso1, pmod_fram_miso, pmod_switches(1), pmod_switches(0), pmod_buttons);
	
	-- Output pmod pins to the hdmi pmod & the on-board led (ring oscillator)
	pmod_hdmi_green <= uo_out(0);
	pmod_hdmi_clk <= uo_out(1);
	pmod_hdmi_hsync <= uo_out(2);
	pmod_hdmi_red <= uo_out(4);
	pmod_hdmi_blue <= uo_out(5);
	pmod_hdmi_de <= uo_out(6);
	pmod_hdmi_vsync <= uo_out(7);
	on_board_leds(0) <= uo_out(3);

	-- Output pmod pins to the ad1, da2, fram pmods
	pmod_fram_sck <= uio_out(0);
	pmod_fram_mosi <= uio_out(1);
	pmod_fram_cs <= uio_out(2);
	pmod_ad1_sck <= uio_out(3);
	pmod_ad1_cs <= uio_out(4);
	pmod_da2_sck <= uio_out(5);
	pmod_da2_mosi1 <= uio_out(6);
	pmod_da2_cs <= uio_out(7);

	-- Set the second mosi pin to 0
	pmod_da2_mosi2 <= '0';

	TinyTapeout_Test : tt_um_gfcwfzkm_scope_bfh_mht1_3
	port map (
		ui_in	=> ui_in,
		uo_out	=> uo_out,
		uio_in	=> "00000000",
		uio_out	=> uio_out,
		uio_oe	=> open,
		ena		=> enabled,
		clk		=> clk_25MHz,
		rst_n	=> rst_n
	);

end architecture;