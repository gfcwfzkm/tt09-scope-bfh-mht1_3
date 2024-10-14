-- TerosHDL Documentation:
--! @title UART transmitter module
--! @author Pascal Gesell (gesep1 / gfcwfzkm)
--! @version 1.0
--! @date 14.10.2024
--! @brief UART transmitter module for the oscilloscope.
--!
--! This module transmits data via UART.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity uart_tx is
	generic (
		--! Clock frequency in Hz
		CLK_FREQ : positive := 25_000_000;
		--! Baud rate in bps
		BAUD_RATE : positive := 9_600
	);
	port (
		--! Clock signal
		clk				: in std_logic;
		--! Reset signal, active high
		reset			: in std_logic;
		
		--! Data to send
		data_to_send	: in std_logic_vector(7 downto 0);
		
		--! Start sending signal
		start_sending	: in std_logic;
		--! Busy signal
		busy			: out std_logic;

		--! UART TX signal
		tx				: out std_logic
	);
end entity uart_tx;

architecture rtl of uart_tx is
	--! Counter steps for baud rate
	constant COUNTER_STEPS	: integer := CLK_FREQ / BAUD_RATE;
	--! Maximum counter value
	constant COUNTER_MAX	: integer := COUNTER_STEPS-1;
	--! Data bit size
	constant DATA_BIT_SIZE	: integer := 8;
	--! State Machine states
	type state_type is (
		IDLE,			--! Idle state, waiting for start signal
		START_BIT,		--! Sending start bit
		TRANSMITTING,	--! Transmitting data bits
		STOP_BIT		--! Sending stop bit, move to IDLE after stop bit
	);
	
	--! Counter Register to break down baud rate
	signal counter_reg, counter_next : unsigned(integer(ceil(log2(real(COUNTER_STEPS))))-1 downto 0);
	--! State Machine Register
	signal state_reg, state_next : state_type;
	--! Data Register
	signal data_reg, data_next : std_logic_vector(DATA_BIT_SIZE-1 downto 0);
	--! Data counter Register
	signal datacnt_reg, datacnt_next : unsigned(integer(ceil(log2(real(DATA_BIT_SIZE))))-1 downto 0);
begin

	--! Register process and reset
	CLKREG : process(clk, reset)
	begin
		if reset = '1' then
			counter_reg <= to_unsigned(COUNTER_MAX, counter_next'length);
			state_reg <= IDLE;
			data_reg <= (others => '0');
			datacnt_reg <= to_unsigned(DATA_BIT_SIZE-1, datacnt_next'length);
		elsif rising_edge(clk) then
			counter_reg <= counter_next;
			state_reg <= state_next;
			data_reg <= data_next;
			datacnt_reg <= datacnt_next;
		end if;
	end process;

	--! State Machine
	STATEMACHINE : process(counter_reg, state_reg, data_reg, datacnt_reg, start_sending, data_to_send)
	begin
		-- Default register assignments
		counter_next <= counter_reg;
		state_next <= state_reg;
		data_next <= data_reg;
		datacnt_next <= datacnt_reg;

		case state_reg is
			when IDLE =>
				-- Reset counter and data counter
				datacnt_next <= to_unsigned(DATA_BIT_SIZE-1, datacnt_next'length);
				counter_next <= to_unsigned(COUNTER_MAX, counter_next'length);

				if start_sending = '1' then
					-- Start sending
					data_next <= data_to_send;
					state_next <= START_BIT;
				end if;
			when START_BIT =>
				-- Start bit, move to next state after counter is 0
				if counter_reg = 0 then
					state_next <= TRANSMITTING;
					counter_next <= to_unsigned(COUNTER_MAX, counter_next'length);
				else
					counter_next <= counter_reg - 1;
				end if;
			when TRANSMITTING =>
				-- Transmit data bits
				if counter_reg = 0 then
					counter_next <= to_unsigned(COUNTER_MAX, counter_next'length);
					if datacnt_reg = 0 then
						state_next <= STOP_BIT;
					else
						data_next <= '0' & data_reg(DATA_BIT_SIZE-1 downto 1);
						datacnt_next <= datacnt_reg - 1;
					end if;
				else
					counter_next <= counter_reg - 1;
				end if;
			when STOP_BIT =>
				-- Stop bit, move to IDLE after counter is 0
				if counter_reg = 0 then
					state_next <= IDLE;
				else
					counter_next <= counter_reg - 1;
				end if;
			when others =>
				state_next <= IDLE;
		end case;
	end process STATEMACHINE;

	with state_reg select tx <=
		'0' when START_BIT,
		data_reg(0) when TRANSMITTING,
		'1' when others; 

	busy <= '1' when state_reg /= IDLE else '0';

end architecture;