----------------------------------------------------------------------------------
-- Module Name  : motion_controller
-- Description  : Bouncing square controller with switch-selectable speed.
--                Speed is set via one-hot encoded 8-bit switch input.
--                Includes LFSR-based random direction changes (~every 256 frames).
-- Clock        : 25.175 MHz pixel clock
-- Frame Tick   : One-cycle pulse per frame (from VGA controller)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ============================================================
-- Entity
-- ============================================================
entity motion_controller is
    port (
        clk_i        : in  std_logic;                     -- 25.175 MHz pixel clock
        rst_i        : in  std_logic;                     -- Asynchronous reset, active high
        frame_tick_i : in  std_logic;                     -- One-cycle pulse per frame
        sw_i         : in  std_logic_vector(7 downto 0);  -- One-hot speed select switches
        x_pos_o      : out std_logic_vector(9 downto 0);  -- Current X position
        y_pos_o      : out std_logic_vector(9 downto 0)   -- Current Y position
    );
end entity motion_controller;

-- ============================================================
-- Architecture
-- ============================================================
architecture Behavioral of motion_controller is

    -- ----------------------------------------------------------
    -- Boundary constants (object is 16x16, so max = 640/480 - 16)
    -- ----------------------------------------------------------
    constant X_MAX : unsigned(9 downto 0) := to_unsigned(624, 10);
    constant Y_MAX : unsigned(9 downto 0) := to_unsigned(464, 10);

    -- ----------------------------------------------------------
    -- Internal signals
    -- ----------------------------------------------------------
    signal x_reg  : unsigned(9 downto 0) := to_unsigned(312, 10);  -- X position register (center)
    signal y_reg  : unsigned(9 downto 0) := to_unsigned(232, 10);  -- Y position register (center)
    signal dx_dir : std_logic := '0';                               -- X direction: 0=right, 1=left
    signal dy_dir : std_logic := '1';                               -- Y direction: 0=down,  1=up
    signal lfsr   : std_logic_vector(15 downto 0) := x"ACDC";      -- 16-bit Fibonacci LFSR
    signal speed  : unsigned(9 downto 0);                           -- Active speed value

begin

    -- ==========================================================
    -- Concurrent: One-hot switch to speed decoder
    -- SW(7) = fastest (128), SW(0) = slowest (1)
    -- ==========================================================
    speed <= to_unsigned(128, 10) when sw_i(7) = '1' else
             to_unsigned(64,  10) when sw_i(6) = '1' else
             to_unsigned(32,  10) when sw_i(5) = '1' else
             to_unsigned(16,  10) when sw_i(4) = '1' else
             to_unsigned(8,   10) when sw_i(3) = '1' else
             to_unsigned(4,   10) when sw_i(2) = '1' else
             to_unsigned(2,   10) when sw_i(1) = '1' else
             to_unsigned(1,   10) when sw_i(0) = '1' else
             to_unsigned(0,   10);

    -- ==========================================================
    -- Process: Position update and LFSR
    -- Async reset, updates on frame_tick only
    -- ==========================================================
    p_movement : process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            x_reg  <= to_unsigned(312, 10);
            y_reg  <= to_unsigned(232, 10);
            dx_dir <= '0';
            dy_dir <= '1';
            lfsr   <= x"ACDC";

        elsif rising_edge(clk_i) then

            if frame_tick_i = '1' then

                -- ------------------------------------------------
                -- LFSR update (16-bit Fibonacci, taps: 16,14,13,11)
                -- ------------------------------------------------
                lfsr <= lfsr(14 downto 0) &
                        (lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10));

                if speed /= 0 then

                    -- ----------------------------------------
                    -- X-axis movement
                    -- ----------------------------------------
                    if dx_dir = '0' then                      -- Moving right
                        if (x_reg + speed) >= X_MAX then
                            x_reg  <= X_MAX;
                            dx_dir <= '1';
                        else
                            x_reg <= x_reg + speed;
                        end if;
                    else                                       -- Moving left
                        if x_reg <= speed then
                            x_reg  <= (others => '0');
                            dx_dir <= '0';
                        else
                            x_reg <= x_reg - speed;
                        end if;
                    end if;

                    -- ----------------------------------------
                    -- Y-axis movement
                    -- ----------------------------------------
                    if dy_dir = '0' then                      -- Moving down
                        if (y_reg + speed) >= Y_MAX then
                            y_reg  <= Y_MAX;
                            dy_dir <= '1';
                        else
                            y_reg <= y_reg + speed;
                        end if;
                    else                                       -- Moving up
                        if y_reg <= speed then
                            y_reg  <= (others => '0');
                            dy_dir <= '0';
                        else
                            y_reg <= y_reg - speed;
                        end if;
                    end if;

                    -- ----------------------------------------
                    -- Random direction override from LFSR
                    -- Triggers approximately every 256 frames
                    -- ----------------------------------------
                    if lfsr(7 downto 0) = x"FF" then
                        dx_dir <= lfsr(8);
                    end if;

                    if lfsr(15 downto 8) = x"FF" then
                        dy_dir <= lfsr(0);
                    end if;

                end if;
            end if;
        end if;
    end process p_movement;

    -- ==========================================================
    -- Output assignments
    -- ==========================================================
    x_pos_o <= std_logic_vector(x_reg);
    y_pos_o <= std_logic_vector(y_reg);

end architecture Behavioral;