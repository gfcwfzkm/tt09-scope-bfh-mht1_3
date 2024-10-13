-- TerosHDL Documentation:
--! @title Oscilloscope Top Module
--! @author Pascal Gesell (gesep1 / gfcwfzkm)
--! @version 1.0
--! @date 09.10.2024
--! @brief Top module for the oscilloscope.
--!
--! Tiny Tapeout Oscilloscope Top Module
--!

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
			display_samples : in std_logic;
			displayDotSamples	: in std_logic;
			chAmplitude : in signed(2 downto 0);
			chOffset : in unsigned(4 downto 0);
			triggerXPos : in unsigned(2 downto 0);
			triggerYPos : in unsigned(3 downto 0);
			display_x : out unsigned(9 downto 0);
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
			triggerOnRisingEdge : out std_logic;
			displayDotSamples : out std_logic;
			chAmplitude : out signed(2 downto 0);
			chOffset : out unsigned(4 downto 0);
			triggerXPos : out unsigned(2 downto 0);
			triggerYPos : out unsigned(3 downto 0);
			timebase : out unsigned(2 downto 0);
			memoryShift : out signed(8 downto 0);
			dsgFreqShift : out unsigned(1 downto 0);
			waveform : out unsigned(1 downto 0)
		);
	end component;

	component measurement_sm
		port (
			clk : in std_logic;
			reset : in std_logic;
			trigger_start : in std_logic;
			frame_end : in std_logic;
			line_end : in std_logic;
			triggerXPos : in unsigned(2 downto 0);
			triggerYPos : in unsigned(3 downto 0);
			timebase : in unsigned(2 downto 0);
			memoryShift : in signed(8 downto 0);
			display_x : in unsigned(9 downto 0);
			triggerOnRisingEdge : in std_logic;
			display_samples : out std_logic;
			current_sample : out unsigned(7 downto 0);
			last_sample : out unsigned(7 downto 0);
			fram_cs : out std_logic;
			fram_sclk : out std_logic;
			fram_mosi : out std_logic;
			fram_miso : in std_logic;
			adc_cs : out std_logic;
			adc_sclk : out std_logic;
			adc_miso : in std_logic;
			error_occurred	: out std_logic
		);
	end component;

	component signal_gen
		port (
			clk : in std_logic;
			reset : in std_logic;
			SigGenFrequency : in unsigned(1 downto 0);
			SigWaveSelect : in unsigned(1 downto 0);
			da_cs : out std_logic;
			da_sclk : out std_logic;
			da_mosi : out std_logic
		);
	end component;

	signal reset          : std_logic;
	signal display_samples : std_logic;
	signal frame_end	  : std_logic;
	signal line_end		  : std_logic;

	signal trigger_start : std_logic;
	signal chAmplitude	  : signed(2 downto 0);
	signal chOffset		  : unsigned(4 downto 0);
	signal triggerXPos	  : unsigned(2 downto 0);
	signal triggerYPos	  : unsigned(3 downto 0);
	signal timebase		  : unsigned(2 downto 0);
	signal memoryShift	  : signed(8 downto 0);
	signal triggerOnRisingEdge : std_logic;
	signal displayDotSamples : std_logic;
	signal dsgFreqShift : unsigned(1 downto 0);
	signal waveform : unsigned(1 downto 0);

	signal display_x : unsigned(9 downto 0);

	signal currentSample : unsigned(7 downto 0);
	signal lastSample	: unsigned(7 downto 0);
	signal buttons		: std_logic_vector(3 downto 0);
	signal switches		: std_logic_vector(1 downto 0);
begin

	-- Make the reset active-high
	reset <= not rst_n;

	-- Set the bidirectional IOs to outputs
	uio_oe <= "11111111";

	buttons(0) <= ui_in(1);
	buttons(1) <= ui_in(5);
	buttons(2) <= ui_in(2);
	buttons(3) <= ui_in(6);
	switches(0) <= ui_in(3);
	switches(1) <= ui_in(7);
	
	--! Video Generator Entity, attached to a 1bpp HDMI Pmod
	VIDEOGEN : video
		port map (
			clk			=> clk,
			reset		=> reset,
			line_end	=> line_end,
			frame_end	=> frame_end,
			currentSample => currentSample,
			lastSample	=> lastSample,
			display_samples => display_samples,
			displayDotSamples => displayDotSamples,
			chAmplitude	=> chAmplitude,
			chOffset	=> chOffset,
			triggerXPos	=> triggerXPos,
			triggerYPos	=> triggerYPos,
			display_x	=> display_x,
			r			=> uo_out(4),
			g			=> uo_out(0),
			b			=> uo_out(5),
			hsync		=> uo_out(2),
			vsync		=> uo_out(7),
			de			=> uo_out(6)
	);
	uo_out(1) <= clk;	-- HDMI Clock

	--! Settings Entity, attached to the buttons and switches
	OSCILLOSCOPE_CONTROL : settings
		port map (
			clk			=> clk,
			reset		=> reset,
			sample_inputs => frame_end,
			buttons		=> buttons,
			switches	=> switches,
			trigger_start => trigger_start,
			triggerOnRisingEdge => triggerOnRisingEdge,
			displayDotSamples => displayDotSamples,
			chAmplitude	=> chAmplitude,
			chOffset	=> chOffset,
			triggerXPos	=> triggerXPos,
			triggerYPos	=> triggerYPos,
			timebase	=> timebase,
			memoryShift	=> memoryShift,
			dsgFreqShift => dsgFreqShift,
			waveform	=> waveform
	);

	--! Measurement State Machine Entity, attached to the ADC and FRAM
	MEASUREMENTS : measurement_sm
		port map (
			clk			=> clk,
			reset		=> reset,
			trigger_start => trigger_start,
			frame_end	=> frame_end,
			line_end	=> line_end,
			triggerXPos	=> triggerXPos,
			triggerYPos	=> triggerYPos,
			timebase	=> timebase,
			memoryShift	=> memoryShift,
			display_x	=> display_x,
			triggerOnRisingEdge => triggerOnRisingEdge,
			display_samples => display_samples,
			current_sample => currentSample,
			last_sample	=> lastSample,
			fram_cs		=> uio_out(6),
			fram_sclk	=> uio_out(3),
			fram_mosi	=> uio_out(7),
			fram_miso	=> ui_in(0),
			adc_cs		=> uio_out(0),
			adc_sclk	=> uio_out(2),
			adc_miso	=> ui_in(4),
			error_occurred => uo_out(3)
	);

	--! Signal Generator Entity, attached to the DAC
	SIGGEN : signal_gen
		port map (
			clk				=> clk,
			reset			=> reset,
			SigGenFrequency => dsgFreqShift,
			SigWaveSelect	=> waveform,
			da_cs			=> uio_out(4),
			da_sclk			=> uio_out(5),
			da_mosi			=> uio_out(1)
	);

end Behavioral;