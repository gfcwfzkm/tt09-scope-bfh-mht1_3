library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity meas_statemachine is
	port (
		clk   : in std_logic;
		reset : in std_logic;
		
		trigger_start	: in std_logic;
		frame_end		: in std_logic;
		line_end		: in std_logic;
		triggerXPos		: in unsigned(3 downto 0);
		triggerYPos		: in unsigned(4 downto 0);
		timebase		: in unsigned(3 downto 0);
		memoryShift		: in signed(7 downto 0);


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
end entity meas_statemachine;

architecture rtl of meas_statemachine is
	component trigger_detection
		port (
			last_sample : in unsigned(7 downto 0);
			current_sample : in unsigned(7 downto 0);
			trigger_threshold : in unsigned(7 downto 0);
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

	signal last_sample_reg, last_sample_next : unsigned(7 downto 0);

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
begin

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
			fram_address => (others => '0'),
			data_to_fram => sample_from_adc_slv,
			data_from_fram => sample_from_fram_slv,
			fram_cs_n => fram_cs,
			fram_sck => fram_sclk,
			fram_mosi => fram_mosi,
			fram_miso => fram_miso
	);

	ADC : pmodAD1
		port map (
			clk => clk,
			reset => reset,
			start => adc_start,
			busy => adc_busy,
			data => sample_from_adc_slv,
			sclk => adc_sclk,
			miso => adc_miso,
			cs_n => adc_cs
	);

	TRIGGER : trigger_detection
		port map (
			last_sample => last_sample_reg,
			current_sample => sample_from_adc,
			trigger_threshold => "10000000",
			sample_on_rising_edge => '1',
			triggered => trigger_start
	);
end architecture;