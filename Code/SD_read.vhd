library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity SD_read is

    Port ( sys_clk : in STD_LOGIC;    -- 100MHz
         reset     : in STD_LOGIC;
         en_25MHz  : in STD_LOGIC;
         en_800kHz : in STD_LOGIC;
         read_en   : in STD_LOGIC;    -- start reading a block from SD card

         miso : in STD_LOGIC;         -- SD card signals
         mosi : out STD_LOGIC;
         cs   : out STD_LOGIC;
         sclk : out STD_LOGIC;

         byte_ready : out STD_LOGIC;                      -- new byte waits on the output (PCM_data)
         PCM_data   : out STD_LOGIC_VECTOR (7 downto 0);  -- should change with frequency: 44 100Hz
         sd_audio   : out std_logic;
         
         BTNC : in STD_LOGIC;
         BTNL : in STD_LOGIC;
         BTNR : in STD_LOGIC);

end SD_read;

architecture Behavioral of SD_read is

    signal cmd_out : std_logic_vector (55 downto 0) := (others => '1');             -- encoded command
    signal sclk_sig : std_logic := '0';                                             -- SCLK for SPI
    signal address : std_logic_vector (31 downto 0) := x"00002000";                 -- address from which to read
    signal recv_data : std_logic_vector (7 downto 0);                               -- byte that was read from SD card
    signal bit_counter : unsigned (7 downto 0);                                     -- counts bits for SPI (max 255)
    signal byte_counter : unsigned (8 downto 0);                                    -- counts bytes read (max 511)
    signal boot_counter : unsigned (26 downto 0) := "101111101011110000100000000";  -- counts to 100M (4 sec)
    signal pausePulse, backPulse, forwardPulse : std_logic;                         -- button signals
    signal pause : std_logic := '1';                                                -- '1' when music is paused

    -- states to control the commands
    type state_type is ( RST , INIT, SEND_CMD , WAIT_RESPONSE , READ_MISO , CMD_READ , WAIT_DATA , READ_DATA , READ_CRC , CMD0 , CHECK_RESPONSE_CMD0 , CMD8 , CMD55, CMD41, CHECK_RESPONSE_ACMD41 );
    signal state : state_type := RST;
    signal return_state : state_type := RST;    -- return state after reading a byte from miso

    -- Debouncer for the buttons
    component Dbncr is
    generic(
        NR_OF_CLKS : integer := 4095);
    port(
        clk_i : in std_logic;
        sig_i : in std_logic;
        pls_o : out std_logic);
    end component;
        
