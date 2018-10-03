library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lpf_iir is
				generic (
												AXIS_TDATA_WIDTH: natural := 32
								);
				port(
										aclk       : in std_logic;
										aresetn    : in std_logic;
										sig_i      : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
										x_value    : in std_logic_vector (AXIS_TDATA_WIDTH-1 downto 0); 
										data_o     : out std_logic_vector(AXIS_TDATA_WIDTH/2-1 downto 0)
						);
end lpf_iir;

architecture rtl of lpf_iir is

				-- format is A(0,31)
				constant one               : signed(AXIS_TDATA_WIDTH-1 downto 0) := "01111111111111111111111111111111";

				signal sig_reg, sig_next   : signed(AXIS_TDATA_WIDTH-1 downto 0);
				signal data_reg, data_next : signed(AXIS_TDATA_WIDTH-1 downto 0);

				signal b0_reg, b0_next                  : signed(AXIS_TDATA_WIDTH-1 downto 0);
				signal a1_reg, a1_next                  : signed(AXIS_TDATA_WIDTH-1 downto 0);

				signal x_reg, x_next       : std_logic_vector (AXIS_TDATA_WIDTH-1 downto 0); 
				signal r1_reg, r1_next       : signed(2*AXIS_TDATA_WIDTH-1 downto 0); 
				signal r11_reg, r11_next       : signed(2*AXIS_TDATA_WIDTH-1 downto 0); 
				signal r2_reg, r2_next       : signed(2*AXIS_TDATA_WIDTH-1 downto 0); 
				signal r22_reg, r22_next       : signed(2*AXIS_TDATA_WIDTH-1 downto 0); 
				signal r3_reg, r3_next       : signed(2*AXIS_TDATA_WIDTH-1 downto 0); 
				signal r4_reg, r4_next       : signed(AXIS_TDATA_WIDTH-1 downto 0); 
begin

				b0_next <= one - signed(x_value); 
				a1_next <= signed(x_value); 

				process(aclk)
				begin
								if rising_edge(aclk) then
												if(aresetn = '0') then
																a1_reg <= (others => '0');
																b0_reg <= (others => '0');
																sig_reg  <= signed(sig_i);
																r1_reg <= (others => '0');
																r2_reg <= (others => '0');
																r3_reg <= (others => '0');
																r4_reg <= signed(sig_i);
												else
																a1_reg  <= a1_next;
																b0_reg <= b0_next;
																sig_reg  <= sig_next;
																r1_reg <= r1_next;
																r11_reg <= r11_next;
																r2_reg <= r2_next;
																r22_reg <= r22_next;
																r3_reg <= r3_next;
																r4_reg <= r4_next;
												end if;
								end if;
				end process;

				--Next state logic
				sig_next <= signed(sig_i);

				r1_next <= b0_reg * sig_reg;
				r11_next <= r1_reg;
				r2_next <= a1_reg * r4_reg;
				r22_next <= r2_reg;
				r3_next <= r11_reg + r22_reg;
				r4_next <= r3_reg(2*AXIS_TDATA_WIDTH-1) & r3_reg((2*AXIS_TDATA_WIDTH)-3 downto AXIS_TDATA_WIDTH-1);

				data_o <= std_logic_vector(r4_reg(AXIS_TDATA_WIDTH-1 downto AXIS_TDATA_WIDTH/2));

end rtl;
