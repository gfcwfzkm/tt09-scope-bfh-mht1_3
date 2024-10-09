-- TerosHDL Documentation:
--! @title Measurement State Machine
--! @author Pascal Gesell (gesep1 / gfcwfzkm)
--! @version 1.0
--! @date 09.10.2024
--! @brief State machine to control the measurement process.
--!
--! This module controls the measurement process of the oscilloscope. 
--! It reads the samples from the ADC and writes them to the FRAM when a single-shot measurement is triggered.
--! Otherwise the samples are read from the FRAM and displayed on the screen.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity measurement_sm is
	port (
		--! Clock signal
		clk   : in std_logic;
		--! Ansynchronous, active-high reset
		reset : in std_logic;
		
		--! Trigger signal to start the measurement process
		trigger_start	: in std_logic;
		--! Image frame end signal
		frame_end		: in std_logic;
		--! Image line end signal
		line_end		: in std_logic;
		--! Trigger X position, multiplied by 32 if applied onto the screen / sample
		triggerXPos		: in unsigned(3 downto 0);
		--! Trigger Y position, multiplied by 16 if applied onto the screen / sample
		triggerYPos		: in unsigned(3 downto 0);
		--! Timebase of the oscilloscope
		timebase		: in unsigned(2 downto 0);
		--! Shift of the memory to display the samples
		memoryShift		: in signed(7 downto 0);
		--! Current display position in the horizontal direction
		display_x		: in unsigned(9 downto 0);
		--! Trigger on the rising or falling edge of the signal
		triggerOnRisingEdge : in std_logic;

		--! Signal to toggle if the samples should be displayed
		display_samples : out std_logic;
		--! Current sample to be displayed
		current_sample	: out unsigned(7 downto 0);
		--! Last sample to be displayed
		last_sample		: out unsigned(7 downto 0);

		--! FRAM Chip Select
		fram_cs			: out std_logic;
		--! FRAM Serial Clock
		fram_sclk		: out std_logic;
		--! FRAM Master Out Slave In
		fram_mosi		: out std_logic;
		--! FRAM Master In Slave Out
		fram_miso		: in std_logic;

		--! ADC Chip Select
		adc_cs			: out std_logic;
		--! ADC Serial Clock
		adc_sclk		: out std_logic;
		--! ADC Master In Slave Out
		adc_miso		: in std_logic
	);
end entity measurement_sm;

architecture rtl of measurement_sm is
	component trigger_detection
		port (
			last_sample : in unsigned(3 downto 0);
			current_sample : in unsigned(3 downto 0);
			trigger_threshold : in unsigned(3 downto 0);
			sample_on_rising_edge : in std_logic;
			triggered : out std_logic
		);
	end component;
	
	component pmodAD1
		port (
			clk : in std_logic;
			reset : in std_logic;
			start : in std_logic;
			busy : out std_logic;
			data : out std_logic_vector(7 downto 0);
			sclk : out std_logic;
			miso : in std_logic;
			cs_n : out std_logic
		);
	end component;

	component fram
		port (
			clk : in std_logic;
			reset : in std_logic;
			start_read_single : in std_logic;
			start_write_single : in std_logic;
			start_read_multiple : in std_logic;
			start_write_multiple : in std_logic;
			another_m_rw_exchange : in std_logic;
			close_m_rw_exchange : in std_logic;
			fram_busy : out std_logic;
			request_m_next_data : out std_logic;
			fram_address : in std_logic_vector(14 downto 0);
			data_to_fram : in std_logic_vector(7 downto 0);
			data_from_fram : out std_logic_vector(7 downto 0);
			fram_cs_n : out std_logic;
			fram_sck : out std_logic;
			fram_mosi : out std_logic;
			fram_miso : in std_logic
		);
	end component;

	--! Default trigger X position
	constant TRIGGER_X_DEFAULT : unsigned(triggerXPos'length-1 downto 0) := to_unsigned(8, triggerXPos'length);
	--! Display X maximum value
	constant DISPLAY_X_MAX : unsigned(display_x'length-1 downto 0) := to_unsigned(480, display_x'length);

	--! State machine states
	type state_type is (
		INIT,				--! Initialization state
		WAIT_FOR_LINEEND,	--! Wait for the end of the line
		READ_FROM_FRAM		--! Read samples from the FRAM to display them
	);

	--! Calculated display X position (display_x << timebase + 1 << timebase)
	signal display_x_calced			: unsigned(14 downto 0);
	--! Calculated sample address (sample_start_address + display_x_calced)
	signal sample_address_calced	: unsigned(14 downto 0);
	--! Current start address of the samples in the FRAM
	signal sample_start_address_reg, sample_start_address_next : unsigned(14 downto 0);
	--! Last read sample from the FRAM
	signal last_sample_reg, last_sample_next : unsigned(7 downto 0);
	--! Current state of the state machine
	signal state_reg, state_next : state_type;

	--! ADC Busy signal (1 = busy)
	signal adc_isBusy				: std_logic;
	--! ADC Start signal (1 = start)
	signal adc_start			: std_logic;
	--! Sample from the ADC (unsigned)
	signal sample_from_adc		: unsigned(7 downto 0);
	--! Sample from the ADC (std_logic_vector)
	signal sample_from_adc_slv	: std_logic_vector(7 downto 0);

	--! FRAM Busy signal (1 = busy)
	signal fram_isBusy				: std_logic;
	--! FRAM Read single byte signal (1 = read)
	signal fram_readSample			: std_logic;
	--! FRAM Write multiple samples signal (1 = write)
	signal fram_writeSamples		: std_logic;
	--! FRAM Write next sample signal (1 = write)
	signal fram_writeNextSample		: std_logic;
	--! FRAM Done writing signal (1 = done)
	signal fram_doneWriting			: std_logic;
	--! FRAM requesting more data to write, or done/cancelation of the write (1 = more to write)
	signal fram_isThereMoreToWrite	: std_logic;
	--! Sample from the FRAM (unsigned)
	signal sample_from_fram			: unsigned(7 downto 0);
	--! Sample from the FRAM (std_logic_vector)
	signal sample_from_fram_slv		: std_logic_vector(7 downto 0);
	--! FRAM Address to read/write from/to
	signal fram_address				: std_logic_vector(14 downto 0);
