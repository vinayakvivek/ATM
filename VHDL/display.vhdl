library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity display is
	port (
		clk : in STD_LOGIC;
		reset : in STD_LOGIC;
		done_button : in STD_LOGIC;

		read_count : in STD_LOGIC_VECTOR(2 downto 0);
		data_in : in STD_LOGIC_VECTOR (63 downto 0);
		state : in STD_LOGIC_VECTOR(2 downto 0);
		status_from_host : in STD_LOGIC_VECTOR(7 downto 0);
		enough_balance_in_atm : in STD_LOGIC;

		T : in STD_LOGIC;
		D : in STD_LOGIC;

		led_out : out STD_LOGIC_VECTOR(7 downto 0) -- eight LEDs
	);
end display;

architecture Behavioral of display is
	-- for counting from 1 to 7
	signal count5_reg, count5_next : STD_LOGIC_VECTOR(2 downto 0);
	signal count3_reg, count3_next : STD_LOGIC_VECTOR(2 downto 0);
	signal count6_reg, count6_next : STD_LOGIC_VECTOR(2 downto 0);

	--signal n2000_reg, n2000_next : STD_LOGIC_VECTOR(7 downto 0);

	signal start_count5, start_count5_next : STD_LOGIC;
	signal start_count3, start_count3_next : STD_LOGIC;
	signal start_count6, start_count6_next : STD_LOGIC;

	signal n2000_reg, n2000_next : STD_LOGIC_VECTOR(7 downto 0);
	signal n1000_reg ,n1000_next : STD_LOGIC_VECTOR(7 downto 0);
	signal n500_reg, n500_next : STD_LOGIC_VECTOR(7 downto 0);
	signal n100_reg, n100_next : STD_LOGIC_VECTOR(7 downto 0);
	
	signal start_2000_count, start_2000_count_next : STD_LOGIC;
	signal start_1000_count, start_1000_count_next : STD_LOGIC;
	signal start_500_count, start_500_count_next : STD_LOGIC;
	signal start_100_count, start_100_count_next : STD_LOGIC;

	-- define states
	type state_type is (idle, S1, disp_2000, disp_1000, disp_500, disp_100, over, blink_leds, check_status);
	signal state_reg, state_next : state_type; 
