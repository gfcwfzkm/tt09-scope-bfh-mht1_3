library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity measurement_sm is
	port (
		clk   : in std_logic;
		reset : in std_logic;
		
		trigger_start	: in std_logic;
		frame_end		: in std_logic;
		line_end		: in std_logic;
		triggerXPos		: in unsigned(3 downto 0);
		triggerYPos		: in unsigned(3 downto 0);
		timebase		: in unsigned(2 downto 0);
		memoryShift		: in signed(7 downto 0);
		display_x		: in unsigned(9 downto 0);
		sampleOnRisingEdge : in std_logic;

		display_samples : out std_logic;
		current_sample	: out unsigned(7 downto 0);
		last_sample		: out unsigned(7 downto 0);

		fram_cs			: out std_logic;
		fram_sclk		: out std_logic;
		fram_mosi		: out std_logic;
		fram_miso		: in std_logic;

		adc_cs			: out std_logic;
		adc_sclk		: out std_logic;
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
	constant TRIGGER_X_DEFAULT : unsigned(triggerXPos'length-1 downto 0) := to_unsigned(8, triggerXPos'length);
	constant DISPLAY_X_MAX : unsigned(display_x'length-1 downto 0) := to_unsigned(480, display_x'length);
	type state_type is (INIT, WAIT_FOR_LINEEND, READ_FROM_FRAM);

	signal display_x_calced			: unsigned(14 downto 0);
	signal sample_address_calced	: unsigned(14 downto 0);
	signal sample_start_address_reg, sample_start_address_next : unsigned(14 downto 0);
	signal last_sample_reg, last_sample_next : unsigned(7 downto 0);
	signal state_reg, state_next : state_type;

	signal adc_busy				: std_logic;
	signal adc_start			: std_logic;
	signal sample_from_adc		: unsigned(7 downto 0);
	signal sample_from_adc_slv	: std_logic_vector(7 downto 0);

	signal fram_isBusy				: std_logic;
	signal fram_readSample			: std_logic;
	signal fram_writeSamples		: std_logic;
	signal fram_writeNextSample		: std_logic;
	signal fram_doneWriting			: std_logic;
	signal fram_isThereMoreToWrite	: std_logic;
	signal sample_from_fram			: unsigned(7 downto 0);
	signal sample_from_fram_slv		: std_logic_vector(7 downto 0);
	signal fram_address				: std_logic_vector(14 downto 0);
begin

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

	SAMPLES_ADC : pmodAD1
		port map (
			clk => clk,
			reset => reset,
			start => '0',
			busy => adc_busy,
			data => sample_from_adc_slv,
			sclk => adc_sclk,
			miso => adc_miso,
			cs_n => adc_cs
	);

	TRIGGER : trigger_detection
		port map (
			last_sample => last_sample_reg(7 downto 4),
			current_sample => sample_from_adc(7 downto 4),
			trigger_threshold => triggerYPos,
			sample_on_rising_edge => sampleOnRisingEdge,
			triggered => open
	);
end architecture;