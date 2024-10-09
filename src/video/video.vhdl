library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity video is
	generic (
		c_HDMI_H_BITWIDTH	: positive := 10;
		c_HDMI_V_BITWIDTH	: positive := 10
	);
	port (
		clk   : in std_logic;
		reset : in std_logic;

		-- 
		line_end : out std_logic;
		frame_end : out std_logic;

		currentSample		: in unsigned(7 downto 0);
		lastSample			: in unsigned(7 downto 0);
		display_samples 	: in std_logic;
		displayDotSamples	: in std_logic;

		chAmplitude		: in signed(2 downto 0);
		chOffset		: in unsigned(4 downto 0);
		triggerXPos		: in unsigned(3 downto 0);
		triggerYPos		: in unsigned(3 downto 0);

		display_x : out unsigned(c_HDMI_H_BITWIDTH-1 downto 0);

		-- Video Signals
		r,g,b : out std_logic;
		hsync,vsync,de : out std_logic
	);
end entity video;

architecture rtl of video is
	signal draw_x : unsigned(c_HDMI_H_BITWIDTH-1 downto 0);
	signal draw_y : unsigned(c_HDMI_V_BITWIDTH-1 downto 0);
	signal draw_active : std_logic;
	signal grid_active : std_logic;

	component vtgen
		port (
		  	clk : in std_logic;
		  	reset : in std_logic;
		  	disp_active : out std_logic;
		  	disp_x : out unsigned(c_HDMI_H_BITWIDTH-1 downto 0);
		  	disp_y : out unsigned(c_HDMI_V_BITWIDTH-1 downto 0);
		  	line_end : out std_logic;
		  	frame_end : out std_logic;
		  	hdmi_vsync : out std_logic;
		  	hdmi_hsync : out std_logic;
		  	hdmi_de : out std_logic
		);
	end component;

	component merge_generators
		port (
			disp_x : in unsigned(c_HDMI_H_BITWIDTH-1 downto 0);
			disp_y : in unsigned(c_HDMI_V_BITWIDTH-1 downto 0);
			display_active : in std_logic;
			display_samples : in std_logic;
			currentSample : in unsigned(7 downto 0);
			lastSample : in unsigned(7 downto 0);
			displayDotSamples : in std_logic;
			chAmplitude : in signed(2 downto 0);
			chOffset : in unsigned(4 downto 0);
			triggerXPos :  unsigned(3 downto 0);
			triggerYPos :  unsigned(3 downto 0);
			red : out std_logic;
			green : out std_logic;
			blue : out std_logic
		);
	end component;
begin

	display_x <= draw_x;

	Video_Timing_Generator : vtgen
		port map (
			clk => clk,
			reset => reset,
			disp_active => draw_active,
			disp_x => draw_y,	-- X and Y are swapped because the screen is rotated CCW 90 degrees
			disp_y => draw_x,	-- X and Y are swapped because the screen is rotated CCW 90 degrees
			line_end => line_end,
			frame_end => frame_end,
			hdmi_vsync => vsync,
			hdmi_hsync => hsync,
			hdmi_de => de
	);

	Video_Signal_Merger : merge_generators
		port map (
			disp_x => draw_x,
			disp_y => draw_y,
			display_active => draw_active,
			display_samples => display_samples,
			currentSample => currentSample,
			lastSample => lastSample,
			displayDotSamples => displayDotSamples,
			chAmplitude => chAmplitude,
			chOffset => chOffset,
			triggerXPos => triggerXPos,
			triggerYPos => triggerYPos,
			red => r,
			green => g,
			blue => b
	);

end architecture;