-- TerosHDL Documentation:
--! @title Signal Generator Module
--! @author Pascal Gesell (gesep1 / gfcwfzkm)
--! @version 1.0
--! @date 14.10.2024
--! @brief This module generates different waveforms (sine, square, triangle, sawtooth) and sends them to the DAC module.
--!
--! This module contains a 8-bit counter, which it increases everytime the DAC has been started.
--! Using this counter, the module generates different waveforms (sine, square, triangle, sawtooth)
--! and sends them to the DAC module.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity signal_gen is
	port (
		--! Clock Signal
		clk   : in std_logic;
		--! Reset Signal, active high
		reset : in std_logic;

		--! Frequency of the signal generator (Amount of bits to shift the counter)
		SigGenFrequency : in unsigned(1 downto 0);
		--! Selects the waveform to generate
		SigWaveSelect : in unsigned(1 downto 0);

		--! Chip Select Signal for the DAC
		da_cs : out std_logic;
		--! Serial Clock Signal for the DAC
		da_sclk : out std_logic;
		--! Serial Data Signal for the DAC
		da_mosi : out std_logic
	);
end entity signal_gen;

architecture rtl of signal_gen is
	component sine
		port (
			counter : in unsigned(7 downto 0);
			sine_signal : out std_logic_vector(7 downto 0)
		);
	end component;
	component rectangle
		port (
			counter : in unsigned(7 downto 0);
			rect_signal : out std_logic_vector(7 downto 0)
		);
	end component;
	
	component triangle
		port (
			counter : in unsigned(7 downto 0);
			triangle_signal : out std_logic_vector(7 downto 0)
		);
	end component;

	component sawtooth
		port (
			counter : in unsigned(7 downto 0);
			saw_signal : out std_logic_vector(7 downto 0)
		);
	end component;
	
	component pmodDA2
		port (
			clk : in std_logic;
			reset : in std_logic;
			din : in std_logic_vector(7 downto 0);
			start : in std_logic;
			busy : out std_logic;
			mosi : out std_logic;
			sclk : out std_logic;
			cs_n : out std_logic
		);
	end component;

	--! Constants for the waveform selection
	constant SELECTED_SINEWAVE : unsigned(1 downto 0)		:= "00";
	constant SELECTED_SQUAREWAVE : unsigned(1 downto 0)		:= "01";
	constant SELECTED_TRIANGLEWAVE : unsigned(1 downto 0)	:= "10";
	constant SELECTED_SAWTOOTHWAVE : unsigned(1 downto 0)	:= "11";

	--! States for the state machine
	type state_type is (IDLE, SENDING);
	--! Array for the counter increment and mask
	type FreqArray is array(0 to 3) of unsigned(7 downto 0);

	--! Constants for the counter increment
	constant ADD_COUNT : FreqArray := (
		"00000001",
		"00000010",
		"00000100",
		"00001000"
	);

	--! Constants for the counter mask
	constant AND_MASK : FreqArray := (
		"11111111",
		"11111110",
		"11111100",
		"11111000"
	);

	--! Register for the state machine
	signal state_reg, state_next : state_type;
	--! Register for the counter
	signal sig_counter_reg, sig_counter_next : unsigned(7 downto 0);

	--! Busy signal from the DAC
	signal dac_busy : std_logic;
	--! Start signal to the DAC
	signal dac_start: std_logic;

	--! Currently active waveform
	signal waveform : std_logic_vector(7 downto 0);
	--! Sine waveform
	signal sinewave : std_logic_vector(7 downto 0);
	--! Square waveform
	signal squarewave : std_logic_vector(7 downto 0);
	--! Triangle waveform
	signal trianglewave : std_logic_vector(7 downto 0);
	--! Sawtooth waveform
	signal sawtoothwave : std_logic_vector(7 downto 0);
	--! Next counter value
	signal next_counter : unsigned(7 downto 0);
begin

	CLKGEN : process(clk, reset)
	begin
		if reset = '1' then
			sig_counter_reg <= (others => '0');
			state_reg <= IDLE;
		elsif rising_edge(clk) then
			sig_counter_reg <= sig_counter_next;
			state_reg <= state_next;
		end if;
	end process CLKGEN;

	WAVEFORM_GEN_NSL : process(sig_counter_reg, SigGenFrequency, state_reg, dac_busy, next_counter) is
	begin
		sig_counter_next <= sig_counter_reg;
		state_next <= state_reg;
		dac_start <= '0';

		case state_reg is
			when IDLE =>
				-- Wait until the DAC isn't busy anymore
				if dac_busy = '0' then
					-- Start the DAC and move to the sending state
					dac_start <= '1';
					state_next <= SENDING;
				end if;
			when SENDING =>
				-- Increment the counter and move back to Idle
				sig_counter_next <= next_counter;
				state_next <= IDLE;
			when others =>
				state_next <= IDLE;
		end case;
	end process WAVEFORM_GEN_NSL;

	--! Select the waveform to generate
	with SigWaveSelect select waveform <= 
		sinewave when SELECTED_SINEWAVE,
		squarewave when SELECTED_SQUAREWAVE,
		trianglewave when SELECTED_TRIANGLEWAVE,
		sawtoothwave when SELECTED_SAWTOOTHWAVE,
		x"10" when others;
	
	--! Calculate the next counter value depending on the frequency
	next_counter <= (sig_counter_reg and AND_MASK(to_integer(SigGenFrequency))) + ADD_COUNT(to_integer(SigGenFrequency));

	--! Sinewave generator
	SINE_GENERATOR : sine
		port map (
			counter => sig_counter_reg,
			sine_signal => sinewave
	);

	--! Squarewave generator
	RECTANGLE_GENERATOR : rectangle
		port map (
			counter => sig_counter_reg,
			rect_signal => squarewave
	);
	
	--! Trianglewave generator
	TRIANGLE_GENERATOR : triangle
		port map (
			counter => sig_counter_reg,
			triangle_signal => trianglewave
	);

	--! Sawtoothwave generator
	SAWTOOTH_GENERATOR : sawtooth
		port map (
			counter => sig_counter_reg,
			saw_signal => sawtoothwave
	);

	--! DAC module
	DAC_PMOD : pmodDA2
		port map (
			clk => clk,
			reset => reset,
			din => waveform,
			start => dac_start,
			busy => dac_busy,
			mosi => da_mosi,
			sclk => da_sclk,
			cs_n => da_cs
	);

end architecture;