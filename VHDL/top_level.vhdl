library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity top_level is
    Port(fx2Clk_in : in  STD_LOGIC;
        reset : in  STD_LOGIC;
        sw_in : in  STD_LOGIC_VECTOR (7 downto 0);
        next_data_in : in  STD_LOGIC;
        start : in STD_LOGIC;
        done : in STD_LOGIC;

        -- ports for USB communication
        -- FX2LP interface ---------------------------------------------------------------------------
		--fx2Clk_in      : in    std_logic;                    -- 48MHz clock from FX2LP
		fx2Addr_out    : out   std_logic_vector(1 downto 0); -- select FIFO: "00" for EP2OUT, "10" for EP6IN
		fx2Data_io     : inout std_logic_vector(7 downto 0); -- 8-bit data to/from FX2LP

		-- When EP2OUT selected:
		fx2Read_out    : out   std_logic;                    -- asserted (active-low) when reading from FX2LP
		fx2OE_out      : out   std_logic;                    -- asserted (active-low) to tell FX2LP to drive bus
		fx2GotData_in  : in    std_logic;                    -- asserted (active-high) when FX2LP has data for us

		-- When EP6IN selected:
		fx2Write_out   : out   std_logic;                    -- asserted (active-low) when writing to FX2LP
		fx2GotRoom_in  : in    std_logic;                    -- asserted (active-high) when FX2LP has room for more data from us
		fx2PktEnd_out  : out   std_logic;                    -- asserted (active-low) when a host read needs to be committed early

		
        led_out : out  STD_LOGIC_VECTOR (7 downto 0)
    );
end top_level;

architecture Behavioral of top_level is
    
	signal debounced_next_data_in_button: STD_LOGIC;
	
	signal debounced_start: STD_LOGIC;
	signal debounced_done: STD_LOGIC;
	signal debounced_reset: STD_LOGIC;

	signal multi_byte_data_read: STD_LOGIC_VECTOR (63 downto 0);	-- user input
	signal data_from_host: STD_LOGIC_VECTOR (63 downto 0);			-- encrypted data recieved from host 
	signal ciphertext_out: STD_LOGIC_VECTOR (63 downto 0);			-- encrypted user input
	signal plaintext_out: STD_LOGIC_VECTOR (63 downto 0);			-- decypted host data
	--signal data_to_be_displayed: STD_LOGIC_VECTOR (63 downto 0);

	signal encryption_over: STD_LOGIC;
	signal decryption_over: STD_LOGIC;
	signal end_comm : STD_LOGIC;
	signal system_state: STD_LOGIC;

	signal start_communication : STD_LOGIC;
	signal start_encryption : STD_LOGIC;
	signal start_decryption : STD_LOGIC;

	signal done_input : STD_LOGIC;


	-- Channel read/write interface -----------------------------------------------------------------
	signal chanAddr  : std_logic_vector(6 downto 0);  -- the selected channel (0-127)

	-- Host >> FPGA pipe:
	signal h2fData   : std_logic_vector(7 downto 0);  -- data lines used when the host writes to a channel
	signal h2fValid  : std_logic;                     -- '1' means "on the next clock rising edge, please accept the data on h2fData"
	signal h2fReady  : std_logic;                     -- channel logic can drive this low to say "I'm not ready for more data yet"

	-- Host << FPGA pipe:
	signal f2hData   : std_logic_vector(7 downto 0);  -- data lines used when the host reads from a channel
	signal f2hValid  : std_logic;                     -- channel logic can drive this low to say "I don't have data ready for you"
	signal f2hReady  : std_logic;                     -- '1' means "on the next clock rising edge, put your next byte of data on f2hData"
	-- ----------------------------------------------------------------------------------------------

	-- Needed so that the comm_fpga_fx2 module can drive both fx2Read_out and fx2OE_out
	signal fx2Read   : std_logic;

	-- Reset signal so host can delay startup
	signal fx2Reset  : std_logic;
	-------------------------------------------------------------------------------------------------
	
	-------------------------------------------------------------------------------------------------
	signal state : STD_LOGIC_VECTOR(2 downto 0);	-- 5 states in binary
	-- 000 - Ready
	-- 001 - get user input
	-- 010 - comm with fpga
	-- 011 - check status
	-- 100 - load cash
	-- 101 - dispence cash
	-------------------------------------------------------------------------------------------------

	signal status_from_host : STD_LOGIC_VECTOR(7 downto 0);
	signal enough_balance_in_atm : STD_LOGIC;
	signal timerSig : STD_LOGIC;
	signal timer2Sig: STD_LOGIC;
	signal read_count : STD_LOGIC_VECTOR(2 downto 0);

	-- cash details
	--signal n2000, n1000, n500, n100 : std_logic_vector(7 downto 0) := (others => '0');
	--signal n2000_next, n1000_next, n500_next, n100_next : std_logic_vector(7 downto 0) := (others => '0');
