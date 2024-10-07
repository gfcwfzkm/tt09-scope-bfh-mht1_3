library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tt_um_gfcwfzkm_scope_bfh_mht1_3 is
	port (
		ui_in   : in  std_logic_vector(7 downto 0);
		uo_out  : out std_logic_vector(7 downto 0);
		uio_in  : in  std_logic_vector(7 downto 0);
		uio_out : out std_logic_vector(7 downto 0);
		uio_oe  : out std_logic_vector(7 downto 0);
		ena     : in  std_logic;
		clk     : in  std_logic;
		rst_n   : in  std_logic
	);
end tt_um_gfcwfzkm_scope_bfh_mht1_3;

architecture Behavioral of tt_um_gfcwfzkm_scope_bfh_mht1_3 is
	component video
		port (
		  	clk : in std_logic;
		  	reset : in std_logic;
			line_end : out std_logic;
			frame_end : out std_logic;
			currentSample : in unsigned(7 downto 0);
			lastSample : in unsigned(7 downto 0);
			chAmplitude : in signed(2 downto 0);
			chOffset : in unsigned(4 downto 0);
			triggerXPos :  unsigned(3 downto 0);
			triggerYPos :  unsigned(4 downto 0);
		  	r : out std_logic;
		  	g : out std_logic;
		  	b : out std_logic;
		  	hsync : out std_logic;
		  	vsync : out std_logic;
		  	de : out std_logic
		);
	end component;

	component settings
		port (
			clk : in std_logic;
			reset : in std_logic;
			sample_inputs : in std_logic;
			buttons : in std_logic_vector(3 downto 0);
			switches : in std_logic_vector(1 downto 0);
			trigger_start : out std_logic;
			chAmplitude : out signed(2 downto 0);
			chOffset : out unsigned(4 downto 0);
			triggerXPos : out unsigned(3 downto 0);
			triggerYPos : out unsigned(4 downto 0);
			timebase : out unsigned(3 downto 0);
			memoryShift : out signed(7 downto 0)
		);
	end component;

	signal reset          : std_logic;
	signal frame_end	  : std_logic;
	signal line_end		  : std_logic;

	signal trigger_start : std_logic;
	signal chAmplitude	  : signed(2 downto 0);
	signal chOffset		  : unsigned(4 downto 0);
	signal triggerXPos	  : unsigned(3 downto 0);
	signal triggerYPos	  : unsigned(4 downto 0);
	signal timebase		  : unsigned(3 downto 0);
	signal memoryShift	  : signed(7 downto 0);
begin

	-- Make the reset active-high
	reset <= not rst_n;

	-- Set the bidirectional IOs to outputs
	uio_oe <= "11111111";
	
	-- Video Generator Entity, attached to a 1bpp HDMI Pmod
	VIDEOGEN : video
	port map (
		clk			=> clk,
		reset		=> reset,
		line_end	=> line_end,
		frame_end	=> frame_end,
		currentSample => to_unsigned(120, 8),
		lastSample	=> to_unsigned(120, 8),
		chAmplitude	=> chAmplitude,
		chOffset	=> chOffset,
		triggerXPos	=> triggerXPos,
		triggerYPos	=> triggerYPos,
		r			=> uo_out(4),
		g			=> uo_out(0),
		b			=> uo_out(5),
		hsync		=> uo_out(2),
		vsync		=> uo_out(7),
		de			=> uo_out(6)
	);
	uo_out(1) <= clk;	-- HDMI Clock

	-- Settings Entity, attached to the buttons and switches
	OSCILLOSCOPE_CONTROL : settings
	port map (
		clk			=> clk,
		reset		=> reset,
		sample_inputs => frame_end,
		buttons		=> ui_in(3 downto 0),
		switches	=> ui_in(5 downto 4),
		trigger_start => trigger_start,
		chAmplitude	=> chAmplitude,
		chOffset	=> chOffset,
		triggerXPos	=> triggerXPos,
		triggerYPos	=> triggerYPos,
		timebase	=> timebase,
		memoryShift	=> memoryShift
	);

end Behavioral;