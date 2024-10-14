-- TerosHDL Documentation:
--! @title Print settings module
--! @author Pascal Gesell (gesep1 / gfcwfzkm)
--! @version 1.0
--! @date 14.10.2024
--! @brief Print settings module for the oscilloscope.
--!
--! This module prints the settings of the oscilloscope via UART.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity print_settings is
	port (
		--! Clock signal
		clk					: in std_logic;
		--! Reset signal, active high
		reset				: in std_logic;
		
		--! Trigger on rising edge setting
		triggerOnRisingEdge	: in std_logic;
		--! Trigger X position setting
		triggerXPos			: in unsigned(2 downto 0);
		--! Trigger Y position setting
		triggerYPos			: in unsigned(3 downto 0);
		--! Channel amplitude setting
		chAmplitude			: in signed(2 downto 0);
		--! Channel offset setting
		chOffset			: in unsigned(4 downto 0);
		--! Timebase setting
		timebase			: in unsigned(2 downto 0);
		--! DSG frequency shift setting
		dsgFreqShift		: in unsigned(1 downto 0);
		--! Waveform setting
		waveform			: in unsigned(1 downto 0);

		--! UART TX signal
		tx					: out std_logic
	);
end entity print_settings;

architecture rtl of print_settings is
	component uart_tx
		port (
			clk : in std_logic;
			reset : in std_logic;
			data_to_send : in std_logic_vector(7 downto 0);
			start_sending : in std_logic;
			busy : out std_logic;
			tx : out std_logic
		);
	end component;

	--! Data package size
	constant PKG_SIZE	: integer := 16;
	--! ASCII character R
	constant ASCII_R	: std_logic_vector(7 downto 0) := x"52";
	--! ASCII character F
	constant ASCII_F	: std_logic_vector(7 downto 0) := x"46";
	--! ASCII character 0
	constant ASCII_0	: std_logic_vector(7 downto 0) := x"30";
	--! ASCII character T
	constant ASCII_T	: std_logic_vector(7 downto 0) := x"54";
	--! ASCII character C
	constant ASCII_C	: std_logic_vector(7 downto 0) := x"43";
	--! ASCII character W
	constant ASCII_W	: std_logic_vector(7 downto 0) := x"57";
	--! ASCII character :
	constant ASCII_DOUBLEPOINT : std_logic_vector(7 downto 0) := x"3A";
	--! ASCII character CR
	constant CARRIAGE_RETURN : std_logic_vector(7 downto 0) := x"0D";
	--! ASCII character LF
	constant NEW_LINE : std_logic_vector(7 downto 0) := x"0A";

	--! Data package type
	type data_pkg is array(0 to PKG_SIZE-1) of std_logic_vector(7 downto 0);
	--! State Machine states
	type state_type is (
		SEND_DATA,		--! Send data package
		WAIT_FOR_UART	--! Wait for UART to finish sending
	);

	--! Trigger edge setting as ASCII character
	signal trigger_edge_setting : std_logic_vector(7 downto 0);
	--! Trigger X position setting as ASCII character
	signal trigger_x_setting : std_logic_vector(7 downto 0);
	--! Trigger Y position setting as ASCII character
	signal trigger_y_setting : std_logic_vector(7 downto 0);
	--! Channel amplitude setting as ASCII character
	signal chAmplitude_setting : std_logic_vector(7 downto 0);
	--! Channel offset setting as ASCII character
	signal chOffset_setting : std_logic_vector(7 downto 0);
	--! Timebase setting as ASCII character
	signal timebase_setting : std_logic_vector(7 downto 0);
	--! DSG frequency shift setting as ASCII character
	signal dsgFreqShift_setting : std_logic_vector(7 downto 0);
	--! Waveform setting as ASCII character
	signal waveform_setting : std_logic_vector(7 downto 0);

	--! UART Control signal - busy
	signal uart_busy : std_logic;
	--! UART Control signal - start sending
	signal uart_start : std_logic;
	--! UART Data to send
	signal uart_data_to_send : std_logic_vector(7 downto 0);

	--! Package counter register
	signal pkg_counter_next, pkg_counter_reg : unsigned(integer(ceil(log2(real(PKG_SIZE))))-1 downto 0);
	--! State Machine register
	signal state_reg, state_next : state_type;

	--! Data package
	signal data_package : data_pkg;
begin

	-- Convert the settings to ASCII characters
	trigger_edge_setting <= ASCII_R when triggerOnRisingEdge = '1' else ASCII_F;
	trigger_x_setting <= std_logic_vector(resize(triggerXPos, 8)) or ASCII_0;
	trigger_y_setting <= std_logic_vector(resize(triggerYPos, 8)) or ASCII_0;
	chAmplitude_setting <= std_logic_vector(resize(unsigned(chAmplitude), 8)) or ASCII_0;
	chOffset_setting <= std_logic_vector(resize(chOffset, 8)) or ASCII_0;
	timebase_setting <= std_logic_vector(resize(timebase, 8)) or ASCII_0;
	dsgFreqShift_setting <= std_logic_vector(resize(dsgFreqShift, 8)) or ASCII_0;
	waveform_setting <= std_logic_vector(resize(waveform, 8)) or ASCII_0;

	-- Assign the converted settings to the data package
	data_package(0) <= NEW_LINE;
	data_package(1) <= CARRIAGE_RETURN;
	data_package(2) <= waveform_setting;
	data_package(3) <= dsgFreqShift_setting;
	data_package(4) <= ASCII_DOUBLEPOINT;
	data_package(5) <= ASCII_W;
	data_package(6) <= timebase_setting;
	data_package(7) <= chOffset_setting;
	data_package(8) <= chAmplitude_setting;
	data_package(9) <= ASCII_DOUBLEPOINT;
	data_package(10) <= ASCII_C;
	data_package(11) <= trigger_y_setting;
	data_package(12) <= trigger_x_setting;
	data_package(13) <= trigger_edge_setting;
	data_package(14) <= ASCII_DOUBLEPOINT;
	data_package(15) <= ASCII_T;

	--! Register process and reset
	CLKREG : process(clk, reset)
	begin
		if reset = '1' then
			pkg_counter_reg <= to_unsigned(PKG_SIZE-1, pkg_counter_reg'length);
			state_reg <= SEND_DATA;
		elsif rising_edge(clk) then
			pkg_counter_reg <= pkg_counter_next;
			state_reg <= state_next;
		end if;
	end process;

	--! State Machine
	STATEMACHINE : process(pkg_counter_reg, state_reg, uart_busy)
	begin
		pkg_counter_next <= pkg_counter_reg;
		state_next <= state_reg;
		uart_start <= '0';

		case state_reg is
			when SEND_DATA =>
				uart_start <= '1';
				state_next <= WAIT_FOR_UART;
			when WAIT_FOR_UART =>
				if uart_busy = '0' then
					if pkg_counter_reg = 0 then
						pkg_counter_next <= to_unsigned(PKG_SIZE-1, pkg_counter_reg'length);
					else
						pkg_counter_next <= pkg_counter_reg - 1;
					end if;
					state_next <= SEND_DATA;
				end if;
		end case;
	end process STATEMACHINE;
	
	uart_data_to_send <= data_package(to_integer(unsigned(pkg_counter_reg)));

	UART_TX_MODULE : uart_tx
		port map (
			clk => clk,
			reset => reset,
			data_to_send => uart_data_to_send,
			start_sending => uart_start,
			busy => uart_busy,
			tx => tx
	);

end architecture;