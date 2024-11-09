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
		triggerXPos		: in unsigned(2 downto 0);
		--! Trigger Y position, multiplied by 16 if applied onto the screen / sample
		triggerYPos		: in unsigned(3 downto 0);
		--! Timebase of the oscilloscope
		time_base		: in unsigned(2 downto 0);
		--! Shift of the memory to display the samples
		memoryShift		: in signed(8 downto 0);
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
		adc_miso		: in std_logic;

		--! Something Went wrong if this is high, can be observed with the Gowin Oscilloscope Tool
		error_occurred	: out std_logic
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

	--! Maximum half size of the memory
	constant MEMORY_HALFSIZE : positive := (2**15)/2 - 1;
	--! Display X maximum value
	constant DISPLAY_X_MAX : positive := 480;
	--! Sample Rate of the ADC
	constant SAMPLERATE_CNT_MAX : positive := 25_000_000 / 500_000;
	--! Bitlength of the sample rate counter
	constant SAMPLERATE_CNT_MAX_BITLENGTH : positive := integer(ceil(log2(real(SAMPLERATE_CNT_MAX))));
	--! Trigger X-Pos Offset
	constant TRIGGER_X_OFFSET : positive := 60;
	--! Memory Shift factor
	constant MEMORY_SHIFT_FACTOR : positive := 5;

	--! State machine states
	type state_type is (
		INIT,					--! Initialization state
		WAIT_FOR_LINE_END,		--! Wait for the end of the line
		READ_FROM_FRAM,			--! Read samples from the FRAM to display them
		FRAME_END_REACHED,		--! Frame end reached
		PREP_FRAM_FOR_SAMPLES,	--! Trigger start! Prepare the FRAM for the samples
		MEASURE_ADC,			--! Measure the ADC
		CHECK_ADC,				--! Check the ADC for the sample, process trigger(s)
		STORE_IN_MEM,			--! Store the samples in the FRAM
		WRAP_UP_MEASUREMENT		--! Wrap up the measurement process
	);

	--! Calculated display X position (display_x << time_base + 1 << time_base)
	signal display_x_calculated			: unsigned(14 downto 0);
	--! Calculated sample address (sample_start_address + display_x_calculated)
	signal sample_address_calced	: unsigned(14 downto 0);
	--! Current start address of the samples in the FRAM when displaying, repurposed during writing for buffer calculations
	signal sample_start_address_reg, sample_start_address_next : unsigned(14 downto 0);
	--! Address Counter for the FRAM during sampling, repurposed during display to memorize the last trigger position
	signal address_counter_reg, address_counter_next : unsigned(14 downto 0);
	--! Last read sample from the FRAM
	signal last_sample_reg, last_sample_next : unsigned(7 downto 0);
	--! Samplerate counter for the ADC
	signal samplerate_cnt_next, samplerate_cnt_reg : unsigned(SAMPLERATE_CNT_MAX_BITLENGTH-1 downto 0);
	--! Current state of the state machine
	signal state_reg, state_next : state_type;
	--! Sample address with the memory shift offset calculated in
	signal sample_address_calced_shifted : unsigned(14 downto 0);
	--! Has the trigger already been triggered?
	signal alreadyTriggered_next, alreadyTriggered_reg : std_logic;
	--! Position of the trigger in the memory samples
	signal sample_trigger_address : unsigned(14 downto 0);
	--! Got enough samples in the FRAM buffered?
	signal enough_samples_in_fram_next, enough_samples_in_fram_reg : std_logic;
	--! Has the trigger button been detected - register
	signal trigger_btn_next, trigger_btn_reg : std_logic;
	--! Signal for trigger detection
	signal triggered : std_logic;

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
			-- Init Address counter in the middle of the FRAM
			address_counter_reg <= to_unsigned(MEMORY_HALFSIZE + 1, address_counter_reg'length);
			samplerate_cnt_reg <= (others => '0');
			alreadyTriggered_reg <= '0';
			trigger_btn_reg <= '0';
			enough_samples_in_fram_reg <= '0';
			state_reg <= INIT;
		elsif rising_edge(clk) then
			last_sample_reg <= last_sample_next;
			sample_start_address_reg <= sample_start_address_next;
			address_counter_reg <= address_counter_next;
			samplerate_cnt_reg <= samplerate_cnt_next;
			alreadyTriggered_reg <= alreadyTriggered_next;
			trigger_btn_reg <= trigger_btn_next;
			enough_samples_in_fram_reg <= enough_samples_in_fram_next;
			state_reg <= state_next;
		end if;
	end process CLKREG;

	--! State machine process
	STATEMACHINE : process (state_reg, last_sample_reg, line_end, sample_from_fram, sample_start_address_reg, fram_isBusy,
		enough_samples_in_fram_reg, sample_from_adc,adc_isBusy, triggered, triggerXPos, fram_isThereMoreToWrite, display_x,
		frame_end, address_counter_reg, samplerate_cnt_reg, alreadyTriggered_reg, trigger_btn_reg, trigger_start) is
	begin
		-- Register values
		state_next <= state_reg;
		last_sample_next <= last_sample_reg;
		sample_start_address_next <= sample_start_address_reg;
		address_counter_next <= address_counter_reg;
		alreadyTriggered_next <= alreadyTriggered_reg;
		trigger_btn_next <= trigger_btn_reg;
		enough_samples_in_fram_next <= enough_samples_in_fram_reg;

		-- Default values
		fram_readSample <= '0';
		fram_writeSamples <= '0';
		fram_writeNextSample <= '0';
		fram_doneWriting <= '0';
		adc_start <= '0';
		error_occurred <= '0';
		
		-- Increment the samplerate counter
		samplerate_cnt_next <= samplerate_cnt_reg + 1;

		-- Reset the button flag if a trigger occurred
		if trigger_start = '1' then
			trigger_btn_next <= '1';
		end if;
		
		case state_reg is
			when INIT =>
				-- We got nothing to initialize, jump to the display/view modi
				state_next <= WAIT_FOR_LINE_END;
			when WAIT_FOR_LINE_END =>
				if trigger_btn_reg = '1' then
					-- If the trigger button has been hit, start the measurement process!
					-- Reset the address counter and the sample start address
					sample_start_address_next <= to_unsigned(0, sample_start_address_next'length);
					address_counter_next <= to_unsigned(0, address_counter_next'length);
					-- Let the FRAM initialize a multiple-write process
					fram_writeSamples <= '1';
					-- Reset the "already triggered" flag
					alreadyTriggered_next <= '0';
					-- Jump to the next state
					state_next <= PREP_FRAM_FOR_SAMPLES;
				elsif frame_end = '1' then
					-- If the frame end has been reached, issue a sample read and jump to the next state
					fram_readSample <= '1';
					state_next <= FRAME_END_REACHED;
				elsif line_end = '1' then
					-- If the line end has been reached, issue a sample read, 
					-- keep the current sample as last sample and jump to the next state
					fram_readSample <= '1';
					last_sample_next <= sample_from_fram;
					state_next <= READ_FROM_FRAM;
				end if;
			when READ_FROM_FRAM =>
				if fram_isBusy = '0' then
					-- Wait until the FRAM is not busy anymore - means the sample can be read from it
					if display_x = 0 then
						-- If the display is at the starting position, use the new sample as last sample
						-- to avoid a jump in the display
						last_sample_next <= sample_from_fram;
					end if;
					-- Jump back to the WAIT_FOR_LINE_END state
					state_next <= WAIT_FOR_LINE_END;
				end if;
			when FRAME_END_REACHED =>
				if fram_isBusy = '0' then
					-- Wait until the FRAM is not busy anymore - means the sample can be read from it
					-- Overwrite the last sample with the current sample
					last_sample_next <= sample_from_fram;
					state_next <= WAIT_FOR_LINE_END;
				end if;
			when PREP_FRAM_FOR_SAMPLES =>
				-- Wait for the FRAM to be done initializing the multiple-write-process
				if fram_isThereMoreToWrite = '1' then
					-- Reset the samplerate-counter and the trigger-button-flag registers
					samplerate_cnt_next <= to_unsigned(0, samplerate_cnt_next'length);
					trigger_btn_next <= '0';
					state_next <= MEASURE_ADC;
				end if;
			when MEASURE_ADC =>
				if samplerate_cnt_reg = SAMPLERATE_CNT_MAX-1 then
					-- If the samplerate counter has reached the maximum, start the ADC
					adc_start <= '1';
					-- Increase the address counter
					address_counter_next <= address_counter_reg + 1;
					-- Memorize the last/previous sample
					last_sample_next <= sample_from_adc;
					-- Reset the samplerate counter
					samplerate_cnt_next <= to_unsigned(0, samplerate_cnt_next'length);
					state_next <= CHECK_ADC;
				end if;
			when CHECK_ADC =>
				-- Check if the ADC is done with the sample
				if adc_isBusy = '0' then
					-- Have we already triggered a stop, either manually or by the trigger?
					if alreadyTriggered_reg = '1' then
						-- Have we collected enough samples?
						if address_counter_reg = sample_start_address_reg + MEMORY_HALFSIZE then
							-- If so, wrap things up!
							fram_doneWriting <= '1';
							state_next <= WRAP_UP_MEASUREMENT;
						else
							-- Nope, store the sample in the FRAM
							state_next <= STORE_IN_MEM;
						end if;
					else
						-- We haven't triggered a stop yet, so we will definitely store the sample in the FRAM
						state_next <= STORE_IN_MEM;

						-- Check if enough samples are in the FRAM buffer
						if address_counter_reg = MEMORY_HALFSIZE then
							enough_samples_in_fram_next <= '1';
						end if;

						-- If we buffered enough samples already, check if a trigger or stop occurred
						if enough_samples_in_fram_reg = '1' then
							if trigger_btn_reg = '1' or triggered = '1' then
								-- If a trigger or stop occurred, remember the start address and
								-- prepare to fill the second half of the FRAM with data
								trigger_btn_next <= '0';
								sample_start_address_next <= address_counter_reg;
								enough_samples_in_fram_next <= '0';
								alreadyTriggered_next <= '1';
							end if;
						end if;
					end if;
				end if;
			when STORE_IN_MEM =>
				-- This should be always true, otherwise a error occured!
				if fram_isThereMoreToWrite = '1' then
					fram_writeNextSample <= '1';
					state_next <= MEASURE_ADC;
				else
					-- Should never happen!
					error_occurred <= '1';
				end if;
			when WRAP_UP_MEASUREMENT =>
				-- Memorize the trigger settings and the start address (used for the sample start address calculation)
				address_counter_next <= to_unsigned(TRIGGER_X_OFFSET, address_counter_next'length - triggerXPos'length) * triggerXPos;
				state_next <= WAIT_FOR_LINE_END;
			when others =>
				-- Should never happen!
				state_next <= INIT;
				error_occurred <= '1';
		end case;
	end process STATEMACHINE;

	-- Calculated the address of the sample to be read from the FRAM with the current time base and display position
	display_x_calculated <= shift_left(resize(display_x, display_x_calculated'length), to_integer(time_base))
						+ shift_left(to_unsigned(1, display_x_calculated'length), to_integer(time_base));

	-- address_counter_reg is repurposed during display mode to memorize the last trigger position
	-- This is now used to retain the correct trigger position even when the time base is changed after capture.
	sample_trigger_address <= sample_start_address_reg - shift_left(address_counter_reg, to_integer(time_base));

	-- Sample start address calculation
	sample_address_calced_shifted <= unsigned(shift_left(resize(memoryShift, sample_start_address_reg'length), MEMORY_SHIFT_FACTOR))
									 + sample_trigger_address;

	-- Final calculation of the sample address, unless the display position is over the end of the display - then the address is the same as the start address
	sample_address_calced <= sample_address_calced_shifted + display_x_calculated when display_x /= DISPLAY_X_MAX-1  else
							 sample_address_calced_shifted;

	--! Set the FRAM address to the calculated sample address in the display/view mode, otherwise use the address counter
	with state_reg select fram_address <=
		std_logic_vector(sample_address_calced) when WAIT_FOR_LINE_END | READ_FROM_FRAM | FRAME_END_REACHED,
		std_logic_vector(address_counter_reg) when others;
	
	--! Display the samples on the screen only in the WAIT_FOR_LINE_END state
	with state_reg select display_samples <=
		'1' when WAIT_FOR_LINE_END,
		'0' when others;

	--! Output sample signals
	current_sample <= sample_from_fram;
	last_sample <= last_sample_reg;
	
	-- Convert the samples from the ADC/FRAM from std_logic_vector to unsigned for easier handling
	sample_from_adc <= unsigned(sample_from_adc_slv);
	sample_from_fram <= unsigned(sample_from_fram_slv);
	
	--! FRAM Component with 2^15 bytes of storage
	SAMPLES_STORAGE : fram 
		port map (
			clk						=> clk,
			reset					=> reset,
			start_read_single		=> fram_readSample,
			start_write_single		=> '0',
			start_read_multiple		=> '0',
			start_write_multiple	=> fram_writeSamples,
			another_m_rw_exchange	=> fram_writeNextSample,
			close_m_rw_exchange		=> fram_doneWriting,
			fram_busy				=> fram_isBusy,
			request_m_next_data		=> fram_isThereMoreToWrite,
			fram_address			=> fram_address,
			data_to_fram			=> sample_from_adc_slv,
			data_from_fram			=> sample_from_fram_slv,
			fram_cs_n				=> fram_cs,
			fram_sck				=> fram_sclk,
			fram_mosi				=> fram_mosi,
			fram_miso				=> fram_miso
	);

	--! ADC Component with 8-bit resolution
	SAMPLES_ADC : pmodAD1
		port map (
			clk		=> clk,
			reset	=> reset,
			start	=> adc_start,
			busy	=> adc_isBusy,
			data	=> sample_from_adc_slv,
			sclk	=> adc_sclk,
			miso	=> adc_miso,
			cs_n	=> adc_cs
	);

	--! Trigger Detection Component - Only uses the upper 4 bits for triggering since trigger_threshold is 4 bits
	TRIGGER : trigger_detection
		port map (
			last_sample				=> last_sample_reg(7 downto 4),
			current_sample			=> sample_from_adc(7 downto 4),
			trigger_threshold		=> triggerYPos,
			sample_on_rising_edge	=> triggerOnRisingEdge,
			triggered				=> triggered
	);
end architecture;