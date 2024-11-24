-- TerosHDL Documentation:
--! @title Settings Module
--! @author Pascal Gesell (gesep1 / gfcwfzkm)
--! @version 1.0
--! @date 09.10.2024
--! @brief Settings module for the oscilloscope.
--!
--! This module implements the settings module for the oscilloscope. The settings module
--! is used to configure the oscilloscope settings such as the trigger position, amplitude,
--! offset, timebase, memory shift, trigger edge, and display mode.
--!
--! The settings module is controlled by the buttons and switches on the FPGA board.
--! The buttons are used to change the settings, while the switches are used to select
--! the setting to be changed.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity settings is
	port (
		--! Clock signal
		clk   : in std_logic;
		--! Asynchronous, active-high reset
		reset : in std_logic;
		
		--! Sample inputs signal, forwarded to the debouncer to sample the inputs
		sample_inputs : in std_logic;

		--! Buttons input signal
		buttons : in std_logic_vector(3 downto 0);
		--! Switches input signal
		switches : in std_logic_vector(1 downto 0);

		--! Trigger start signal
		trigger_start : out std_logic;
		--! Trigger on rising edge signal (true if the trigger should be on the rising edge)
		triggerOnRisingEdge : out std_logic;
		--! Display samples as dots or lines
		displayDotSamples : out std_logic;

		--! Channel amplitude setting (Shifts the samples left or right)
		chAmplitude : out signed(2 downto 0);
		--! Channel offset setting (moves the samples up or down on the screen)
		chOffset : out unsigned(4 downto 0);
		--! Trigger X position setting (60 pixels per trigger position)
		triggerXPos : out unsigned(2 downto 0);
		--! Trigger Y position setting (16 pixels per trigger position)
		triggerYPos : out unsigned(3 downto 0);
		--! Timebase setting (0: 1x, 1: 1/2x, 2: 1/4x, 3: 1/8x, 4: 1/16x, 5: 1/32x, 6: 1/64x, 7: 1/128x)
		time_base : out unsigned(2 downto 0);
		--! Memory shift setting (Shifts the memory start position to the right or left)
		memoryShift : out signed(8 downto 0);
		--! DSG frequency shift setting (Shifts the DSG frequency up or down)
		dsgFreqShift : out unsigned(1 downto 0);
		--! Waveform selection
		waveform : out unsigned(1 downto 0)
	);
end entity settings;

