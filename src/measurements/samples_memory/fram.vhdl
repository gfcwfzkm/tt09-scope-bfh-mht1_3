-- TerosHDL Documentation:
--! @title FRAM Controller
--! @author Pascal Gesell (gesep1 / gfcwfzkm)
--! @version 1.0
--! @date 09.10.2024
--! @brief Controls the FRAM memory
--!
--! This module controls the FRAM memory. It reads and writes data to the FRAM memory using the SPI protocol.
--! The module can handle single read/write transactions and multiple read/write transactions. The module
--! uses a state machine to control the SPI transactions and the FRAM memory. It has been specifically
--! written for the FM25W256 FRAM memory chip by Cypress (Infineon): https://datasheet.octopart.com/FM25W256-G-Cypress-Semiconductor-datasheet-86779777.pdf
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity fram is
	generic(
		F_CLK : positive := 25_000_000 --! FPGA clock frequency in Hz, used to calculate the FRAM deselect time
	);
	port (
		--! Clock signal
		clk   : in std_logic;
		--! Ansynchronous, active-high reset
		reset : in std_logic;
		
		--! Start a single read transaction
		start_read_single		: in std_logic;
		--! Start a single write transaction
		start_write_single		: in std_logic;
		--! Start a multiple read transaction
		start_read_multiple		: in std_logic;
		--! Start a multiple write transaction
		start_write_multiple	: in std_logic;
		--! Start another multiple read/write transaction if request_m_next_data is high
		another_m_rw_exchange	: in std_logic;
		--! Close the multiple read/write transaction if close_m_rw_exchange is high
		close_m_rw_exchange		: in std_logic;
		--! FRAM busy signal (active-high)
		fram_busy				: out std_logic;
		--! Request the next data for a multiple read/write transaction
		request_m_next_data		: out std_logic;

		--! FRAM address to read/write
		fram_address	: in std_logic_vector(14 downto 0);
		--! Data to write to the FRAM
		data_to_fram	: in std_logic_vector(7 downto 0);
		--! Data read from the FRAM
		data_from_fram	: out std_logic_vector(7 downto 0);

		--! FRAM Chip Select (active-low)
		fram_cs_n	: out std_logic;
		--! FRAM Serial Clock
		fram_sck	: out std_logic;
		--! FRAM Master Out Slave In
		fram_mosi	: out std_logic;
		--! FRAM Master In Slave Out
		fram_miso	: in std_logic
	);
end entity fram;

architecture rtl of fram is
	--! 60ns deselect time for the FRAM memory
	constant FRAM_DESELECT_TIME : positive := positive(1.0 / real(60 * 10.0**(-9)));	
	--! Counter value to deselect the FRAM memory based on the deselect time and the FPGA clock frequency
	constant FRAM_DESELECT_COUNTER : positive := positive(F_CLK / FRAM_DESELECT_TIME);
	--! Bits needed for the deselect counter
	constant FRAM_DESELECT_COUNTER_BITS : integer := integer(ceil(log2(real(FRAM_DESELECT_COUNTER)))) + 1;
	--! FRAM SPI Read Opcode
	constant FRAM_OPCODE_READ	: std_logic_vector(7 downto 0) := "00000011";
	--! FRAM SPI Write Opcode
	constant FRAM_OPCODE_WRITE	: std_logic_vector(7 downto 0) := "00000010";
	--! FRAM SPI Write Enable Opcode
	constant FRAM_OPCODE_WREN	: std_logic_vector(7 downto 0) := "00000110";

	--! State machine states
	type fram_state is (
		IDLE,				--! Idle state, waiting for a transaction to start
		SEND_WREN_OPCODE,	--! Send the write enable opcode to the FRAM
		RESTART_SPI,		--! Restart the SPI transaction after a write enable opcode
		SEND_ADDR_H,		--! Send the high byte of the address to the FRAM
		SEND_ADDR_L,		--! Send the low byte of the address to the FRAM
		SEND_DATA,			--! Send the data to be written to the FRAM
		READ_DATA,			--! Read the data from the FRAM
		WAIT_MULTIPLE_RW,	--! Wait for the next multiple read/write transaction
		FINISH,				--! Finish the current single-byte transaction
		FINISH_MULTIPLE_RW	--! Finish the current multiple read/write transaction
	);

	--! Transaction states
	type transaction_state is (
		SINGLE_READ,	--! Single read transaction
		SINGLE_WRITE,	--! Single write transaction
		MULTIPLE_READ,	--! Multiple read transaction
		MULTIPLE_WRITE	--! Multiple write transaction
	);

	--! State machine register
	signal state_reg, state_next : fram_state;
	--! Transaction state register
	signal transaction_state_reg, transaction_state_next : transaction_state;
	--! Deselect counter register
	signal nCS_counter_reg, nCS_counter_next : unsigned(FRAM_DESELECT_COUNTER_BITS-1 downto 0);

	--! SPI busy signal
	signal spi_busy : std_logic;
	--! SPI multiple read/write signal
	signal spi_multiple_rw : std_logic;
	--! SPI start signal
	signal spi_start : std_logic;
	--! SPI data to be sent to the FRAM
	signal spi_data_to_fram : std_logic_vector(7 downto 0);
	--! SPI data received from the FRAM
	signal spi_data_from_fram : std_logic_vector(7 downto 0);

	--! SPI Master Component
	component spi_master
		port (
		  	clk : in std_logic;
		  	reset : in std_logic;
		  	start : in std_logic;
		  	busy_wait : in std_logic;
		  	data_in : in std_logic_vector(7 downto 0);
		  	data_out : out std_logic_vector(7 downto 0);
		  	busy : out std_logic;
		  	sclk : out std_logic;
		  	mosi : out std_logic;
		  	miso : in std_logic;
		  	cs : out std_logic
		);
	  end component;
