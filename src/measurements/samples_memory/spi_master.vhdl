library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity spi_master is
	generic (
		MSB_FIRST : boolean := TRUE;
		NBITS : positive := 8
	);
	port (
		--! Clock signal
		clk			: in std_logic;
		--! Asynchronous reset signal
		reset		: in std_logic;
		
		-- Control signals
		--! Start signal - initiates the SPI transaction or to continue the transaction right after the previous one
		start		: in std_logic;
		--! Busy wait signal - if set, the SPI transaction will be done in a busy wait mode
		busy_wait	: in std_logic;
		--! Data in signal - the data to be sent to the SPI slave
		data_in		: in std_logic_vector(NBITS-1 downto 0);
		--! Data out signal - the data received from the SPI slave
		data_out	: out std_logic_vector(NBITS-1 downto 0);
		--! Busy signal - indicates that the SPI transaction is in progress
		busy		: out std_logic;

		-- SPI signals
		--! Serial clock signal
		sclk		: out std_logic;
		--! Master out slave in signal
		mosi		: out std_logic;
		--! Master in slave out signal
		miso		: in std_logic;
		--! Chip select signal (active low)
		cs			: out std_logic
	);
end entity spi_master;

architecture rtl of spi_master is
	type spi_state is (IDLE, TRANSCEIVE, DONE);
	signal state_reg, state_next : spi_state;

	--! Reverse bit order if MSB_FIRST is set
	signal data_in_MSB : std_logic_vector(NBITS-1 downto 0);
	signal data_out_MSB : std_logic_vector(NBITS-1 downto 0);

	--! Shift register and shift cycle counter
	signal shift_cycle_reg, shift_cycle_next : unsigned(3 downto 0);
	signal shift_reg, shift_next : std_logic_vector(NBITS downto 0);
begin

	--! Assign the SPI signals
	sclk <= shift_cycle_reg(0);
	mosi <= shift_reg(0);
	busy <= '1' when state_reg = TRANSCEIVE else '0';
	cs <= '1' when state_reg = IDLE else '0';
	data_out <= data_out_MSB;

	--! Reverse the data_in signal if the MSB_FIRST generic is set
	REVERSE_ORDER : for i in NBITS-1 downto 0 generate
		data_in_MSB(NBITS-1 - i) <= data_in(i);
		data_out_MSB(NBITS-1 - i) <= shift_reg(i);
	end generate;

	--! Clock and reset process
	CLKREG : process(clk, reset) begin
		if reset = '1' then
			state_reg <= IDLE;
			shift_reg <= (others => '0');
			shift_cycle_reg <= (others => '0');
		elsif rising_edge(clk) then
			state_reg <= state_next;
			shift_reg <= shift_next;
			shift_cycle_reg <= shift_cycle_next;
		end if;
	end process CLKREG;

	--! SPI state machine
	NSL : process (state_reg, shift_reg, shift_cycle_reg, start, busy_wait, miso, data_in_MSB) begin
		state_next <= state_reg;
		shift_next <= shift_reg;
		shift_cycle_next <= shift_cycle_reg;

		case state_reg is 
			when IDLE =>
				if start = '1' then
					state_next <= TRANSCEIVE;
					shift_cycle_next <= (others => '0');

					-- Load the data into the shift register
					if MSB_FIRST then
						shift_next <= ('0' & data_in_MSB);
					else
						shift_next <= ('0' & data_in);
					end if;
				end if;
			when TRANSCEIVE =>
				-- Check if the shift cycle counter has reached the end
				if shift_cycle_reg = "1111" then
					state_next <= DONE;
				end if;

				if shift_cycle_reg(0) = '0' then
					-- Read in the MISO data on the rising edge of SCLK
					shift_next(NBITS) <= miso;
				else
					-- Shift the data to the left on falling edge of SCLK
					shift_next <= '0' & shift_reg(NBITS downto 1);
				end if;

				-- Increment the shift cycle counter
				shift_cycle_next <= shift_cycle_reg + 1;
			when DONE =>
				-- Check if the busy wait signal is set
				if busy_wait = '1' then
					-- If the busy wait signal is set, stay in this state until
					-- the start signal is asserted to start the next transaction
					-- or the busy wait signal is de-asserted to return to the
					-- IDLE state
					if start = '1' then
						state_next <= TRANSCEIVE;
						shift_cycle_next <= (others => '0');

						-- Load the data into the shift register
						if MSB_FIRST then
							shift_next <= ('0' & data_in_MSB);
						else
							shift_next <= ('0' & data_in);
						end if;
					end if;
				else
					state_next <= IDLE;
				end if;
		end case;
	end process NSL;

end architecture;