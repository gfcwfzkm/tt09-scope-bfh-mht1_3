library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity merge_generators is
	generic (
		c_HDMI_H_BITWIDTH	: positive := 10;
		c_HDMI_V_BITWIDTH	: positive := 10
	);
	port (
		--! X Position of Display
		disp_x		: in unsigned(c_HDMI_H_BITWIDTH-1 downto 0);
		--! Y Position of Display
		disp_y		: in unsigned(c_HDMI_V_BITWIDTH-1 downto 0);

		--! Display active signal
		display_active : in std_logic;

		--! Display the current sample if true
		display_samples : in std_logic;

		--! The current sample
		currentSample : in unsigned(7 downto 0);
		--! The previous sample
		lastSample : in unsigned(7 downto 0);

		--! The amplitude of the channel
		chAmplitude : in signed(2 downto 0);
		--! The offset of the channel
		chOffset : in unsigned(4 downto 0);
		--! The trigger x position
		triggerXPos :  unsigned(3 downto 0);
		--! The trigger y position
		triggerYPos :  unsigned(3 downto 0);

		red		: out std_logic;
		green	: out std_logic;
		blue	: out std_logic
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
			trigger_active : out std_logic
		);
	end component;

	signal grid_active		: std_logic;
	signal offset_ch_active	: std_logic;
	signal signal_ch_active	: std_logic;
	signal offset_tr_active	: std_logic;
begin

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
			if signal_ch_active = '1' and display_samples = '1' then
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

	Grid_Generator : Grid_Gen
		port map (
			disp_x => disp_x,
			disp_y => disp_y,
			grid_active => grid_active
	);

	Channel_Generator : channel_gen
		port map (
			disp_x => disp_x,
			disp_y => disp_y,
			ShowDotInsteadOfLine => '1',
			currentSample => currentSample,
			lastSample => lastSample,
			chAmplitude => chAmplitude,
			chOffset => chOffset,
			channel => signal_ch_active,
			offset => offset_ch_active
	);

	Trigger_Generator : trigger_gen
		port map (
			disp_x => disp_x,
			disp_y => disp_y,
			triggerXPos => triggerXPos,
			triggerYPos => triggerYPos,
			chOffset => chOffset,
			trigger_active => offset_tr_active
	);

end architecture;