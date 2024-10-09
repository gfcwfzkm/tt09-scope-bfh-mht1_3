-- TerosHDL Documentation:
--! @title Video Module
--! @author Pascal Gesell (gesep1 / gfcwfzkm)
--! @version 1.0
--! @date 09.10.2024
--! @brief Video module for the HDMI output.
--!
--! This module simply wires together the timing generator and the signal generator to create a video output.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity video is
	generic (
		--! HDMI Horizontal Bitwidth
		c_HDMI_H_BITWIDTH	: positive := 10;
		--! HDMI Vertical Bitwidth
		c_HDMI_V_BITWIDTH	: positive := 10
	);
	port (
		--! Clock signal
		clk   : in std_logic;
		--! Reset signal (active high, asynchronous)
		reset : in std_logic;

		--! Indicate a line end
		line_end : out std_logic;
		--! Indicate a frame end
		frame_end : out std_logic;

		--! Current sample to be displayed
		currentSample		: in unsigned(7 downto 0);
		--! Last sample to be displayed
		lastSample			: in unsigned(7 downto 0);
		--! Display samples
		display_samples 	: in std_logic;
		--! Display dot samples or lines
		displayDotSamples	: in std_logic;

		--! Channel amplitude
		chAmplitude		: in signed(2 downto 0);
		--! Channel offset
		chOffset		: in unsigned(4 downto 0);
		--! Trigger X position
		triggerXPos		: in unsigned(3 downto 0);
		--! Trigger Y position
		triggerYPos		: in unsigned(3 downto 0);

		--! Display X position
		display_x : out unsigned(c_HDMI_H_BITWIDTH-1 downto 0);

		--! RGB signals
		r,g,b : out std_logic;
		--! HDMI signals
		hsync,vsync,de : out std_logic
	);
end entity video;

architecture rtl of video is
	--! X position of the display
	signal draw_x : unsigned(c_HDMI_H_BITWIDTH-1 downto 0);
	--! Y position of the display
	signal draw_y : unsigned(c_HDMI_V_BITWIDTH-1 downto 0);
	--! Active signal for the display
	signal draw_active : std_logic;
	--! Signal to display the samples
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

	--! Instantiate the video timing generator
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

	--! Instantiate the video signal merger
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