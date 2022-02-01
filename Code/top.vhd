library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity top is
    Port ( clk_in   : in STD_LOGIC;         -- Clock and reset
           reset_in : in STD_LOGIC;
           
           sd_audio_out  : out STD_LOGIC;   -- Audio signals
           pwm_audio_out : out STD_LOGIC;
           
           BTNC : in STD_LOGIC;
           BTNL : in STD_LOGIC;
           BTNR : in STD_LOGIC;
           
           SD_CD    : in STD_LOGIC;         -- SD signals
           SD_DAT_0 : in STD_LOGIC;
           SD_DAT_1 : out STD_LOGIC;
           SD_DAT_2 : out STD_LOGIC;
           SD_DAT_3 : out STD_LOGIC;
           SD_RESET : out STD_LOGIC;
           SD_SCK   : out STD_LOGIC;
           SD_CMD   : out STD_LOGIC);
end entity;

architecture Behavioral of top is

    signal en_25MHz_sig : STD_LOGIC;
    signal en_44kHz_sig : STD_LOGIC;
    signal en_800kHz_sig : STD_LOGIC;
    signal reset_sig : STD_LOGIC;
    signal read_en_sig  : STD_LOGIC;
    signal byte_ready_sig : STD_LOGIC;
    signal RAM_data_in_sig : STD_LOGIC_VECTOR (7 downto 0);
    signal RAM_data_out_sig : STD_LOGIC_VECTOR (7 downto 0); 

    component prescaler is 
        Port ( sys_clk  : in STD_LOGIC;       -- 100MHz
               reset    : in STD_LOGIC;
               en_25MHz : out STD_LOGIC;
               en_44kHz : out STD_LOGIC;
               en_800kHz : out STD_LOGIC);
	end component;
	
	component SD_read is 
        Port ( sys_clk   : in STD_LOGIC;
               reset     : in STD_LOGIC;
               en_25MHz  : in STD_LOGIC;
               en_800kHz : in STD_LOGIC;
               read_en   : in STD_LOGIC;
           
               miso : in STD_LOGIC;         -- SD signals
               mosi : out STD_LOGIC;
               cs   : out STD_LOGIC;
               sclk : out STD_LOGIC;
           
               byte_ready : out STD_LOGIC;
               PCM_data   : out STD_LOGIC_VECTOR (7 downto 0);
               sd_audio   : out std_logic;
               
               BTNC : in STD_LOGIC;
               BTNL : in STD_LOGIC;
               BTNR : in STD_LOGIC);
	end component;
	
	component RAM_controller is 
        Port ( sys_clk    : in std_logic;
               reset      : in std_logic;
               en_44kHz   : in  std_logic;
               byte_ready : in  std_logic;
               dataIn     : in  std_logic_vector (7 downto 0);
               dataOut    : out std_logic_vector (7 downto 0);
               read_en    : out std_logic);
	end component;
	
	component PCM_to_audio is 
        Port ( sys_clk   : in STD_LOGIC;
               reset     : in STD_LOGIC;
               PCM_data  : in STD_LOGIC_VECTOR (7 downto 0);  -- should change with frequency: 44 100Hz
               pwm_audio : out STD_LOGIC);
	end component;
	


begin

    -- for SPI mode
    SD_DAT_1 <= '1';
    SD_DAT_2 <= '1';
    SD_RESET <= '0';
    
    reset_sig <= reset_in or SD_CD;
    
    prs : prescaler
    port map (
			sys_clk => clk_in,
			reset => reset_sig,
			en_25MHz => en_25MHz_sig,
			en_44kHz => en_44kHz_sig,
			en_800kHz => en_800kHz_sig
		);

    sd : SD_read
    port map (
			sys_clk => clk_in,
			reset => reset_sig,
			en_25MHz => en_25MHz_sig,
			en_800kHz => en_800kHz_sig,
			read_en => read_en_sig,
			
			miso => SD_DAT_0,
            mosi => SD_CMD,
            cs   => SD_DAT_3,
            sclk => SD_SCK,
			
			byte_ready => byte_ready_sig,
			PCM_data => RAM_data_in_sig,
            sd_audio => sd_audio_out,
            
            BTNC => BTNC,
            BTNL => BTNL,
            BTNR => BTNR
		);
	
	ram : RAM_controller
    port map (
			sys_clk => clk_in,
			reset => reset_sig,
			en_44kHz => en_44kHz_sig,
			byte_ready => byte_ready_sig,
			dataIn => RAM_data_in_sig,
			dataOut => RAM_data_out_sig,
			read_en => read_en_sig
		);
		
	aud : PCM_to_audio
    port map (
			sys_clk => clk_in,
			reset => reset_sig,
			PCM_data => RAM_data_out_sig,
			pwm_audio => pwm_audio_out
		);
		

end Behavioral;