architecture rtl of settings is
	component debouncer
		port (
		  	clk : in std_logic;
		  	reset : in std_logic;
		  	in_raw : in std_logic;
		  	deb_en : in std_logic;
		  	debounced : out std_logic;
		  	released : out std_logic;
		  	pressed : out std_logic
		);
	end component;

	--! Default Amplitude
	constant AMPLITUDE_DEFAULT : signed(chAmplitude'length-1 downto 0)		:= to_signed(0,		chAmplitude'length);
	--! Minimum Amplitude
	constant AMPLITUDE_MIN : signed(chAmplitude'length-1 downto 0)			:= to_signed(-2,	chAmplitude'length);
	--! Maximum Amplitude
	constant AMPLITUDE_MAX : signed(chAmplitude'length-1 downto 0)			:= to_signed(2,		chAmplitude'length);
	--! Default Offset
	constant OFFSET_DEFAULT : unsigned(chOffset'length-1 downto 0)			:= to_unsigned(4,	chOffset'length);
	--! Maximum Offset
	constant OFFSET_MAX : unsigned(chOffset'length-1 downto 0)				:= to_unsigned(19,	chOffset'length);
	--! Minimum Offset
	constant OFFSET_MIN : unsigned(chOffset'length-1 downto 0)				:= to_unsigned(0,	chOffset'length);
	--! Default Trigger X Position
	constant TRIGGER_X_DEFAULT : unsigned(triggerXPos'length-1 downto 0)	:= to_unsigned(4,	triggerXPos'length);
	--! Maximum Trigger X Position
	constant TRIGGER_X_MAX : unsigned(triggerXPos'length-1 downto 0)		:= to_unsigned(7,	triggerXPos'length);
	--! Minimum Trigger X Position
	constant TRIGGER_X_MIN : unsigned(triggerXPos'length-1 downto 0)		:= to_unsigned(0,	triggerXPos'length);
	--! Default Trigger Y Position
	constant TRIGGER_Y_DEFAULT : unsigned(triggerYPos'length-1 downto 0)	:= to_unsigned(3,	triggerYPos'length);
	--! Maximum Trigger Y Position
	constant TRIGGER_Y_MAX : unsigned(triggerYPos'length-1 downto 0)		:= to_unsigned(15,	triggerYPos'length);
	--! Minimum Trigger Y Position
	constant TRIGGER_Y_MIN : unsigned(triggerYPos'length-1 downto 0)		:= to_unsigned(0,	triggerYPos'length);
	--! Default time base
	constant TIME_BASE_DEFAULT : unsigned(time_base'length-1 downto 0)		:= to_unsigned(0,	time_base'length);
	--! Maximum time base
	constant TIME_BASE_MAX : unsigned(time_base'length-1 downto 0)			:= to_unsigned(7,	time_base'length);
	--! Minimum time base
	constant TIME_BASE_MIN : unsigned(time_base'length-1 downto 0)			:= to_unsigned(0,	time_base'length);
	--! Default Memory Shift
	constant MEMORY_SHIFT_DEFAULT : signed(memoryShift'length-1 downto 0)	:= to_signed(0,		memoryShift'length);
	--! Maximum Memory Shift
	constant MEMORY_SHIFT_MAX : signed(memoryShift'length-1 downto 0)		:= to_signed(255,	memoryShift'length);
	--! Minimum Memory Shift
	constant MEMORY_SHIFT_MIN : signed(memoryShift'length-1 downto 0)		:= to_signed(-255,	memoryShift'length);
	--! Default DSG Frequency Shift
	constant DSG_FREQ_SHIFT_DEFAULT : unsigned(dsgFreqShift'length-1 downto 0) := to_unsigned(0, dsgFreqShift'length);
	--! Maximum DSG Frequency Shift
	constant DSG_FREQ_SHIFT_MAX : unsigned(dsgFreqShift'length-1 downto 0) := to_unsigned(3, dsgFreqShift'length);
	--! Minimum DSG Frequency Shift
	constant DSG_FREQ_SHIFT_MIN : unsigned(dsgFreqShift'length-1 downto 0) := to_unsigned(0, dsgFreqShift'length);
	--! Waveform Default Setting on Sine
	constant WAVEFORM_DEFAULT : unsigned(1 downto 0) := "00";
	--! Waveform Maximum Setting
	constant WAVEFORM_MAX : unsigned(1 downto 0) := "11";
	--! Waveform Minimum Setting
	constant WAVEFORM_MIN : unsigned(1 downto 0) := "00";
	--! Default Trigger on Rising Edge
	constant TRIGGER_ON_RISING_EDGE_DEFAULT : std_logic	:= '1';
	--! Default Display Dot Samples
	constant DISPLAY_DOT_SAMPLES_DEFAULT : std_logic	:= '0';

	--! Button Layout 1
	constant BTN_LAYOUT_1 : std_logic_vector(1 downto 0) := "00";
	--! Button Layout 2
	constant BTN_LAYOUT_2 : std_logic_vector(1 downto 0) := "01";
	--! Button Layout 3
	constant BTN_LAYOUT_3 : std_logic_vector(1 downto 0) := "10";
	--! Button Layout 4
	constant BTN_LAYOUT_4 : std_logic_vector(1 downto 0) := "11";

	--! Debounced buttons pressed signal
	signal debounced_buttons_pressed : std_logic_vector(3 downto 0);
	--! Debounced switches signal
	signal debounced_switches : std_logic_vector(1 downto 0);

	--! Register for the amplitude setting
	signal chAmplitude_reg, chAmplitude_next : signed(chAmplitude'length-1 downto 0);
	--! Register for the offset setting
	signal chOffset_reg, chOffset_next : unsigned(chOffset'length-1 downto 0);
	--! Register for the trigger X position setting
	signal triggerXPos_reg, triggerXPos_next : unsigned(triggerXPos'length-1 downto 0);
	--! Register for the trigger Y position setting
	signal triggerYPos_reg, triggerYPos_next : unsigned(triggerYPos'length-1 downto 0);
	--! Register for the time_base setting
	signal time_base_reg, time_base_next : unsigned(time_base'length-1 downto 0);
	--! Register for the memory shift setting
	signal memoryShift_reg, memoryShift_next : signed(memoryShift'length-1 downto 0);
	--! Register for the trigger on rising edge setting
	signal triggerOnRisingEdge_reg, triggerOnRisingEdge_next : std_logic;
	--! Register for the DSG frequency setting
	signal dsgFreqShift_reg, dsgFreqShift_next : unsigned(dsgFreqShift'length-1 downto 0);
	--! Selected Waveform
	signal selectedWaveform_reg, selectedWaveform_next : unsigned(1 downto 0);

	--! Syncronizing signals for the buttons and switches
	signal button_ff_stage_1_reg, button_ff_stage_1_next : std_logic_vector(3 downto 0);
	signal button_ff_stage_2_reg, button_ff_stage_2_next : std_logic_vector(3 downto 0);
	signal switches_ff_stage_1_reg, switches_ff_stage_1_next : std_logic_vector(1 downto 0);
	signal switches_ff_stage_2_reg, switches_ff_stage_2_next : std_logic_vector(1 downto 0);
begin

	--! Clocked registers for the settings
	CLKREG : process(clk, reset) is
	begin
		if reset = '1' then
			chAmplitude_reg <= AMPLITUDE_DEFAULT;
			chOffset_reg <=OFFSET_DEFAULT;
			triggerXPos_reg <= TRIGGER_X_DEFAULT;
			triggerYPos_reg <= TRIGGER_Y_DEFAULT;
			time_base_reg <= TIME_BASE_DEFAULT;
			memoryShift_reg <= MEMORY_SHIFT_DEFAULT;
			triggerOnRisingEdge_reg <= TRIGGER_ON_RISING_EDGE_DEFAULT;
			dsgFreqShift_reg <= DSG_FREQ_SHIFT_DEFAULT;
			selectedWaveform_reg <= WAVEFORM_DEFAULT;
			button_ff_stage_1_reg <= (others => '0');
			button_ff_stage_2_reg <= (others => '0');
			switches_ff_stage_1_reg <= (others => '0');
			switches_ff_stage_2_reg <= (others => '0');
		elsif rising_edge(clk) then
			chAmplitude_reg <= chAmplitude_next;
			chOffset_reg <= chOffset_next;
			triggerXPos_reg <= triggerXPos_next;
			triggerYPos_reg <= triggerYPos_next;
			time_base_reg <= time_base_next;
			memoryShift_reg <= memoryShift_next;
			triggerOnRisingEdge_reg <= triggerOnRisingEdge_next;
			dsgFreqShift_reg <= dsgFreqShift_next;
			selectedWaveform_reg <= selectedWaveform_next;
			button_ff_stage_1_reg <= button_ff_stage_1_next;
			button_ff_stage_2_reg <= button_ff_stage_2_next;
			switches_ff_stage_1_reg <= switches_ff_stage_1_next;
			switches_ff_stage_2_reg <= switches_ff_stage_2_next;
		end if;
	end process CLKREG;

	--! State machine process for the settings
	NSL : process(debounced_buttons_pressed, debounced_switches, chAmplitude_reg, chOffset_reg, triggerXPos_reg,
				  triggerYPos_reg, time_base_reg, memoryShift_reg, triggerOnRisingEdge_reg, dsgFreqShift_reg, selectedWaveform_reg) is
	begin
		chAmplitude_next <= chAmplitude_reg;
		chOffset_next <= chOffset_reg;
		triggerXPos_next <= triggerXPos_reg;
		triggerYPos_next <= triggerYPos_reg;
		time_base_next <= time_base_reg;
		memoryShift_next <= memoryShift_reg;
		triggerOnRisingEdge_next <= triggerOnRisingEdge_reg;
		dsgFreqShift_next <= dsgFreqShift_reg;
		selectedWaveform_next <= selectedWaveform_reg;
		trigger_start <= '0';

		case debounced_switches is
			when BTN_LAYOUT_1 =>
				if debounced_buttons_pressed(0) = '1' then
					-- Button 0: Trigger up
					if triggerYPos_reg /= TRIGGER_Y_MAX then
						triggerYPos_next <= triggerYPos_reg + 1;
					end if;
				elsif debounced_buttons_pressed(1) = '1' then
					-- Button 1: Trigger down
					if triggerYPos_reg /= TRIGGER_Y_MIN then
						triggerYPos_next <= triggerYPos_reg - 1;
					end if;
				elsif debounced_buttons_pressed(2) = '1' then
					-- Button 2: Shift trigger point to the right
					if triggerXPos_reg /= TRIGGER_X_MAX then
						triggerXPos_next <= triggerXPos_reg + 1;
					else
						triggerXPos_next <= TRIGGER_X_MIN;
					end if;
				elsif debounced_buttons_pressed(3) = '1' then
					-- Button 3: Trigger on rising / falling edge
					triggerOnRisingEdge_next <= not triggerOnRisingEdge_reg;
				end if;
			when BTN_LAYOUT_2 =>
				if debounced_buttons_pressed(0) = '1' then
					-- Button 0: Zoom in
					if chAmplitude_reg /= AMPLITUDE_MAX then
						chAmplitude_next <= chAmplitude_reg + 1;
					end if;
				elsif debounced_buttons_pressed(1) = '1' then
					-- Button 1: Zoom out
					if chAmplitude_reg /= AMPLITUDE_MIN then
						chAmplitude_next <= chAmplitude_reg - 1;
					end if;
				elsif debounced_buttons_pressed(2) = '1' then
					-- Button 2: Offset up
					if chOffset_reg /= OFFSET_MAX then
						chOffset_next <= chOffset_reg + 1;
					end if;
				elsif debounced_buttons_pressed(3) = '1' then
					-- Button 3: Offset down
					if chOffset_reg /= OFFSET_MIN then
						chOffset_next <= chOffset_reg - 1;
					end if;
				end if;
			when BTN_LAYOUT_3 =>
				if debounced_buttons_pressed(0) = '1' then
					-- Button 0: Timebase up
					if time_base_reg /= TIME_BASE_MAX then
						time_base_next <= time_base_reg + 1;
					end if;
				elsif debounced_buttons_pressed(1) = '1' then
					-- Button 1: Timebase down
					if time_base_reg /= TIME_BASE_MIN then
						time_base_next <= time_base_reg - 1;
					end if;
				elsif debounced_buttons_pressed(2) = '1' then
					-- Button 2: Memory shift up/right
					if memoryShift_reg /= MEMORY_SHIFT_MAX then
						memoryShift_next <= memoryShift_reg + 1;
					end if;
				elsif debounced_buttons_pressed(3) = '1' then
					-- Button 3: Memory shift down/left
					if memoryShift_reg /= MEMORY_SHIFT_MIN then
						memoryShift_next <= memoryShift_reg - 1;
					end if;
				end if;
			when BTN_LAYOUT_4 =>
				if debounced_buttons_pressed(0) = '1' then
					-- Trigger Start / Stop
					trigger_start <= '1';
					-- Reset the memory shift if the trigger is started
					memoryShift_next <= MEMORY_SHIFT_DEFAULT;
				elsif debounced_buttons_pressed(1) = '1' then
					-- Waveform select
					if selectedWaveform_reg /= WAVEFORM_MAX then
						selectedWaveform_next <= selectedWaveform_reg + 1;
					else
						selectedWaveform_next <= WAVEFORM_MIN;
					end if;
				elsif debounced_buttons_pressed(2) = '1' then
					-- Increase Frequency
					if dsgFreqShift_reg /= DSG_FREQ_SHIFT_MAX then
						dsgFreqShift_next <= dsgFreqShift_reg + 1;
					end if;
				elsif debounced_buttons_pressed(3) = '1' then
					-- Decrease Frequency
					if dsgFreqShift_reg /= DSG_FREQ_SHIFT_MIN then
						dsgFreqShift_next <= dsgFreqShift_reg - 1;
					end if;
				end if;
			when others =>
				null;
		end case;
	end process NSL;

	-- Output the register values
	chAmplitude <= chAmplitude_reg;
	chOffset <= chOffset_reg;
	triggerXPos <= triggerXPos_reg;
	triggerYPos <= triggerYPos_reg;
	time_base <= time_base_reg;
	memoryShift <= memoryShift_reg;
	triggerOnRisingEdge <= triggerOnRisingEdge_reg;
	displayDotSamples <= DISPLAY_DOT_SAMPLES_DEFAULT;
	dsgFreqShift <= dsgFreqShift_reg;
	waveform <= selectedWaveform_reg;

	-- Syncronize the buttons and switches
	button_ff_stage_1_next <= buttons;
	button_ff_stage_2_next <= button_ff_stage_1_reg;
	switches_ff_stage_1_next <= switches;
	switches_ff_stage_2_next <= switches_ff_stage_1_reg;

	--! Debounce the buttons
	BUTTON_DEBOUNCER : for i in 0 to 3 generate
		DEBOUNCE_BUTTONS : debouncer
		port map (
			clk => clk,
			reset => reset,
			in_raw => button_ff_stage_2_reg(i),
			deb_en => sample_inputs,
			debounced => open,
			released => open,
			pressed => debounced_buttons_pressed(i)
		);
	end generate;

	--! Debounce the switches
	SWITCH_DEBOUNCER : for i in 0 to 1 generate
		DEBOUNCE_SWITCHES : debouncer
		port map (
			clk => clk,
			reset => reset,
			in_raw => switches_ff_stage_2_reg(i),
			deb_en => sample_inputs,
			debounced => debounced_switches(i),
			released => open,
			pressed => open
		);
	end generate;

end architecture;