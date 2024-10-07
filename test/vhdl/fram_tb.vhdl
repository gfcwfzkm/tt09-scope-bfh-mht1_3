library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library std;
use std.textio.all;


entity fram_tb is
end entity fram_tb;

architecture test of fram_tb is
	constant FRAM_OPCODE_READ	: std_logic_vector(7 downto 0) := "00000011";
	constant FRAM_OPCODE_WRITE	: std_logic_vector(7 downto 0) := "00000010";
	constant FRAM_OPCODE_WREN	: std_logic_vector(7 downto 0) := "00000110";
	constant RANDOM_TEST_CYCLES : integer := 1000;
	constant F_CLK : positive := 25_000_000; --! FPGA clock frequency in Hz
	constant CLK_PERIOD : time := 1 sec / F_CLK;
	constant CLK_H_PERIOD : time := CLK_PERIOD / 2;

	type std_logic_array is array(natural range <>) of STD_LOGIC_VECTOR(7 downto 0);

	signal tb_finished : boolean := FALSE;
	signal clk : std_logic := '0';
	signal dut_reset : std_logic := '1';

	-- DUT FRAM control signals
	signal dut_start_read_single : std_logic := '0';
	signal dut_start_write_single : std_logic := '0';
	signal dut_start_read_multiple : std_logic := '0';
	signal dut_start_write_multiple : std_logic := '0';
	signal dut_another_m_rw_exchange : std_logic := '0';
	signal dut_close_m_rw_exchange : std_logic := '0';
	signal dut_fram_busy : std_logic := '0';
	signal dut_get_m_rw_next_byte : std_logic := '0';

	-- DUT FRAM data signals
	signal dut_fram_address : std_logic_vector(14 downto 0) := (others => '0');
	signal dut_data_to_fram : std_logic_vector(7 downto 0) := (others => '0');
	signal dut_data_from_fram : std_logic_vector(7 downto 0) := (others => '0');

	-- SPI signals
	signal spi_fram_cs_n : std_logic := '1';
	signal spi_fram_sck : std_logic := '0';
	signal spi_fram_mosi : std_logic := '0';
	signal spi_fram_miso : std_logic := '0';

	-- FRAM simulation of the slave SPI
	type simu_fram is (IDLE, ADDR, READ, WRITE, EXPECTING_CS_GO_HIGH);
	signal simu_fram_state : simu_fram := IDLE;
	signal simu_fram_read_requested : boolean := FALSE;
	signal simu_fram_WREN_latch : boolean := FALSE;
	signal simu_fram_data : std_logic_array(0 to 32767) := (others => (others => '0'));
	signal simu_fram_data_ptr : integer range 0 to 32767 := 0;
	signal simu_spi_mosi : std_logic_vector(7 downto 0) := (others => '0');
	signal simu_spi_miso : std_logic_vector(7 downto 0) := (others => '0');
	signal closeTransaction : boolean := FALSE;
	signal addrCalc : integer;