begin

	deb_next_in: entity work.debouncer
        port map (
        	clk => fx2Clk_in,
            button => next_data_in,
            button_deb => debounced_next_data_in_button);

	deb_reset: entity work.debouncer
        port map (
        	clk => fx2Clk_in,
            button => reset,
            button_deb => debounced_reset);

	deb_start: entity work.debouncer
		port map (
			clk => fx2Clk_in,
	        button => start,
            button_deb => debounced_start);

	deb_done: entity work.debouncer
		port map (
			clk => fx2Clk_in,
            button => done,
            button_deb => debounced_done);

	data_inp: entity work.read_multiple_data_bytes
        port map (
        	clk => fx2Clk_in,
            reset => debounced_reset,
            data_in => sw_in,
            next_data => debounced_next_data_in_button,
            read_count => read_count,
            done => done_input,
            done_button => debounced_done,
            data_read => multi_byte_data_read);

	encrypt: entity work.encrypter
        port map (
        	clk => fx2Clk_in,
	        reset => debounced_reset,
            plaintext => multi_byte_data_read,
            start => start_encryption,
            ciphertext => ciphertext_out,
            done_button => debounced_done,
            done => encryption_over);

	decrypt: entity work.decrypter
        port map (
        	clk => fx2Clk_in,
            reset => debounced_reset,
            ciphertext => data_from_host,
            start => start_decryption,
            plaintext => plaintext_out,
            done_button => debounced_done,
            done => decryption_over);

	seq: entity work.sequencer 
		port map (
			clk => fx2Clk_in,
  			reset => debounced_reset,
  			start => debounced_start,

  			read_over => done_input,
  			done => debounced_done,

  			user_status => status_from_host,

  			encryption_over => encryption_over,
  			decryption_over => decryption_over,
  			end_comm => end_comm,

  			data_user_input => multi_byte_data_read,
  			data_from_host_decrypted => plaintext_out,

  			state => state,
  			enough_balance_in_atm => enough_balance_in_atm,
  			start_comm => start_communication,
   			start_encryption => start_encryption,
  			start_decryption => start_decryption
  		);

	-- CommFPGA module
	fx2Read_out <= fx2Read;
	fx2OE_out <= fx2Read;
	fx2Addr_out(0) <=  -- So fx2Addr_out(1)='0' selects EP2OUT, fx2Addr_out(1)='1' selects EP6IN
		'0' when fx2Reset = '0'
		else 'Z';
	comm_fpga_fx2 : entity work.comm_fpga_fx2
		port map(
			clk_in         => fx2Clk_in,
			reset_in       => '0',
			reset_out      => fx2Reset,
			
			-- FX2LP interface
			fx2FifoSel_out => fx2Addr_out(1),
			fx2Data_io     => fx2Data_io,
			fx2Read_out    => fx2Read,
			fx2GotData_in  => fx2GotData_in,
			fx2Write_out   => fx2Write_out,
			fx2GotRoom_in  => fx2GotRoom_in,
			fx2PktEnd_out  => fx2PktEnd_out,

			-- DVR interface -> Connects to application module
			chanAddr_out   => chanAddr,
			h2fData_out    => h2fData,
			h2fValid_out   => h2fValid,
			h2fReady_in    => h2fReady,
			f2hData_in     => f2hData,
			f2hValid_in    => f2hValid,
			f2hReady_out   => f2hReady
		);


	io_interface : entity work.io_interface
		port map(
			clk => fx2Clk_in,
			reset => reset,

			start_comm => start_communication,
			enough_balance_in_atm => enough_balance_in_atm,
			done_button => debounced_done,

			-- DVR interface -> Connects to comm_fpga module
			chanAddr_in  => chanAddr,
			h2fData_in   => h2fData,
			h2fValid_in  => h2fValid,
			h2fReady_out => h2fReady,
			f2hData_out  => f2hData,
			f2hValid_out => f2hValid,
			f2hReady_in  => f2hReady,

			--state : in STD_LOGIC_VECTOR(2 downto 0);	-- 5 states in binary
			status_from_host => status_from_host,
			data_from_user_encrypted => ciphertext_out,
			data_from_host => data_from_host,

			end_comm => end_comm
		);

	display : entity work.display
		port map (
			clk => fx2Clk_in,
			reset => reset,
			done_button => debounced_done,

			read_count => read_count,
			data_in => plaintext_out,
			state => state,
			status_from_host => status_from_host,
			enough_balance_in_atm => enough_balance_in_atm,
			T => timerSig,
			D => timer2Sig,

			led_out => led_out
		);

	timer : entity work.timer
		port map (
			clk => fx2Clk_in,
			reset => reset,
			T => timerSig,
			D => timer2Sig
		);

end Behavioral;