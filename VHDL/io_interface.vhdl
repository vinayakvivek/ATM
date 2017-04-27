library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity io_interface is
	port (
		clk : in STD_LOGIC;
		reset : in STD_LOGIC;

		start_comm : in STD_LOGIC;
		enough_balance_in_atm : in STD_LOGIC;
		done_button : in STD_LOGIC;

		-- DVR interface -----------------------------------------------------------------------------
		chanAddr_in  : in  std_logic_vector(6 downto 0);  -- the selected channel (0-17)

		-- Host >> FPGA pipe:
		h2fData_in   : in  std_logic_vector(7 downto 0);  -- data lines used when the host writes to a channel
		h2fValid_in  : in  std_logic;                     -- '1' means "on the next clock rising edge, please accept the data on h2fData"
		h2fReady_out : out std_logic;                     -- channel logic can drive this low to say "I'm not ready for more data yet"

		-- Host << FPGA pipe:
		f2hData_out  : out std_logic_vector(7 downto 0);  -- data lines used when the host reads from a channel
		f2hValid_out : out std_logic;                     -- channel logic can drive this low to say "I don't have data ready for you"
		f2hReady_in  : in  std_logic;                     -- '1' means "on the next clock rising edge, put your next byte of data on f2hData"


		--state : in STD_LOGIC_VECTOR(2 downto 0);	-- 5 states in binary
		status_from_host : out STD_LOGIC_VECTOR(7 downto 0);
		data_from_user_encrypted : in STD_LOGIC_VECTOR (63 downto 0);
		data_from_host : out STD_LOGIC_VECTOR (63 downto 0);

		end_comm : out STD_LOGIC
	);
end io_interface;

architecture Behavioral of io_interface is

	type channel_array is array (17 downto 0) of std_logic_vector(7 downto 0);
	signal ch_array_reg, ch_array_next : channel_array;
	--signal n_reg, n_next : std_logic_vector(6 downto 0);	

	-- define states
	type state_type is (idle, S1, S2, S3, reset_state);
	signal state_reg, state_next : state_type; 

begin

	-- state reg
	process(clk, reset)
	begin
		if reset = '1' then
			state_reg <= idle;
			ch_array_reg <= (others => (others => '0'));
			--n_reg <= (others => '0');
		elsif (clk'event and clk = '1') then
			state_reg <= state_next;
			ch_array_reg <= ch_array_next;
			--n_reg <= n_next;
		end if;
	end process;

	process (state_reg, ch_array_reg, start_comm, data_from_user_encrypted,
			 h2fData_in, h2fValid_in, chanAddr_in, enough_balance_in_atm, done_button)
	begin
		state_next <= state_reg;
		ch_array_next <= ch_array_reg;
		--data_from_host <= (others => '0');
		status_from_host <= x"00";
		end_comm <= '0';

		data_from_host(7 downto 0) <= ch_array_reg(10);
		data_from_host(15 downto 8) <= ch_array_reg(11);
		data_from_host(23 downto 16) <= ch_array_reg(12);
		data_from_host(31 downto 24) <= ch_array_reg(13);
		data_from_host(39 downto 32) <= ch_array_reg(14);
		data_from_host(47 downto 40) <= ch_array_reg(15);
		data_from_host(55 downto 48) <= ch_array_reg(16);
		data_from_host(63 downto 56) <= ch_array_reg(17);
		--n_next <= n_reg;

		case state_reg is
			when idle => 
				if (start_comm = '1') then
					state_next <= S1;
				end if;

			when S1 => 
				if enough_balance_in_atm = '1' then
					ch_array_next(0) <= x"01";
				else 
					ch_array_next(0) <= x"02";
				end if;
				
				ch_array_next(1) <= data_from_user_encrypted(7 downto 0);
				ch_array_next(2) <= data_from_user_encrypted(15 downto 8);
				ch_array_next(3) <= data_from_user_encrypted(23 downto 16);
				ch_array_next(4) <= data_from_user_encrypted(31 downto 24);
				ch_array_next(5) <= data_from_user_encrypted(39 downto 32);
				ch_array_next(6) <= data_from_user_encrypted(47 downto 40);
				ch_array_next(7) <= data_from_user_encrypted(55 downto 48);
				ch_array_next(8) <= data_from_user_encrypted(63 downto 56);

				ch_array_next(9) <= x"00";
				ch_array_next(10) <= x"00";
				ch_array_next(11) <= x"00";
				ch_array_next(12) <= x"00";
				ch_array_next(13) <= x"00";
				ch_array_next(14) <= x"00";
				ch_array_next(15) <= x"00";
				ch_array_next(16) <= x"00";
				ch_array_next(17) <= x"00";

				state_next <= S2;

			when S2 =>

				if h2fValid_in = '1' then
					ch_array_next(to_integer(unsigned(chanAddr_in))) <= h2fData_in;
				end if;

				if (ch_array_reg(9) /= x"00") then
					ch_array_next(0) <= x"03";
					state_next <= S3;
				end if;

			when S3 =>
				status_from_host <= ch_array_reg(9);
				--data_from_host(7 downto 0) <= ch_array_reg(10);
				--data_from_host(15 downto 8) <= ch_array_reg(11);
				--data_from_host(23 downto 16) <= ch_array_reg(12);
				--data_from_host(31 downto 24) <= ch_array_reg(13);
				--data_from_host(39 downto 32) <= ch_array_reg(14);
				--data_from_host(47 downto 40) <= ch_array_reg(15);
				--data_from_host(55 downto 48) <= ch_array_reg(16);
				--data_from_host(63 downto 56) <= ch_array_reg(17);
				end_comm <= '1';

				if (done_button = '1') then
					state_next <= reset_state;
				end if;

			when reset_state =>
				ch_array_next <= (others => (others => '0'));
				state_next <= idle;

		end case;
	end process;

	---- read
	f2hData_out <= ch_array_reg(to_integer(unsigned(chanAddr_in))) when f2hReady_in = '1' else x"00";
	
	---- Assert that there's always data for reading, and always room for writing
	f2hValid_out <= '1';
	h2fReady_out <= '1';     

end Behavioral;