begin
	spi_fram_miso <= simu_spi_miso(7) when spi_fram_cs_n = '0' else '0';
	
	-- DUT instantiation
	FRAM_DUT : entity work.fram
  		port map (
    		clk						=> clk,
    		reset					=> dut_reset,
    		start_read_single		=> dut_start_read_single,
    		start_write_single		=> dut_start_write_single,
    		start_read_multiple		=> dut_start_read_multiple,
    		start_write_multiple	=> dut_start_write_multiple,
    		another_m_rw_exchange	=> dut_another_m_rw_exchange,
    		close_m_rw_exchange		=> dut_close_m_rw_exchange,
    		fram_busy				=> dut_fram_busy,
    		request_m_next_data		=> dut_get_m_rw_next_byte,
    		fram_address			=> dut_fram_address,
    		data_to_fram			=> dut_data_to_fram,
    		data_from_fram			=> dut_data_from_fram,
    		fram_cs_n				=> spi_fram_cs_n,
    		fram_sck				=> spi_fram_sck,
    		fram_mosi				=> spi_fram_mosi,
    		fram_miso				=> spi_fram_miso
  	);

	-- Clock generation
	clk <= not clk after CLK_H_PERIOD when not tb_finished else '0';

	-- Make sure the minimum deselect time is met
	SPI_FRAM_CS : process is
		variable vTimestamp : time := 0 ns;
	begin
		while not tb_finished loop
			wait until rising_edge(spi_fram_cs_n);
			vTimestamp := now;
			wait until falling_edge(spi_fram_cs_n);

			if (now - vTimestamp) < 60 ns then
				report "CS_N was not high for 60ns(" & to_string(now-vTimestamp) & ")" severity failure;
			end if;
		end loop;

		wait;
	end process SPI_FRAM_CS;

	-- SPI FRAM simulation
	SPI_FRAM : process is
		procedure simu_spi_slave(slave_miso : std_logic_vector(7 downto 0)) is
		begin
			simu_spi_miso <= slave_miso;
			for i in 7 downto 0 loop

				if spi_fram_cs_n = '1' then
					exit;
				end if;
				wait until rising_edge(spi_fram_sck) or rising_edge(spi_fram_cs_n);
				--simu_spi_mosi(i) <= spi_fram_mosi;
				simu_spi_mosi <= simu_spi_mosi(6 downto 0) & spi_fram_mosi;

				if spi_fram_cs_n = '1' then
					exit;
				end if;
				wait until falling_edge(spi_fram_sck) or rising_edge(spi_fram_cs_n);
				--spi_fram_miso <= slave_miso(i);
				simu_spi_miso <= simu_spi_miso(6 downto 0) & spi_fram_miso;
			end loop;
				
			wait for 1 ns;
		end procedure;

		procedure simulate_fram is
		begin
			NCS_LOOP : while spi_fram_cs_n = '0' loop
				wait for 1 ns;
				case simu_fram_state is
					when IDLE =>
						-- Receive the opcode
						simu_spi_slave((others => '0'));

						if simu_spi_mosi = FRAM_OPCODE_READ then
							-- report "Received read opcode" severity note;
							if simu_fram_WREN_latch then
								simu_fram_WREN_latch <= FALSE;
							end if;
							simu_fram_read_requested <= TRUE;
							simu_fram_state <= ADDR;
						elsif simu_spi_mosi = FRAM_OPCODE_WRITE then
							-- report "Received write opcode" severity note;
							if simu_fram_WREN_latch then
								simu_fram_WREN_latch <= FALSE;
							else
								report "WREN not set" severity failure;
							end if;
							simu_fram_read_requested <= FALSE;
							simu_fram_state <= ADDR;
						elsif simu_spi_mosi = FRAM_OPCODE_WREN then
							-- report "Received WREN opcode" severity note;
							simu_fram_WREN_latch <= TRUE;
							simu_fram_state <= EXPECTING_CS_GO_HIGH;
						else
							report "Unknown opcode: " & to_string(simu_spi_mosi) severity error;
						end if;
					when EXPECTING_CS_GO_HIGH =>
						wait until rising_edge(spi_fram_cs_n) or rising_edge(spi_fram_sck);
						if spi_fram_sck = '1' then
							report "CS did not go high after WREN command" severity failure;
						end if;
					when ADDR =>
						-- Receive the address
						simu_spi_slave((others => '0'));
						wait for 1 ns;
						simu_fram_data_ptr <= to_integer(unsigned(simu_spi_mosi));
						wait for 1 ns;
						simu_fram_data_ptr <= simu_fram_data_ptr * 256;
						wait for 1 ns;
						simu_spi_slave((others => '0'));
						wait for 1 ns;
						simu_fram_data_ptr <= simu_fram_data_ptr + to_integer(unsigned(simu_spi_mosi));
						wait for 1 ns;

						-- report "Accessing address: " & to_string(simu_fram_data_ptr) severity note;

						-- Check if the fram_data_ptr is the same as dut_fram_address
						assert simu_fram_data_ptr = to_integer(unsigned(dut_fram_address))
							report "Address read is incorrect -> " & 
								"Expected: " & to_string(to_integer(unsigned(dut_fram_address))) &
								"  Received: " & to_string(simu_fram_data_ptr);
						
						if simu_fram_read_requested then
							simu_fram_state <= READ;
						else
							simu_fram_state <= WRITE;
						end if;
					when READ =>
						-- Send the data
						simu_spi_slave(simu_fram_data(simu_fram_data_ptr));
						wait for 1 ns;
						if spi_fram_cs_n = '1' then
							exit;
						end if;

						if simu_fram_data_ptr = 32767 then
							-- Roll over the data pointer if max is reached
							simu_fram_data_ptr <= 0;
						else
							-- Increment the data pointer
							simu_fram_data_ptr <= simu_fram_data_ptr + 1;
						end if;
						wait for 1 ns;

					when WRITE =>
						-- Receive the data
						simu_spi_slave((others => '0'));

						if spi_fram_cs_n = '1' then
							exit;
						end if;

						simu_fram_data(simu_fram_data_ptr) <= simu_spi_mosi;
						wait for 1 ns;

						if simu_fram_data_ptr = 32767 then
							-- Roll over the data pointer if max is reached
							simu_fram_data_ptr <= 0;
						else
							-- Increment the data pointer
							simu_fram_data_ptr <= simu_fram_data_ptr + 1;
						end if;
						wait for 1 ns;
					when others =>
						simu_fram_state <= IDLE;
						report "Unknown state" severity failure;
				end case;
			end loop;
			
			simu_fram_state <= IDLE;
		end procedure;

		variable seed1, seed2 : positive := 42;
		variable randomData : real;
	begin
		-- Initialize the FRAM with some data
		for i in 0 to 32767 loop
			uniform(seed1, seed2, randomData);
			simu_fram_data(i) <= std_logic_vector(to_unsigned(integer(randomData * 255.0), 8));
		end loop;
		
		while not tb_finished loop
			wait until spi_fram_cs_n = '0' or tb_finished = TRUE;

			if tb_finished = TRUE then
				exit;
			else
				simulate_fram;
			end if;
		end loop;
		
		wait;
	end process SPI_FRAM;
	
	-- Test process
	STIMULI : process is
		variable seed1, seed2 : positive := 999;
		variable randomData : real;
		variable randomAddress : real;
		variable randomLength : real;

		procedure check_idle is
		begin
			assert spi_fram_cs_n = '1' report "CS_N is not high";
			assert spi_fram_sck = '0' report "SCK is not low";			
			assert dut_fram_busy = '0' report "FRAM is busy";
			assert dut_get_m_rw_next_byte = '0' report "Byterequest is active";			
		end procedure;

		procedure test_fram_read_single(address : std_logic_vector(14 downto 0)) is
		begin
			-- Check that the FRAM is idle
			check_idle;
			-- Start the read operation
			dut_fram_address <= address;
			dut_start_read_single <= '1';
			wait until rising_edge(clk);
			dut_start_read_single <= '0';
			wait for 1 ns;

			-- Pass control over to simulate_fram

			-- Wait for the FRAM to be ready
			if dut_fram_busy = '1' then
				wait until dut_fram_busy = '0';
			end if;
			-- Check the data
			assert dut_data_from_fram = simu_fram_data(to_integer(unsigned(address)))
				report "Data read is incorrect ->" &
					"Expected: " & to_string(simu_fram_data(to_integer(unsigned(address)))) & 
					"  Received: " & to_string(dut_data_from_fram) & 
					"  Address: " & to_hstring(address) severity failure;
		end procedure;

		procedure test_fram_write_single(address : std_logic_vector(14 downto 0); data : std_logic_vector(7 downto 0)) is
		begin
			check_idle;

			-- Start the write operation
			dut_fram_address <= address;
			dut_data_to_fram <= data;
			dut_start_write_single <= '1';
			wait until rising_edge(clk);
			dut_start_write_single <= '0';
			wait for 1 ns;

			-- Pass control over to simulate_frame

			-- Wait for the FRAM to be ready
			if dut_fram_busy = '1' then
				wait until dut_fram_busy = '0';
			end if;

			-- Check the data
			assert simu_fram_data(to_integer(unsigned(address))) = data
				report "Data write is incorrect ->" &
					"Expected: " & to_string(data) & 
					"  Received: " & to_string(simu_fram_data(to_integer(unsigned(address)))) & 
					"  Address: " & to_hstring(address) severity failure;
		end procedure;

		procedure test_fram_read_multiple (start_address : std_logic_vector(14 downto 0); amount_of_data : integer) is
		begin
			closeTransaction <= FALSE;
			-- Check that the FRAM is idle
			check_idle;
			-- Start the read operation
			dut_fram_address <= start_address;
			dut_start_read_multiple <= '1';
			wait until rising_edge(clk);
			dut_start_read_multiple <= '0';
			wait for 1 ns;

			-- Wait for the FRAM to be ready
			if dut_fram_busy = '1' then
				wait until rising_edge(dut_get_m_rw_next_byte);
			end if;
			wait for 1 ns;

			for i in 0 to amount_of_data - 1 loop
				-- Keep the fram module waiting for a random amount of time
				uniform(seed1, seed2, randomData);
				wait for (randomData * 150 ns);
				
				-- Make sure the FRAM is still busy and waiting for us
				assert dut_fram_busy = '1' report "FRAM is not busy";
				assert spi_fram_cs_n = '0' report "CS_N is not low";
				assert dut_get_m_rw_next_byte = '1' report "Byterequest is not active";

				-- Check the data
				addrCalc <= to_integer(unsigned(start_address)) + i;
				wait for 1 ns;
				if addrCalc > 32767 then
					addrCalc <= addrCalc - 32768;
				end if;
				wait for 1 ns;

				assert dut_data_from_fram = simu_fram_data(addrCalc)
					report "Data read is incorrect ->" &
						   "Expected: " & to_string(simu_fram_data(addrCalc)) & 
						   "  Received: " & to_string(dut_data_from_fram) & 
						   "  Address: " & to_hstring(to_unsigned(addrCalc, 15)) severity failure;
				
				if i = amount_of_data - 1 then
					dut_close_m_rw_exchange <= '1';
					closeTransaction <= TRUE;
				else
					dut_another_m_rw_exchange <= '1';
				end if;

				wait until rising_edge(clk);
				wait for 1 ns;
				dut_another_m_rw_exchange <= '0';
				dut_close_m_rw_exchange <= '0';

				-- Wait for the FRAM to be ready
				if dut_fram_busy = '1' then
					if closeTransaction = FALSE then
						-- Are we expecting another byte? If so, wait for the next byte
						wait until rising_edge(dut_get_m_rw_next_byte);
					else
						-- Otherwise, wait for the FRAM to be ready
						wait until dut_fram_busy = '0';
					end if;
				end if;

				wait for 1 ns;
			end loop;
		end procedure;

		procedure test_fram_write_multiple (start_address : std_logic_vector(14 downto 0); data : std_logic_array; amount_of_data : integer) is
		begin
			closeTransaction <= FALSE;
			-- Check that the FRAM is idle
			check_idle;
			-- Start the write operation
			dut_fram_address <= start_address;
			dut_data_to_fram <= data(0);
			dut_start_write_multiple <= '1';
			wait until rising_edge(clk);
			wait for 1 ns;
			dut_start_write_multiple <= '0';

			-- Wait for the FRAM to be ready
			if dut_fram_busy = '1' then
				wait until rising_edge(dut_get_m_rw_next_byte);
			end if;
			wait for 1 ns;

			for i in 0 to amount_of_data - 1 loop
				-- Keep the fram module waiting for a random amount of time
				uniform(seed1, seed2, randomData);
				wait for (randomData * 150 ns);
				-- Make sure the FRAM is still busy and waiting for us
				assert dut_fram_busy = '1' report "FRAM is not busy";
				assert spi_fram_cs_n = '0' report "CS_N is not low";
				assert dut_get_m_rw_next_byte = '1' report "Byterequest is not active";

				-- Check the data
				addrCalc <= to_integer(unsigned(start_address)) + i;
				wait for 1 ns;
				if addrCalc > 32767 then
					addrCalc <= addrCalc - 32768;
				end if;
				wait for 1 ns;

				-- Check the data
				if simu_fram_data(addrCalc) /= data(i) then
					report "" & to_hstring(to_unsigned(addrCalc, 15)) & " " & to_hstring(to_unsigned(i, 15)) & " " & 
							to_hstring(data(i)) & " " & to_hstring(start_address) severity note;
				end if;
				assert simu_fram_data(addrCalc) = data(i)
					report "Data write is incorrect ->" &
						   "Expected: " & to_string(data(i)) & 
						   "  Received: " & to_string(simu_fram_data(addrCalc)) & 
						   "  Address: " & to_hstring(to_unsigned(addrCalc, 15)) severity failure;
				
				if i = amount_of_data - 1 then
					dut_close_m_rw_exchange <= '1';
					closeTransaction <= TRUE;
				else
					dut_another_m_rw_exchange <= '1';
					dut_data_to_fram <= data(i+1);
				end if;
				wait for 1 ns;
		
				wait until rising_edge(clk);
				wait for 1 ns;
				dut_another_m_rw_exchange <= '0';
				dut_close_m_rw_exchange <= '0';
		
				-- Wait for the FRAM to be ready
				if dut_fram_busy = '1' then
					if closeTransaction = FALSE then
						wait until rising_edge(dut_get_m_rw_next_byte);
					else
						wait until dut_fram_busy = '0';
					end if;
				end if;
		
				wait for 1 ns;
			end loop;
		end procedure;

		variable testArray : std_logic_array(0 to 31) := (others => (others => '0'));
	begin
		for i in 0 to 31 loop
			uniform(seed1, seed2, randomData);
			testArray(i) := std_logic_vector(to_unsigned(integer(randomData * 255.0), 8));
		end loop;

		wait for CLK_H_PERIOD;
		dut_reset <= '0';
		wait for 1 ns;

		-- Test the FRAM single read operation
		report "Testing " & to_string(RANDOM_TEST_CYCLES) & " single-read operation" severity note;
		for i in 1 to RANDOM_TEST_CYCLES loop
			uniform(seed1, seed2, randomAddress);
			test_fram_read_single(std_logic_vector(to_unsigned(integer(randomAddress * 32767.0), dut_fram_address'length)));
			wait for 1 ns;
		end loop;

		-- Test the FRAM single write operation
		report "Testing " & to_string(RANDOM_TEST_CYCLES) & " single-write operation" severity note;
		for i in 1 to RANDOM_TEST_CYCLES loop
			uniform(seed1, seed2, randomAddress);
			uniform(seed1, seed2, randomData);
			test_fram_write_single(std_logic_vector(to_unsigned(integer(randomAddress * 32767.0), dut_fram_address'length)),
								   std_logic_vector(to_unsigned(integer(randomData * 255.0), dut_data_to_fram'length)));
			wait for 1 ns;
		end loop;

		-- Test the FRAM multiple read operation
		report "Testing " & to_string(RANDOM_TEST_CYCLES) & " multiple-read operation" severity note;
		for i in 1 to RANDOM_TEST_CYCLES loop
			uniform(seed1, seed2, randomAddress);

			loop -- This loop is to make sure that the read length is more than one, since the test_fram_read_multiple
				 -- function does not support single reads
				uniform(seed1, seed2, randomLength);
				exit when integer(randomLength * 32.0) > 1;
			end loop;
			
			uniform(seed1, seed2, randomLength);

			if integer(randomLength * 32.0) > 1 then
				test_fram_read_multiple(std_logic_vector(to_unsigned(integer(randomAddress * 32767.0), dut_fram_address'length)),
										integer(randomLength * 32.0));
			else
				test_fram_read_single(std_logic_vector(to_unsigned(integer(randomAddress * 32767.0), dut_fram_address'length)));
			end if;
			wait for 1 ns;
		end loop;

		-- Test the FRAM multiple write operation
		report "Testing " & to_string(RANDOM_TEST_CYCLES) & " multiple-write operation" severity note;
		for i in 1 to RANDOM_TEST_CYCLES loop
			uniform(seed1, seed2, randomAddress);
			uniform(seed1, seed2, randomLength);

			if i mod (RANDOM_TEST_CYCLES / 10) = 0 then
				for j in 0 to 31 loop
					-- Make sure we have a different data every now and then
					uniform(seed1, seed2, randomData);
					testArray(j) := std_logic_vector(to_unsigned(integer(randomData * 255.0), 8));
				end loop;
			end if;

			if integer(randomLength * 32.0) > 1 then
				test_fram_write_multiple(std_logic_vector(to_unsigned(integer(randomAddress * 32767.0), dut_fram_address'length)),
										testArray, integer(randomLength * 32.0));
			else
				test_fram_write_single(std_logic_vector(to_unsigned(integer(randomAddress * 32767.0), dut_fram_address'length)),
										testArray(0));
			end if;
			
			wait for 1 ns;
		end loop;

		report "Test over" severity note;
		tb_finished <= TRUE;
		wait;

	end process STIMULI;

end architecture test;