begin

	--! Register process and reset logic
	CLKREG : process(clk, reset) is begin
		if reset = '1' then
			last_sample_reg <= (others => '0');
			sample_start_address_reg <= (others => '0');
			state_reg <= INIT;
		elsif rising_edge(clk) then
			last_sample_reg <= last_sample_next;
			sample_start_address_reg <= sample_start_address_next;
			state_reg <= state_next;
		end if;
	end process CLKREG;

	--! State machine process
	STATEMACHINE : process (state_reg, last_sample_reg, line_end, sample_from_fram, sample_start_address_reg, fram_isBusy, fram_isThereMoreToWrite, display_x) is
	begin
		state_next <= state_reg;
		last_sample_next <= last_sample_reg;
		sample_start_address_next <= sample_start_address_reg;
		fram_readSample <= '0';

		case state_reg is
			when INIT =>
				state_next <= WAIT_FOR_LINEEND;

			when WAIT_FOR_LINEEND =>
				if line_end = '1' then
					fram_readSample <= '1';
					last_sample_next <= sample_from_fram;
					state_next <= READ_FROM_FRAM;
				end if;
			when READ_FROM_FRAM =>
				if fram_isBusy = '0' then
					if display_x = DISPLAY_X_MAX then
						last_sample_next <= sample_from_fram;
					end if;
					state_next <= WAIT_FOR_LINEEND;
				end if;
		end case;
	end process STATEMACHINE;

	-- Calculate the address of the sample to be read from the FRAM with the current timebase and display position
	display_x_calced <= shift_left(resize(display_x, display_x_calced'length), to_integer(timebase)) + shift_left(to_unsigned(1, display_x_calced'length), to_integer(timebase));

	-- Final calculation of the sample address, unless the display position is over the end of the display - then the address is the same as the start address
	sample_address_calced <= sample_start_address_reg + display_x_calced when display_x < DISPLAY_X_MAX else sample_start_address_reg;

	with state_reg select fram_address <=
		std_logic_vector(sample_address_calced) when WAIT_FOR_LINEEND,
		std_logic_vector(sample_address_calced) when READ_FROM_FRAM,
		(others => '0') when others;
	
	with state_reg select display_samples <=
		'1' when WAIT_FOR_LINEEND,
		'0' when others;

	current_sample <= sample_from_fram;
	last_sample <= last_sample_reg;
	
	sample_from_adc <= unsigned(sample_from_adc_slv);
	sample_from_fram <= unsigned(sample_from_fram_slv);
	
	--! FRAM Component with 2^15 bytes of storage
	SAMPLES_STORAGE : fram 
		port map (
			clk => clk,
			reset => reset,
			start_read_single => fram_readSample,
			start_write_single => '0',
			start_read_multiple => '0',
			start_write_multiple => fram_writeSamples,
			another_m_rw_exchange => fram_writeNextSample,
			close_m_rw_exchange => fram_doneWriting,
			fram_busy => fram_isBusy,
			request_m_next_data => fram_isThereMoreToWrite,
			fram_address => fram_address,
			data_to_fram => sample_from_adc_slv,
			data_from_fram => sample_from_fram_slv,
			fram_cs_n => fram_cs,
			fram_sck => fram_sclk,
			fram_mosi => fram_mosi,
			fram_miso => fram_miso
	);

	--! ADC Component with 8-bit resolution
	SAMPLES_ADC : pmodAD1
		port map (
			clk => clk,
			reset => reset,
			start => '0',
			busy => adc_isBusy,
			data => sample_from_adc_slv,
			sclk => adc_sclk,
			miso => adc_miso,
			cs_n => adc_cs
	);

	--! Trigger Detection Component
	TRIGGER : trigger_detection
		port map (
			last_sample => last_sample_reg(7 downto 4),
			current_sample => sample_from_adc(7 downto 4),
			trigger_threshold => triggerYPos,
			sample_on_rising_edge => triggerOnRisingEdge,
			triggered => open
	);
end architecture;