begin
	
	process (clk, reset) 
	begin 
		if reset = '1' then
			count5_reg <= "111";
			count3_reg <= "011";
			count6_reg <= "110";

			state_reg <= idle;

			start_count5 <= '0';
			start_count3 <= '0';
			start_count6 <= '0';

			n2000_reg <= (others => '0');
			n1000_reg <= (others => '0');
			n500_reg <= (others => '0');
			n100_reg <= (others => '0');

			start_2000_count <= '0';
			start_1000_count <= '0';
			start_500_count <= '0';
			start_100_count  <= '0';

		elsif (rising_edge(clk)) then
			count5_reg <= count5_next;
			count3_reg <= count3_next;
			count6_reg <= count6_next;

			state_reg <= state_next;

			start_count5 <= start_count5_next;
			start_count3 <= start_count3_next;
			start_count6 <= start_count6_next;

			n2000_reg <= n2000_next;
			n1000_reg <= n1000_next;
			n500_reg <= n500_next;
			n100_reg <= n100_next;

			start_2000_count <= start_2000_count_next;
			start_1000_count <= start_1000_count_next ;
			start_500_count <=	start_500_count_next ;
			start_100_count  <=	start_100_count_next ;
		end if;
	end process;

	-- counter 5
	process (T, count5_reg, start_count5)
	begin
		count5_next <= count5_reg;
		if start_count5 = '0' then
			count5_next <= "110"; -- 6 because, last blinking will last only for one clock cycle and will not be seen
		elsif (rising_edge(T)) then
			count5_next <= count5_reg - '1';
		end if;
	end process;

	-- counter 3
	process (T, count3_reg, start_count3)
	begin
		count3_next <= count3_reg;
		if start_count3 = '0' then
			count3_next <= "011";
		elsif (rising_edge(T)) then
			count3_next <= count3_reg - '1';
		end if;
	end process;

	--counter 6
	process (T, count6_reg, start_count6)
	begin
		count6_next <= count6_reg;
		if start_count6 = '0' then
			count6_next <= "110";
		elsif (rising_edge(T)) then
			count6_next <= count6_reg - '1';
		end if;
	end process;

	-- 2000 notes counter
	process (D, n2000_reg, start_2000_count, data_in)
	begin
		n2000_next <= n2000_reg;

		if (rising_edge(D)) then
			if start_2000_count = '0' then
				n2000_next <= data_in(39 downto 32);
			elsif n2000_reg = 0 then
				n2000_next <= (others => '0');
			else
				n2000_next <= n2000_reg - '1';
			end if;
		end if;
	end process;

	-- 1000 notes counter
	process (D, n1000_reg, start_1000_count, data_in)
	begin
		n1000_next <= n1000_reg;

		if (rising_edge(D)) then
			if start_1000_count = '0' then
				n1000_next <= data_in(47 downto 40);
			elsif n1000_reg = 0 then
				n1000_next <= (others => '0');
			else 
				n1000_next <= n1000_reg - '1';
			end if;
		end if;
	end process;

	-- 500 notes counter
	process (D, n500_reg, start_500_count, data_in)
	begin
		n500_next <= n500_reg;

		if (rising_edge(D)) then
			if start_500_count = '0' then
				n500_next <= data_in(55 downto 48);
			elsif n500_reg = 0 then
				n500_next <= (others => '0');
			else 
				n500_next <= n500_reg - '1';
			end if;
		end if;
	end process;

	-- 100 counter
	process (D, n100_reg, start_100_count , data_in)
	begin
		n100_next <= n100_reg;
	
		if (rising_edge(D)) then
			if start_100_count  = '0' then
				n100_next <= data_in(63 downto 56);
			elsif n100_reg = 0 then
				n100_next <= (others => '0');
			else 
				n100_next <= n100_reg - '1'; 
			end if;
		end if;
	end process;


	-- LEDs and 7-seg display
	process (
		state_reg, state, T, D, read_count, enough_balance_in_atm, status_from_host, 
		count5_reg, count6_reg, count3_reg,
		start_count5, start_count3, start_count6,
		start_2000_count, start_1000_count, start_100_count , start_500_count, 
		n2000_reg, n100_reg, n1000_reg, n500_reg, done_button)
	begin
		led_out <= x"00";

		
		start_count5_next <= start_count5;
		start_count3_next <= start_count3;
		start_count6_next <= start_count6;

		start_2000_count_next <= start_2000_count;
		start_1000_count_next <= start_1000_count ;
		start_500_count_next <= start_500_count ;
		start_100_count_next <= start_100_count ;
		state_next <= state_reg;

		case state_reg is

			when idle =>
				led_out <= x"00";
				if (state = "001") then
					-- state is now get_user_input
					state_next <= S1;
				end if;

			when S1 =>
				case state is

					when "000" =>
						led_out(4) <= T;
						led_out(2) <= T;
						state_next <= idle;

					when "001" =>
						-- getting user input
						led_out(0) <= T;
						led_out(3 downto 1) <= read_count;

					when "010" =>
						-- communicating with backend
						led_out(0) <= T;
						led_out(1) <= T;

					when "011" =>
						-- checking status
						led_out(0) <= T;
						led_out(2) <= T;

					when "100" =>
						-- loading cash
						start_count5_next <= '1';
						if count5_reg /= 0 then
							led_out(0) <= T;
							led_out(1) <= T;
							led_out(2) <= T;
						else
							state_next <= over;		
						end if;

					when "101" =>
						-- dispensing cash
						start_count5_next <= '1';
						if count5_reg /= 0 then
							led_out(0) <= T;
							led_out(1) <= T;
							led_out(2) <= T;
							led_out(3) <= T;
						else
							--n_next <= data_in(39 downto 32);
							state_next <= check_status;
						end if;

					when others =>
						state_next <= idle;

				end case;

			when check_status =>
				if (state = "101") then
					if status_from_host = x"01" AND enough_balance_in_atm = '1' then
						-- dispense 2000 notes
						--n_next <= data_in(39 downto 32);
						state_next <= disp_2000;
						start_2000_count_next <= '1';

					elsif status_from_host = x"02" then
						--count5_next <= "011";
						state_next <= blink_leds;
						start_count3_next <= '1';

					elsif status_from_host = x"01" AND enough_balance_in_atm = '0' then
						--count5_next <= "110";
						state_next <= blink_leds;
						start_count6_next <= '1';

					else 

						
					end if;
				end if;

			when blink_leds =>
				--start_count_next <= "11";
				if (state = "101") then
					if start_count3 = '1' then
						if count3_reg /= 0 then
							led_out(4) <= T;
							led_out(5) <= T;
							led_out(6) <= T;
							led_out(7) <= T;
						else 
							state_next <= over;
						end if;
					elsif start_count6 = '1' then
						if count6_reg /= 0 then
							led_out(4) <= T;
							led_out(5) <= T;
							led_out(6) <= T;
							led_out(7) <= T;
						else 
							state_next <= over;
						end if;
					end if;
				end if;

			when disp_2000 =>
				if (state = "101") then
					if n2000_reg = 0 then
						state_next <= disp_1000;
					else 
						led_out(4) <= D;
					end if;
				end if;
			----	--state_next <= over;

			when disp_1000 =>
				start_1000_count_next <= '1';
				if (state = "101") then
					if n1000_reg /= 0 then
						led_out(5) <= D;
					else 
						state_next <= disp_500;
					end if;
				end if;

			when disp_500 =>
				start_500_count_next <= '1';
				if (state = "101") then
					if n500_reg /= 0 then
						led_out(6) <= D;
					else 
						--n_next <= data_in(63 downto 56);
						state_next <= disp_100;
					end if;
				end if;

			when disp_100 =>
				start_100_count_next <= '1';
				if (state = "101") then
					if n100_reg /= 0 then
						led_out(7) <= D;
					else 
						state_next <= over;
					end if;
				end if;

			when over =>
				
				if done_button = '1' then
					state_next <= idle;

					start_count5_next <= '0';
					start_count3_next <= '0';
					start_count6_next <= '0';

					start_2000_count_next <= '0';
					start_1000_count_next <= '0';
					start_500_count_next <= '0';
					start_100_count_next <= '0';

				end if;


			when others =>
				state_next <= over;
		end case;
	end process;
end Behavioral;

