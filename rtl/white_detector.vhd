----------------------------------------------------------------------------------
-- Module Name  : white_detector
-- Description  : Scans each pixel and builds a bounding box around white pixels
--                (R=G=B=1111) within each frame. At frame end (frame_tick),
--                the centroid is computed as the bounding box midpoint and latched.
-- Clock        : 25.175 MHz pixel clock
-- Frame Tick   : One-cycle pulse per frame (from VGA controller)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ============================================================
-- Entity
-- ============================================================
entity white_detector is
    port (
        clk_i      		: in  std_logic;                     	-- 25.175 MHz pixel clock
        rst_i      		: in  std_logic;                     	-- Asynchronous reset, active high
        frame_tick_i 	: in  std_logic;                   		-- One-cycle pulse per frame
        pixel_x_i  		: in  std_logic_vector(9 downto 0); 	-- Current pixel X
        pixel_y_i  		: in  std_logic_vector(9 downto 0); 	-- Current pixel Y
        vga_r_i    		: in  std_logic_vector(3 downto 0); 	-- Pixel red channel
        vga_g_i    		: in  std_logic_vector(3 downto 0); 	-- Pixel green channel
        vga_b_i    		: in  std_logic_vector(3 downto 0); 	-- Pixel blue channel
        centroid_x_o 	: out std_logic_vector(9 downto 0); 	-- Detected centroid X
        centroid_y_o 	: out std_logic_vector(9 downto 0); 	-- Detected centroid Y
        detected_o 		: out std_logic                      	-- High if white pixel found this frame
    );
end entity white_detector;

-- ============================================================
-- Architecture
-- ============================================================
architecture Behavioral of white_detector is

    -- ----------------------------------------------------------
    -- Bounding box registers
    -- x_min/y_min init to max value, x_max/y_max init to zero
    -- ----------------------------------------------------------
    signal x_min : unsigned(9 downto 0) := (others => '1');
    signal x_max : unsigned(9 downto 0) := (others => '0');
    signal y_min : unsigned(9 downto 0) := (others => '1');
    signal y_max : unsigned(9 downto 0) := (others => '0');

    -- Centroid output registers (initialized to screen center)
    signal cx_reg : unsigned(9 downto 0) := to_unsigned(320, 10);
    signal cy_reg : unsigned(9 downto 0) := to_unsigned(240, 10);

    -- White pixel detection flag for current frame
    signal white_found : std_logic := '0';

    -- Combinational white pixel flag (R=G=B=1111)
    signal is_white : std_logic;

    -- Bounding box midpoint (11-bit to hold sum before halving)
    signal sum_x : unsigned(10 downto 0);
    signal sum_y : unsigned(10 downto 0);

begin

    -- ==========================================================
    -- Concurrent: White pixel test
    -- ==========================================================
    is_white <= '1' when (
        vga_r_i = "1111" and
        vga_g_i = "1111" and
        vga_b_i = "1111"
    ) else '0';

    -- ==========================================================
    -- Concurrent: Centroid = (min + max) / 2
    -- ==========================================================
    sum_x <= ('0' & x_min) + ('0' & x_max);
    sum_y <= ('0' & y_min) + ('0' & y_max);

    -- ==========================================================
    -- Process: Bounding box update and centroid latch
    -- Async reset
    -- ==========================================================
    p_detect : process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            x_min       <= (others => '1');
            x_max       <= (others => '0');
            y_min       <= (others => '1');
            y_max       <= (others => '0');
            cx_reg      <= to_unsigned(320, 10);
            cy_reg      <= to_unsigned(240, 10);
            white_found <= '0';

        elsif rising_edge(clk_i) then

            if frame_tick_i = '1' then
                -- End of frame: latch centroid if white was detected, then reset bbox
                if white_found = '1' then
                    cx_reg <= sum_x(10 downto 1);   -- (x_min + x_max) / 2
                    cy_reg <= sum_y(10 downto 1);   -- (y_min + y_max) / 2
                end if;

                x_min       <= (others => '1');
                x_max       <= (others => '0');
                y_min       <= (others => '1');
                y_max       <= (others => '0');
                white_found <= '0';

            else
                -- Per-pixel: update bounding box on white pixel hit
                if is_white = '1' then
                    white_found <= '1';

                    if unsigned(pixel_x_i) < x_min then
                        x_min <= unsigned(pixel_x_i);
                    end if;

                    if unsigned(pixel_x_i) > x_max then
                        x_max <= unsigned(pixel_x_i);
                    end if;

                    if unsigned(pixel_y_i) < y_min then
                        y_min <= unsigned(pixel_y_i);
                    end if;

                    if unsigned(pixel_y_i) > y_max then
                        y_max <= unsigned(pixel_y_i);
                    end if;
                end if;

            end if;
        end if;
    end process p_detect;

    -- ==========================================================
    -- Output assignments
    -- ==========================================================
    centroid_x_o <= std_logic_vector(cx_reg);
    centroid_y_o <= std_logic_vector(cy_reg);
    detected_o   <= white_found;

end architecture Behavioral;