begin

	data_from_fram <= spi_data_from_fram;
	
	fram_busy <= '0' when state_reg = IDLE else '1';
	--with state_reg select fram_busy <=
	--	'0' when IDLE,
	--	'1' when SEND_WREN_OPCODE | RESTART_SPI | SEND_ADDR_H | SEND_ADDR_L,
	--	'1' when SEND_DATA,
	--	'1' when READ_DATA,
	--	'1' when WAIT_MULTIPLE_RW,
	--	'1' when FINISH,
	--	'1' when FINISH_MULTIPLE_RW,
	--	'0' when others;

	--! Clocked registers and reset logic
	CLKREG : process(clk, reset) is begin
		if reset = '1' then
			state_reg <= IDLE;
			transaction_state_reg <= SINGLE_READ;
			nCS_counter_reg <= (others => '0');
		elsif rising_edge(clk) then
			state_reg <= state_next;
			transaction_state_reg <= transaction_state_next;
			nCS_counter_reg <= nCS_counter_next;
		end if;
	end process CLKREG;

	--! State machine process
	STATEMACHINE : process (state_reg, transaction_state_reg, start_read_single, start_write_single,
							start_read_multiple, start_write_multiple, another_m_rw_exchange, spi_busy,
							close_m_rw_exchange, nCS_counter_reg, fram_address, data_to_fram) is
	begin
		-- Default assignments of the next state
		state_next <= state_reg;
		transaction_state_next <= transaction_state_reg;
		nCS_counter_next <= nCS_counter_reg;

		-- Signals used in the state machine, to prevent latches
		spi_data_to_fram <= (others => '0');
		spi_start <= '0';
		spi_multiple_rw <= '0';
		request_m_next_data <= '0';

		case state_reg is
			when IDLE =>
				-- Check if a read or write transaction is requested
				if start_read_single = '1' or start_read_multiple = '1' then

					-- Check if the transaction is a single read or multiple read
					if start_read_single = '1' then
						transaction_state_next <= SINGLE_READ;
					else -- start_read_multiple = '1'
						transaction_state_next <= MULTIPLE_READ;
					end if;

					-- Send the read opcode to the FRAM
					spi_data_to_fram <= FRAM_OPCODE_READ;
					spi_start <= '1';
					state_next <= SEND_ADDR_H;

					-- Indicate to the SPI master that there will be multiple read/write operations
					spi_multiple_rw <= '1';
				elsif start_write_single = '1' or start_write_multiple = '1' then

					-- Check if the transaction is a single write or multiple write
					if start_write_single = '1' then
						transaction_state_next <= SINGLE_WRITE;
					else -- start_write_multiple = '1'
						transaction_state_next <= MULTIPLE_WRITE;
					end if;

					-- Send the write enable opcode to the FRAM
					spi_data_to_fram <= FRAM_OPCODE_WREN;
					nCS_counter_next <= to_unsigned(FRAM_DESELECT_COUNTER, nCS_counter_next'length);
					spi_start <= '1';
					state_next <= SEND_WREN_OPCODE;

					-- Indicate to the SPI master that this will be a single read/write operation
					spi_multiple_rw <= '0';
				end if;
			when SEND_WREN_OPCODE =>
				-- Check if the SPI master is not busy before sending the next data
				if spi_busy = '0' then
					-- Restart the SPI transaction by waiting the minimum amount of time
					if nCS_counter_reg = 0 then
						state_next <= RESTART_SPI;
					else
						nCS_counter_next <= nCS_counter_reg - 1;
					end if;
				end if;
			when RESTART_SPI =>
				if spi_busy = '0' then
					-- Send the write opcode to the FRAM
					spi_data_to_fram <= FRAM_OPCODE_WRITE;
					spi_start <= '1';
					state_next <= SEND_ADDR_H;
					spi_multiple_rw <= '1';
				end if;
			when SEND_ADDR_H =>
				if spi_busy = '0' then
					-- Send the high byte of the address to the FRAM
					spi_data_to_fram <= ('0' & fram_address(14 downto 8));
					spi_start <= '1';
					state_next <= SEND_ADDR_L;
					spi_multiple_rw <= '1';
				end if;
			when SEND_ADDR_L =>
				if spi_busy = '0' then
					-- Send the low byte of the address to the FRAM
					spi_data_to_fram <= fram_address(7 downto 0);
					spi_start <= '1';
					spi_multiple_rw <= '1';

					-- Check if a read or write transaction is requested
					if transaction_state_reg = SINGLE_READ or transaction_state_reg = MULTIPLE_READ then
						state_next <= READ_DATA;
					else -- SINGLE_WRITE or MULTIPLE_WRITE
						state_next <= SEND_DATA;
					end if;
				end if;
			when SEND_DATA =>
				if spi_busy = '0' then
					-- Send the data to be written to the FRAM
					spi_data_to_fram <= data_to_fram;
					spi_start <= '1';
					spi_multiple_rw <= '1';
					nCS_counter_next <= to_unsigned(FRAM_DESELECT_COUNTER, nCS_counter_next'length);
					state_next <= FINISH;
				end if;
			when READ_DATA =>
				if spi_busy = '0' then
					-- Read the data from the FRAM, send dummy data to it
					spi_data_to_fram <= (others => '0');
					spi_start <= '1';
					spi_multiple_rw <= '1';
					nCS_counter_next <= to_unsigned(FRAM_DESELECT_COUNTER, nCS_counter_next'length);
					state_next <= FINISH;
				end if;
			when WAIT_MULTIPLE_RW =>
				request_m_next_data <= '1';				
				spi_multiple_rw <= '1';
				if another_m_rw_exchange = '1' then
					-- If another read transaction is requested, go back to `READ_DATA` or `SEND_DATA` state
					if transaction_state_reg = MULTIPLE_READ then
						state_next <= READ_DATA;
					else -- MULTIPLE_WRITE
						state_next <= SEND_DATA;
					end if;
				elsif close_m_rw_exchange = '1' then
					-- If the multiple read exchange is to be closed, go back to `IDLE` state
					-- Make sure the minimum amount of time has passed before deselecting the FRAM
					spi_multiple_rw <= '0';
					state_next <= FINISH_MULTIPLE_RW;

					if FRAM_DESELECT_COUNTER /= 0 then
						nCS_counter_next <= to_unsigned(FRAM_DESELECT_COUNTER - 1, nCS_counter_next'length);
					end if;
				end if;	
			when FINISH =>
				-- Wait for the current transaction to finish
				if spi_busy = '0' then
					-- Check if there are more transactions to be done
					if transaction_state_reg = MULTIPLE_READ or transaction_state_reg = MULTIPLE_WRITE then
						-- If multiple read/write, go back to `WAIT_MULTIPLE_RW` state
						state_next <= WAIT_MULTIPLE_RW;
						spi_multiple_rw <= '1';
					else
						-- Make sure the minimum amount of time has passed before deselecting the FRAM
						spi_multiple_rw <= '0';
						if nCS_counter_reg = 0 then
							state_next <= IDLE;
						else
							nCS_counter_next <= nCS_counter_reg - 1;
						end if;
					end if;
				end if;
			when FINISH_MULTIPLE_RW =>
				-- Wait for the current transaction to finish
				if spi_busy = '0' then
					-- Make sure the minimum amount of time has passed before deselecting the FRAM
					if nCS_counter_reg = 0 then
						state_next <= IDLE;
						transaction_state_next <= SINGLE_READ;
					else
						nCS_counter_next <= nCS_counter_reg - 1;
					end if;
				end if;
			when others =>
				state_next <= IDLE;
				report "Invalid state reached"
					severity FAILURE;
		end case;
	end process STATEMACHINE;

	--! SPI Master Component
	spi_master_inst : spi_master
  		port map (
    		clk			=> clk,
    		reset		=> reset,
    		start		=> spi_start,
    		busy_wait	=> spi_multiple_rw,
    		data_in		=> spi_data_to_fram,
    		data_out	=> spi_data_from_fram,
    		busy		=> spi_busy,
    		sclk		=> fram_sck,
    		mosi		=> fram_mosi,
    		miso		=> fram_miso,
    		cs			=> fram_cs_n
  	);

end architecture;