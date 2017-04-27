library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity sequencer is
	port (
			clk : in STD_LOGIC;
			reset : in STD_LOGIC;
			start : in STD_LOGIC;

			read_over : in STD_LOGIC;	-- done with input
			done : in STD_LOGIC;	-- done using ATM

			user_status : in STD_LOGIC_VECTOR(7 downto 0);

			encryption_over : in STD_LOGIC;
			decryption_over : in STD_LOGIC;
			end_comm : in STD_LOGIC;

			data_user_input: in STD_LOGIC_VECTOR (63 downto 0);
			data_from_host_decrypted: in STD_LOGIC_VECTOR (63 downto 0);

			state : out STD_LOGIC_VECTOR(2 downto 0);	-- 5 states in binary
			enough_balance_in_atm : out STD_LOGIC;		-- enough balance to dispense cash in ATM
			start_comm : out STD_LOGIC;
			start_encryption : out STD_LOGIC;
			start_decryption : out STD_LOGIC);
end sequencer;

architecture Behavioral of sequencer is
	signal n2000, n1000, n500, n100 : std_logic_vector(7 downto 0) := (others => '0');
	signal n2000_next, n1000_next, n500_next, n100_next : std_logic_vector(7 downto 0) := (others => '0');

	signal enough_balance, enough_balance_next : STD_LOGIC;

		-- define states
	type state_type is (ready, get_user_input,
						comm_with_backend,
						check_status,
						loading_cash, 
						dispensing_cash_1,	-- sufficient balance, enough money in atm
						dispensing_cash_2,  -- insufficient balance
						dispensing_cash_3,  -- sufficient balance, not enough money in atm
						dispense_over); 
	signal state_reg, state_next : state_type;

	--signal enough_balance, enough_balance_next : STD_LOGIC;
begin
	
	-- set registers
	process(clk, reset)
	begin
		if reset = '1' then
			state_reg <= ready;
			n2000 <= (others => '0'); 
			n1000 <= (others => '0'); 
			n500 <= (others => '0'); 
			n100 <= (others => '0'); 
			enough_balance <= '0';
		elsif (clk'event and clk = '1') then
			state_reg <= state_next;
			n2000 <= n2000_next;
			n1000 <= n1000_next;
			n500 <= n500_next;
			n100 <= n100_next;
			enough_balance <= enough_balance_next; 
		end if;
	end process;

	-- sequencer
	Sequencer: process(state_reg, n2000, n1000, n500, n100, start, 
		read_over, done, encryption_over, decryption_over, data_user_input,
		data_from_host_decrypted, end_comm, user_status, enough_balance)
	begin
		state_next <= state_reg;

		n2000_next <= n2000;
		n1000_next <= n1000;
		n500_next <= n500;
		n100_next <= n100;

		state <= "000";
		start_comm <= '0';
		start_encryption <= '0';
		start_decryption <= '0';

		enough_balance_next <= enough_balance;
		--if (rising_edge(done)) 	

		case state_reg is
			when ready =>
				state <= "000";
				if start = '1' then
					state_next <= get_user_input;
				end if;

			when get_user_input =>
				state <= "001";
				-- read using read entity from module1
				if read_over = '1' then
					if ((n2000 >= data_user_input(39 downto 32)) AND 
						(n1000 >= data_user_input(47 downto 40)) AND  
						(n500 >= data_user_input(55 downto 48)) AND 
						(n100 >= data_user_input(63 downto 56))) then
						enough_balance_next <= '1';
					else 
						enough_balance_next <= '0';
					end if;
					state_next <= comm_with_backend;
				end if;

			when comm_with_backend =>
				state <= "010";
				start_encryption <= '1';

				if encryption_over = '1' then
					start_comm <= '1';
				end if;

				if end_comm = '1' then
					state_next <= check_status;
				end if;

			when check_status =>
				state <= "011";
				start_decryption <= '1';
				--start_encryption <= '0';

				if (decryption_over = '1') then
					--start_decryption <= '0';
					if (user_status = x"01" AND enough_balance = '1') then
						state_next <= dispensing_cash_1;
					elsif (user_status = x"02") then
						state_next <= dispensing_cash_2;
					elsif (user_status = x"01" AND enough_balance = '0') then
						state_next <= dispensing_cash_3;
					elsif (user_status = x"03") then
						state_next <= loading_cash;
					else
						state_next <= ready;
					end if;
				end if;

			when loading_cash =>
				state <= "100";
				-- load cash
				n2000_next <= data_from_host_decrypted(39 downto 32);
				n1000_next <= data_from_host_decrypted(47 downto 40);
				n500_next <= data_from_host_decrypted(55 downto 48);
				n100_next <= data_from_host_decrypted(63 downto 56);

				if done = '1' then
					state_next <= ready;
				end if;

			when dispensing_cash_1 =>
				state <= "101";
				-- sufficient balance, enough money in atm
				n2000_next <= n2000 - data_from_host_decrypted(39 downto 32);
				n1000_next <= n1000 - data_from_host_decrypted(47 downto 40);
				n500_next <= n500 - data_from_host_decrypted(55 downto 48);
				n100_next <= n100 - data_from_host_decrypted(63 downto 56);

				state_next <= dispense_over;

			when dispensing_cash_2 =>
				state <= "101";
				-- insufficient balance
				state_next <= dispense_over;

			when dispensing_cash_3 =>
				state <= "101";
				-- sufficient balance, not enough money in atm
				state_next <= dispense_over;

			when dispense_over =>
				state <= "101";

				if done = '1' then
					state_next <= ready;
					enough_balance_next <= '0';
				end if;

		end case;

	end process;

	enough_balance_in_atm <= enough_balance;

end Behavioral;