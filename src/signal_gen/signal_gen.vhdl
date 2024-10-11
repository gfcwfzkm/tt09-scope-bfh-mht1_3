library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity signal_gen is
	port (
		clk   : in std_logic;
		reset : in std_logic;

		SigGenFrequency : in unsigned(2 downto 0);
		SigWaveSelect : in unsigned(1 downto 0);

		da_cs : out std_logic;
		da_sclk : out std_logic;
		da_mosi : out std_logic
	);
end entity signal_gen;

architecture rtl of signal_gen is
	component sine
		port (
			counter : in unsigned(6 downto 0);
			sine_signal : out std_logic_vector(7 downto 0)
		);
	end component;
	component rectangle
		port (
			counter : in unsigned(6 downto 0);
			rect_signal : out std_logic_vector(7 downto 0)
		);
	end component;
	
	component triangle
		port (
			counter : in unsigned(6 downto 0);
			triangle_signal : out std_logic_vector(7 downto 0)
		);
	end component;

	component sawtooth
		port (
			counter : in unsigned(6 downto 0);
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

	constant SELECTED_SINEWAVE : unsigned(1 downto 0) := "00";
	constant SELECTED_SQUAREWAVE : unsigned(1 downto 0) := "01";
	constant SELECTED_TRIANGLEWAVE : unsigned(1 downto 0) := "10";
	constant SELECTED_SAWTOOTHWAVE : unsigned(1 downto 0) := "11";
	type state_type is (IDLE, SENDING);

	signal state_reg, state_next : state_type;
	signal sig_counter_reg, sig_counter_next : unsigned(6 downto 0);

	signal dac_busy : std_logic;
	signal dac_start: std_logic;

	signal waveform : std_logic_vector(7 downto 0);
	signal sinewave : std_logic_vector(7 downto 0);
	signal squarewave : std_logic_vector(7 downto 0);
	signal trianglewave : std_logic_vector(7 downto 0);
	signal sawtoothwave : std_logic_vector(7 downto 0);
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

	WAVEFORM_GEN_NSL : process(sig_counter_reg, SigGenFrequency, state_reg, dac_busy) is
	begin
		sig_counter_next <= sig_counter_reg;
		state_next <= state_reg;
		dac_start <= '0';

		case state_reg is
			when IDLE =>
				if dac_busy = '0' then
					dac_start <= '1';
					state_next <= SENDING;
				end if;
			when SENDING =>
				state_next <= IDLE;
				sig_counter_next(6 downto to_integer(SigGenFrequency)) <= sig_counter_reg + shift_left(to_unsigned(1, 8), to_integer(SigGenFrequency));
				sig_counter_next(to_integer(SigGenFrequency)-1 downto 0) <= (others => '0');
		end case;
	end process WAVEFORM_GEN_NSL;

	with SigWaveSelect select waveform <= 
		sinewave when SELECTED_SINEWAVE,
		squarewave when SELECTED_SQUAREWAVE,
		trianglewave when SELECTED_TRIANGLEWAVE,
		sawtoothwave when SELECTED_SAWTOOTHWAVE,
		x"10" when others;

	SINE_GENERATOR : sine
		port map (
			counter => sig_counter_reg,
			sine_signal => sinewave
	);

	RECTANGLE_GENERATOR : rectangle
		port map (
			counter => sig_counter_reg,
			rect_signal => squarewave
	);

	TRIANGLE_GENERATOR : triangle
		port map (
			counter => sig_counter_reg,
			triangle_signal => trianglewave
	);

	SAWTOOTH_GENERATOR : sawtooth
		port map (
			counter => sig_counter_reg,
			saw_signal => sawtoothwave
	);

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