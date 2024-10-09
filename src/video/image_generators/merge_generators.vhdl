-- TerosHDL Documentation:
--! @title Merge Generators
--! @author Pascal Gesell (gesep1 / gfcwfzkm)
--! @version 1.0
--! @date 09.10.2024
--! @brief Merges the different image generators into one image.
--!
--! This module merges the different image generators into one image. The different image generators
--! are the grid generator, the channel generator, and the trigger generator.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity merge_generators is
	generic (
		--! HDMI Horizontal Bitwidth
		c_HDMI_H_BITWIDTH	: positive := 10;
		--! HDMI Vertical Bitwidth
		c_HDMI_V_BITWIDTH	: positive := 10
	);
	port (
		--! X Position of Display
		disp_x				: in unsigned(c_HDMI_H_BITWIDTH-1 downto 0);
		--! Y Position of Display
		disp_y				: in unsigned(c_HDMI_V_BITWIDTH-1 downto 0);

		--! Display active signal
		display_active		: in std_logic;

		--! Display the current sample if true
		display_samples		: in std_logic;

		--! The current sample
		currentSample		: in unsigned(7 downto 0);
		--! The previous sample
		lastSample			: in unsigned(7 downto 0);
		
		--! Display the current sample as a dot or line
		displayDotSamples	: in std_logic;

		--! The amplitude of the channel
		chAmplitude			: in signed(2 downto 0);
		--! The offset of the channel
		chOffset			: in unsigned(4 downto 0);
		--! The trigger x position
		triggerXPos			: in unsigned(3 downto 0);
		--! The trigger y position
		triggerYPos			: in unsigned(3 downto 0);

		--! RGB signals
		red, green, blue : out std_logic
	);
end entity merge_generators;

architecture rtl of merge_generators is
	component Grid_Gen
		port (
			disp_x : in unsigned(c_HDMI_H_BITWIDTH-1 downto 0);
			disp_y : in unsigned(c_HDMI_V_BITWIDTH-1 downto 0);
			grid_active : out std_logic
		);
	end component;

	component channel_gen
		port (
			disp_x : in unsigned(c_HDMI_H_BITWIDTH-1 downto 0);
			disp_y : in unsigned(c_HDMI_V_BITWIDTH-1 downto 0);
			ShowDotInsteadOfLine : in std_logic;
			currentSample : in unsigned(7 downto 0);
			lastSample : in unsigned(7 downto 0);
			chAmplitude : in signed(2 downto 0);
			chOffset : in unsigned(4 downto 0);
			channel : out std_logic;
			offset : out std_logic
		);
	end component;

	component trigger_gen
		port (
			disp_x : in unsigned(c_HDMI_H_BITWIDTH-1 downto 0);
			disp_y : in unsigned(c_HDMI_V_BITWIDTH-1 downto 0);
			triggerXPos :  unsigned(3 downto 0);
			triggerYPos :  unsigned(3 downto 0);
			chOffset : in unsigned(4 downto 0);
			chAmplitude : in signed(2 downto 0);
			trigger_active : out std_logic
		);
	end component;

	--! Active signal for the grid
	signal grid_active		: std_logic;
	--! Active signal for the channel offset
	signal offset_ch_active	: std_logic;
	--! Active signal for the signal channel
	signal signal_ch_gen	: std_logic;
	--! Active signal for the trigger offset
	signal offset_tr_active	: std_logic;
	--! Active signal for the signal channel
	signal signal_ch_active	: std_logic;
begin

	signal_ch_active <= '1' when signal_ch_gen = '1' and display_samples = '1' else '0';

	--! Merge the pixels
	MERGE_PIXELS : process (display_active, grid_active, offset_ch_active, 
							signal_ch_active, offset_tr_active, display_samples) is
	begin
		red <= '0';
		green <= '0';
		blue <= '0';

		-- Only display an active signal, if the display is active
		if display_active = '1' then
			-- Render the channel offset line in cyan
			if offset_ch_active = '1' then
				red <= '1';
				blue <= '1';
			end if;
			-- Render the signal channel in cyan
			if signal_ch_active = '1' then
				red <= '1';
				blue <= '1';
			end if;
			-- Render the trigger offset line in cyan
			if offset_tr_active = '1' then
				red <= '1';
				blue <= '1';
			end if;
			-- Render the grid in yellow
			if grid_active = '1' and offset_ch_active = '0' and
			   signal_ch_active = '0' and offset_tr_active = '0' then
				green <= '1';
				red <= '1';
			end if;
		end if;
	end process MERGE_PIXELS;

	--! Generate the grid
	Grid_Generator : Grid_Gen
		port map (
			disp_x => disp_x,
			disp_y => disp_y,
			grid_active => grid_active
	);

	--! Generate the channel samples and offset
	Channel_Generator : channel_gen
		port map (
			disp_x => disp_x,
			disp_y => disp_y,
			ShowDotInsteadOfLine => displayDotSamples,
			currentSample => currentSample,
			lastSample => lastSample,
			chAmplitude => chAmplitude,
			chOffset => chOffset,
			channel => signal_ch_gen,
			offset => offset_ch_active
	);

	--! Generate the trigger offset
	Trigger_Generator : trigger_gen
		port map (
			disp_x => disp_x,
			disp_y => disp_y,
			triggerXPos => triggerXPos,
			triggerYPos => triggerYPos,
			chOffset => chOffset,
			chAmplitude => chAmplitude,
			trigger_active => offset_tr_active
	);

end architecture;