begin

    -- outputs
    sclk <= sclk_sig;
    mosi <= cmd_out(55);
    sd_audio <= not pause;

    -- button debouncers
    Btn1: Dbncr
    generic map(
        NR_OF_CLKS  => 4095)
    port map(
        clk_i => sys_clk,
        sig_i => BTNC,
        pls_o => pausePulse);

    Btn2: Dbncr
    generic map(
        NR_OF_CLKS  => 4095)
    port map(
        clk_i => sys_clk,
        sig_i => BTNL,
        pls_o => backPulse);
        
    Btn3: Dbncr
    generic map(
        NR_OF_CLKS  => 4095)
    port map(
        clk_i => sys_clk,
        sig_i => BTNR,
        pls_o => forwardPulse);

    -- controller
    process(sys_clk)
    begin
        if rising_edge(sys_clk) then
            
            -- handle button (pause)
            if (pausePulse = '1') then
                pause <= not pause;
            end if;
            
			-- Addresses:
			--	microSD is split into 512 Byte sectors. Each sector takes up one address and the 0th sector is at address: x"00002000" (so the 1st sector is at x"00002001", 2nd at x"00002002", etc.)
			--	the sectors can be seen and modified using HxD app
			--	we have put three songs one after the other to the start of microSD card:
			--		First song address:  	 x"00002000" (at sector 0)
			--		Second song address: 	 x"0000675C" (at sector 18,268)
			--		Third song address:		 x"0000BE00" (at sector 40,448)
			--		End third song address:	 x"0000FB18" (at sector 56,088)
			
            -- handle button (back)
            if (backPulse = '1' and to_integer(unsigned(address)) < 26596) then
                address <= x"00002000";						-- 	   =0x67E4	if we are in the first song OR at the start of the second song (address slightly shifted),
															--				go to the start of the first song
			elsif (backPulse = '1' and to_integer(unsigned(address)) < 48776) then
                address <= x"0000675C";						-- 	   =0xBE88	if we are in the second song OR at the start of the third song (address slightly shifted),
															--				go to the start of the second song
			elsif (backPulse = '1') then
                address <= x"0000BE00";						--				else go to the start of the third song
            end if;
            
            -- handle button (forward)
            if (forwardPulse = '1' and to_integer(unsigned(address)) < 26460) then
                address <= x"0000675C";						--		  =0x675C	if we are in the first song, go to the start of the second song
            elsif (forwardPulse = '1' and to_integer(unsigned(address)) < 48640) then
                address <= x"0000BE00";						--		  =0xBE00	if we are in the second song, go to the start of the third song
            end if;
            
            if (to_integer(unsigned(address)) > 64280) then
                address <= x"00002000";						-- 64280 = 0xFB18 if we are at the end of the third song, go to the start of the first song
            end if;

            -- handle reset switch
            if (reset = '1') then
                state <= RST;
                sclk_sig <= '0';
                boot_counter <= "101111101011110000100000000";
            end if;

            -- in INIT state SPI needs slower clock
            if (state = INIT and en_800kHz = '1') then
                if (bit_counter = 0) then
                    cs <= '0';
                    state <= CMD0;                      -- go to initialization procedure
                else
                    bit_counter <= bit_counter - 1;
                    sclk_sig <= not sclk_sig;           -- generate slow SCLK (400kHz)
                end if;
            end if;


            -- handle states for SPI protocol - FSM
            if (en_25MHz = '1') then     -- 25MHz rising edge

                case (state) is
                    when RST =>     -- wait in reset state for 4 sec (boot)
                        address <= x"00002000";
                        sclk_sig <= '0';
                        cmd_out <= (others => '1');
                        recv_data <= (others => '0');
                        byte_ready <= '0';
                        pause <= '1';
                        cs <= '1';
                        if (boot_counter = 0) then
                            bit_counter <= "10100000";  -- 160
                            state <= INIT;
                        else
                            boot_counter <= boot_counter - 1;
                        end if;

                    when INIT =>    -- count to 160 bits and generate SCLK (80 periods)
                        null;       -- handled above, do nothing

                    when SEND_CMD =>    		-- send command + handle response + return to specified state
                        if (sclk_sig = '1') then
                            if (bit_counter = 0) then
                                state <= WAIT_RESPONSE;
                            else
                                bit_counter <= bit_counter - 1;
                                cmd_out <= cmd_out(54 downto 0) & '1';  -- shift command to the left and send top bit
                            end if;
                        end if;
                        sclk_sig <= not sclk_sig;

                    when WAIT_RESPONSE =>
                        if (sclk_sig = '1') then
                            if (miso = '0') then                -- start of a response from SD card
                                recv_data <= (others => '1');
                                recv_data(0) <= '0';
                                bit_counter <= "00000110";      -- response has 7 bits (R1)
                                state <= READ_MISO;

                                if (return_state = CMD55) then  -- CMD8 precedes CMD55
                                    bit_counter <= "00100110";  -- CMD8 has 39bit response (R7)
                                end if;
                            end if;
                        end if;
                        sclk_sig <= not sclk_sig;

                    when READ_MISO =>                   -- read "bit_counter" bits of data from SD card (miso pin)
                        byte_ready <= '0';
                        if (sclk_sig = '1') then
                            recv_data <= recv_data(6 downto 0) & miso; -- shift data to the left
                            if (bit_counter = 0) then
                                state <= return_state;
                            else
                                bit_counter <= bit_counter - 1;
                            end if;
                        end if;
                        sclk_sig <= not sclk_sig;
                        
                        

                    when CMD_READ =>
                        if (read_en = '1' and pause = '0') then             -- start reading when one block of RAM has been read
                            cmd_out <= x"FF51" & address & x"FF";           -- 16bit + 32bit + 8bit = 56bit (0x51 = CMD17)
                            address <= std_logic_vector(unsigned(address) + 1);
                            bit_counter <= "00110111"; -- 55
                            state <= SEND_CMD;				-- send command and read the response
                            return_state <= WAIT_DATA;		-- then start waiting the data stream from SD card
                        end if;

                    when WAIT_DATA =>                        -- wait data stream from SD card
                        if (sclk_sig = '1') then
                            if (miso = '0') then             -- data packet has started
                                byte_counter <= "111111111"; -- 511
                                bit_counter <= "00000111";   -- 7
                                state <= READ_MISO;				-- start of the data stream, read 1B
                                return_state <= READ_DATA;      -- then start reading the next bytes
                            end if;
                        end if;
                        sclk_sig <= not sclk_sig;

                    when READ_DATA =>
                        PCM_data <= recv_data;			-- byte has been read, send it to the output (RAM)
                        byte_ready <= '1';              -- tell RAM_controller that a new byte is on the output
                        
                        if (byte_counter /= 0) then			        -- if we haven't read all 512 bytes:
                            byte_counter <= byte_counter - 1;
                            bit_counter <= "00000111";  -- 7
                            state <= READ_MISO;                     -- read next Byte of data
                            return_state <= READ_DATA;              -- then continue in current state
                        else								        -- else (we have read all 512 bytes):
                            bit_counter <= "00000111";  -- 7
                            state <= READ_MISO;                     -- read first Byte of CRC
                            return_state <= READ_CRC;               -- then start reading the second CRC byte
                        end if;

                    when READ_CRC =>
                        bit_counter <= "00000111";  -- 7
                        state <= READ_MISO;					        -- read second CRC byte
                        return_state <= CMD_READ;                   -- then read next data block from SD card (on read_en)


                    -- INITIALIZATION PROCEDURE
                    when CMD0 =>                                -- send CMD0 to SD card
                        cmd_out <= x"FF400000000095";               
                        bit_counter <= "00110111";  -- 55 (command has 56 bits)
                        return_state <= CHECK_RESPONSE_CMD0;
                        state <= SEND_CMD;

                    when CHECK_RESPONSE_CMD0 =>                 -- check if the respone to CMD0 was OK
                        if(recv_data = "00000001") then
                            state <= CMD8;  -- everything OK, SD is in idle state
                        else
                            state <= CMD0;  -- error, repeat CMD0
                        end if;

                    when CMD8 =>                                -- send CMD8 to SD card
                        cmd_out <= x"FF48000001AA87";
                        bit_counter <= "00110111";  -- 55 (command has 56 bits)
                        return_state <= CMD55;
                        state <= SEND_CMD;

                    when CMD55 =>                               -- send CMD55 to SD card
                        cmd_out <= x"FF770000000001";
                        bit_counter <= "00110111";  -- 55 (command has 56 bits)
                        return_state <= CMD41;
                        state <= SEND_CMD;

                    when CMD41 =>                               -- send CMD41 to SD card
                        cmd_out <= x"FF694000000001";
                        bit_counter <= "00110111";  -- 55 (command has 56 bits)
                        return_state <= CHECK_RESPONSE_ACMD41;
                        state <= SEND_CMD;

                    when CHECK_RESPONSE_ACMD41 =>               -- check if the respone to CMD41 was OK
                        if(recv_data = "00000000") then
                            state <= CMD_READ;  -- everything OK, start reading
                            pause <= '0';
                        else
                            state <= CMD55;     -- error, repeat ACMD41 (ACMD41 = CMD55 + CMD41)
                        end if;
                        
                    when others =>
                        null;
                end case;

            end if;

        end if;
    end process;

end Behavioral;