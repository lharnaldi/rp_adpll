library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lia is
				generic(
											 ADC_DATA_WIDTH : natural := 14;
											 AXIS_TDATA_WIDTH: natural := 32
							 );
				port(
										aclk          : in std_logic;
										aresetn       : in std_logic;
										x_i           : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
										k_p           : in std_logic_vector (AXIS_TDATA_WIDTH-1 downto 0);
										k_i           : in std_logic_vector (AXIS_TDATA_WIDTH-1 downto 0); 
	--sig_i         : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0); 
	--I_o           : out std_logic_vector(AXIS_TDATA_WIDTH/2-1 downto 0);
	--Q_o           : out std_logic_vector(AXIS_TDATA_WIDTH/2-1 downto 0);
										IQ_o          : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
										locked_o      : out std_logic;

	-- Slave side
										s_axis_tready : out std_logic;
										s_axis_tvalid : in std_logic;
										s_axis_tdata  : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0)
						);
end lia;

architecture rtl of lia is

				signal zcd_s  : std_logic;
				signal freq_s : std_logic_vector(29 downto 0);
				signal sync_s : std_logic;

				signal sin_s, cos_s     : std_logic_vector(AXIS_TDATA_WIDTH/2-1 downto 0);
				signal mult1_s, mult2_s : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
				signal I_o, Q_o         : std_logic_vector(AXIS_TDATA_WIDTH/2-1 downto 0);
				signal s_tdata_reg, s_tdata_next : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
				signal s_tready : std_logic;

				--pipelining registers
				signal r1_reg, r1_next : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
				signal r2_reg, r2_next : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
				signal r3_reg, r3_next : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
				signal r4_reg, r4_next : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
				signal r5_reg, r5_next : std_logic_vector(AXIS_TDATA_WIDTH/2-1 downto 0);
				signal r6_reg, r6_next : std_logic_vector(AXIS_TDATA_WIDTH/2-1 downto 0);

begin
				s_tready <= '1'; --always ready to receive data
				--slave side
				s_axis_tready <= s_tready;

				process(aclk)
				begin
								if rising_edge(aclk) then
												if (aresetn = '0') then
																s_tdata_reg <= (others => '0');
												else
																s_tdata_reg <= s_tdata_next;
												end if;
								end if;
				end process;
				--next state logic
				--s_tdata_next <= s_axis_tdata when ((s_axis_tvalid = '1') and (s_axis_tready	= '1')) else s_tdata_reg;
				s_tdata_next <= s_axis_tdata(AXIS_TDATA_WIDTH-3 downto AXIS_TDATA_WIDTH/2) & "00" &
												s_axis_tdata(AXIS_TDATA_WIDTH/2-3 downto 0) & "00" when ((s_axis_tvalid = '1') and (s_tready	= '1')) else s_tdata_reg;


				ZCD: entity work.zero_cross_det
	--generic map( ADC_DATA_WIDTH => ADC_DATA_WIDTH )
				port map(
												aclk   => aclk,
												aresetn => aresetn,
		--sig_i => sig_i(AXIS_TDATA_WIDTH-1 downto AXIS_TDATA_WIDTH/2), --ch2
												sig_i => s_tdata_reg(AXIS_TDATA_WIDTH-1 downto AXIS_TDATA_WIDTH/2), --ch2
												det_o => zcd_s
								);

				ADPLL: entity work.adpll
				generic map( ADC_DATA_WIDTH => ADC_DATA_WIDTH,
										 AXIS_TDATA_WIDTH => AXIS_TDATA_WIDTH
						 )
				port map(
												aclk      => aclk,
												aresetn    => aresetn,
												ref_i      => zcd_s,
												k_p        => k_p,
												k_i        => k_i,
												locked_o   => locked_o,
												sin_o      => sin_s,
												cos_o      => cos_s
								);

				PIP1:process(aclk)
				begin
								if rising_edge(aclk) then
												if (aresetn = '0') then
																r1_reg <= (others => '0');
																r2_reg <= (others => '0');
												else
																r1_reg <= r1_next;
																r2_reg <= r2_next;
												end if;
								end if;
				end process;

				--next state logic
				r1_next <= s_tdata_reg; --ch1
				r2_next <= cos_s & sin_s;

				SM1: entity work.signed_mult
				generic map(
													 AXIS_TDATA_WIDTH => AXIS_TDATA_WIDTH
									 )
				port map(
												aclk => aclk,
												--a_i   => sin_s,
												a_i   => r2_reg(AXIS_TDATA_WIDTH/2-1 downto 0), --sin_s
												--b_i   => s_tdata_reg(AXIS_TDATA_WIDTH/2-1 downto 0), --ch1
												b_i   => r1_reg(AXIS_TDATA_WIDTH/2-1 downto 0), --ch1
												mult_o => mult1_s
								);

				SM2: entity work.signed_mult
				generic map(
													 AXIS_TDATA_WIDTH => AXIS_TDATA_WIDTH
									 )
				port map(
												aclk => aclk,
												--a_i   => cos_s,
												a_i   => r2_reg(AXIS_TDATA_WIDTH-1 downto AXIS_TDATA_WIDTH/2), --cos_s
												--b_i   => s_tdata_reg(AXIS_TDATA_WIDTH/2-1 downto 0), --ch1
												b_i   => r1_reg(AXIS_TDATA_WIDTH/2-1 downto 0), --ch1
												mult_o => mult2_s
								);

				PIP2:process(aclk)
				begin
								if rising_edge(aclk) then
												if (aresetn = '0') then
																r3_reg <= (others => '0');
																r4_reg <= (others => '0');
												else
																r3_reg <= r3_next;
																r4_reg <= r4_next;
												end if;
								end if;
				end process;

				--next state logic
				r3_next <= mult1_s;
				r4_next <= mult2_s;

				LPF1: entity work.lpf_iir
				port map(
												aclk     => aclk,
												aresetn  => aresetn, 
												--sig_i    => mult1_s,
												sig_i    => r3_reg,
												x_value  => x_i,
												data_o   => I_o
								);

				LPF2: entity work.lpf_iir
				port map(
												aclk     => aclk,
												aresetn  => aresetn, 
												--sig_i    => mult2_s,
												sig_i    => r4_reg,
												x_value  => x_i,
												data_o   => Q_o
								);

				PIP3:process(aclk)
				begin
								if rising_edge(aclk) then
												if (aresetn = '0') then
																r5_reg <= (others => '0');
																r6_reg <= (others => '0');
												else
																r5_reg <= r5_next;
																r6_reg <= r6_next;
												end if;
								end if;
				end process;

				--next state logic
				r5_next <= Q_o;
				r6_next <= I_o;

				--IQ_o <= Q_o & I_o;
				IQ_o <= r5_reg & r6_reg;
end rtl;
