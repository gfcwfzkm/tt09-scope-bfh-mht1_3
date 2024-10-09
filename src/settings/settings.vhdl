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
		--! Trigger X position setting (32 pixels per trigger position)
		triggerXPos : out unsigned(3 downto 0);
		--! Trigger Y position setting (16 pixels per trigger position)
		triggerYPos : out unsigned(3 downto 0);
		--! Timebase setting (0: 1x, 1: 1/2x, 2: 1/4x, 3: 1/8x, 4: 1/16x, 5: 1/32x, 6: 1/64x, 7: 1/128x)
		timebase : out unsigned(2 downto 0);
		--! Memory shift setting (Shifts the memory start position to the right or left)
		memoryShift : out signed(7 downto 0)
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
	constant TRIGGER_X_DEFAULT : unsigned(triggerXPos'length-1 downto 0)	:= to_unsigned(8,	triggerXPos'length);
	--! Maximum Trigger X Position
	constant TRIGGER_X_MAX : unsigned(triggerXPos'length-1 downto 0)		:= to_unsigned(15,	triggerXPos'length);
	--! Minimum Trigger X Position
	constant TRIGGER_X_MIN : unsigned(triggerXPos'length-1 downto 0)		:= to_unsigned(0,	triggerXPos'length);
	--! Default Trigger Y Position
	constant TRIGGER_Y_DEFAULT : unsigned(triggerYPos'length-1 downto 0)	:= to_unsigned(4,	triggerYPos'length);
	--! Maximum Trigger Y Position
	constant TRIGGER_Y_MAX : unsigned(triggerYPos'length-1 downto 0)		:= to_unsigned(15,	triggerYPos'length);
	--! Minimum Trigger Y Position
	constant TRIGGER_Y_MIN : unsigned(triggerYPos'length-1 downto 0)		:= to_unsigned(0,	triggerYPos'length);
	--! Default Timebase
	constant TIMEBASE_DEFAULT : unsigned(timebase'length-1 downto 0)		:= to_unsigned(0,	timebase'length);
	--! Maximum Timebase
	constant TIMEBASE_MAX : unsigned(timebase'length-1 downto 0)			:= to_unsigned(7,	timebase'length);
	--! Minimum Timebase
	constant TIMEBASE_MIN : unsigned(timebase'length-1 downto 0)			:= to_unsigned(0,	timebase'length);
	--! Default Memory Shift
	constant MEMORY_SHIFT_DEFAULT : signed(memoryShift'length-1 downto 0)	:= to_signed(0,		memoryShift'length);
	--! Maximum Memory Shift
	constant MEMORY_SHIFT_MAX : signed(memoryShift'length-1 downto 0)		:= to_signed(127,	memoryShift'length);
	--! Minimum Memory Shift
	constant MEMORY_SHIFT_MIN : signed(memoryShift'length-1 downto 0)		:= to_signed(-127,	memoryShift'length);
	--! Default Trigger on Rising Edge
	constant TRIGGER_ON_RISING_EDGE_DEFAULT : std_logic	:= '1';
	--! Default Display Dot Samples
	constant DISPLAY_DOT_SAMPLES_DEFAULT : std_logic	:= '1';

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
	--! Register for the timebase setting
	signal timebase_reg, timebase_next : unsigned(timebase'length-1 downto 0);
	--! Register for the memory shift setting
	signal memoryShift_reg, memoryShift_next : signed(memoryShift'length-1 downto 0);
	--! Register for the trigger on rising edge setting
	signal triggerOnRisingEdge_reg, triggerOnRisingEdge_next : std_logic;
	--! Register for the display dot samples setting
	signal displayDotSamples_reg, displayDotSamples_next : std_logic;
begin

	--! Clocked registers for the settings
	CLKREG : process(clk, reset) is
	begin
		if reset = '1' then
			chAmplitude_reg <= AMPLITUDE_DEFAULT;
			chOffset_reg <=OFFSET_DEFAULT;
			triggerXPos_reg <= TRIGGER_X_DEFAULT;
			triggerYPos_reg <= TRIGGER_Y_DEFAULT;
			timebase_reg <= TIMEBASE_DEFAULT;
			memoryShift_reg <= MEMORY_SHIFT_DEFAULT;
			triggerOnRisingEdge_reg <= TRIGGER_ON_RISING_EDGE_DEFAULT;
			displayDotSamples_reg <= DISPLAY_DOT_SAMPLES_DEFAULT;
		elsif rising_edge(clk) then
			chAmplitude_reg <= chAmplitude_next;
			chOffset_reg <= chOffset_next;
			triggerXPos_reg <= triggerXPos_next;
			triggerYPos_reg <= triggerYPos_next;
			timebase_reg <= timebase_next;
			memoryShift_reg <= memoryShift_next;
			triggerOnRisingEdge_reg <= triggerOnRisingEdge_next;
			displayDotSamples_reg <= displayDotSamples_next;
		end if;
	end process CLKREG;

	--! State machine process for the settings
	NSL : process(debounced_buttons_pressed, debounced_switches, chAmplitude_reg, chOffset_reg, triggerXPos_reg,
				  triggerYPos_reg, timebase_reg, memoryShift_reg, triggerOnRisingEdge_reg, displayDotSamples_reg) is
	begin
		chAmplitude_next <= chAmplitude_reg;
		chOffset_next <= chOffset_reg;
		triggerXPos_next <= triggerXPos_reg;
		triggerYPos_next <= triggerYPos_reg;
		timebase_next <= timebase_reg;
		memoryShift_next <= memoryShift_reg;
		triggerOnRisingEdge_next <= triggerOnRisingEdge_reg;
		displayDotSamples_next <= displayDotSamples_reg;
		trigger_start <= '0';

		case debounced_switches is
			when "00" =>
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
					-- Button 2: Trigger left
					if triggerXPos_reg /= TRIGGER_X_MAX then
						triggerXPos_next <= triggerXPos_reg + 1;
					end if;
				elsif debounced_buttons_pressed(3) = '1' then
					-- Button 3: Trigger right
					if triggerXPos_reg /= TRIGGER_X_MIN then
						triggerXPos_next <= triggerXPos_reg - 1;
					end if;
				end if;
			when "01" =>
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
			when "10" =>
				if debounced_buttons_pressed(0) = '1' then
					-- Button 0: Timebase up
					if timebase_reg /= TIMEBASE_MAX then
						timebase_next <= timebase_reg + 1;
					end if;
				elsif debounced_buttons_pressed(1) = '1' then
					-- Button 1: Timebase down
					if timebase_reg /= TIMEBASE_MIN then
						timebase_next <= timebase_reg - 1;
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
			when "11" =>
				if debounced_buttons_pressed(0) = '1' then
					-- Trigger Start / Stop
					trigger_start <= '1';
				elsif debounced_buttons_pressed(1) = '1' then
					-- Trigger on rising or falling edge
					triggerOnRisingEdge_next <= not triggerOnRisingEdge_reg;
				elsif debounced_buttons_pressed(2) = '1' then
					-- Display samples as dots or lines
					displayDotSamples_next <= not displayDotSamples_reg;
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
	timebase <= timebase_reg;
	memoryShift <= memoryShift_reg;
	triggerOnRisingEdge <= triggerOnRisingEdge_reg;
	displayDotSamples <= displayDotSamples_reg;

	--! Debounce the buttons
	BUTTON_DEBOUNCER : for i in 0 to 3 generate
		DEBOUNCE_BUTTONS : debouncer
		port map (
			clk => clk,
			reset => reset,
			in_raw => buttons(i),
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
			in_raw => switches(i),
			deb_en => sample_inputs,
			debounced => debounced_switches(i),
			released => open,
			pressed => open
		);
	end generate;

end architecture;