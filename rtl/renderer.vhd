----------------------------------------------------------------------------------
-- Module Name  : renderer
-- Description  : Pixel renderer for VGA output. Draws white square (target),
--                green tracker border with label, and colored decoy squares.
--                Priority: white > tracker border > tracker label > decoys > black
-- Clock        : 25.175 MHz pixel clock
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ============================================================
-- Entity
-- ============================================================
entity renderer is
    port (
        clk_i          : in  std_logic;                     -- 25.175 MHz pixel clock
        rst_i          : in  std_logic;                     -- Asynchronous reset, active high
        -- White target square
        x_pos_i        : in  std_logic_vector(9 downto 0);
        y_pos_i        : in  std_logic_vector(9 downto 0);
        -- Tracker box
        tracker_x_i    : in  std_logic_vector(9 downto 0);
        tracker_y_i    : in  std_logic_vector(9 downto 0);
        tracker_act_i  : in  std_logic;
        -- Red decoy
        red_x_i        : in  std_logic_vector(9 downto 0);
        red_y_i        : in  std_logic_vector(9 downto 0);
        red_en_i       : in  std_logic;
        -- Blue decoy
        blue_x_i       : in  std_logic_vector(9 downto 0);
        blue_y_i       : in  std_logic_vector(9 downto 0);
        blue_en_i      : in  std_logic;
        -- Yellow decoy
        yellow_x_i     : in  std_logic_vector(9 downto 0);
        yellow_y_i     : in  std_logic_vector(9 downto 0);
        yellow_en_i    : in  std_logic;
        -- VGA interface
        pixel_x_i      : in  std_logic_vector(9 downto 0);
        pixel_y_i      : in  std_logic_vector(9 downto 0);
        active_i       : in  std_logic;
		-- VGA connector
        vga_r_o        : out std_logic_vector(3 downto 0);
        vga_g_o        : out std_logic_vector(3 downto 0);
        vga_b_o        : out std_logic_vector(3 downto 0)
    );
end entity renderer;

-- ============================================================
-- Architecture
-- ============================================================
architecture Behavioral of renderer is

    -- ----------------------------------------------------------
    -- Object dimension constants
    -- ----------------------------------------------------------
    constant SQUARE_W  : integer := 16;
    constant SQUARE_H  : integer := 16;
    constant TRACKER_W : integer := 28;
    constant TRACKER_H : integer := 28;
    constant BORDER    : integer := 2;

    -- ----------------------------------------------------------
    -- Tracker label bitmap constants (28x8 pixels)
    -- ----------------------------------------------------------
    constant TEXT_W   : integer := 28;
    constant TEXT_H   : integer := 8;
    constant TEXT_GAP : integer := 2;   -- Gap between tracker box top and label

    type text_bitmap_t is array(0 to 7) of std_logic_vector(27 downto 0); -- "TRACKER"
    constant TRACKER_TEXT : text_bitmap_t := (
        "1111111001100111100111111110",
        "0110100110011000101010001001",
        "0110100110011000110010001001",
        "0110111011111000110011101110",
        "0110110010011000101010001100",
        "0110101010011000100110001010",
        "0110100110010111100111111001",
        "0000000000000000000000000000"
    );

    -- ----------------------------------------------------------
    -- Pixel coordinate as integer (combinational conversion)
    -- ----------------------------------------------------------
    signal px         : integer range 0 to 799;
    signal py         : integer range 0 to 524;
    signal tx         : integer range 0 to 639;
    signal ty         : integer range 0 to 479;
    signal text_y_top : integer range 0 to 479;   -- Top row of the label

    -- ----------------------------------------------------------
    -- Hit-test flags (combinational)
    -- ----------------------------------------------------------
    signal in_square         : std_logic;
    signal in_tracker_area   : std_logic;
    signal in_tracker_inner  : std_logic;
    signal in_tracker_border : std_logic;
    signal in_text_area      : std_logic;
    signal in_red            : std_logic;
    signal in_blue           : std_logic;
    signal in_yellow         : std_logic;

begin

    -- ==========================================================
    -- Coordinate conversion (std_logic_vector → integer)
    -- ==========================================================
    px <= to_integer(unsigned(pixel_x_i));
    py <= to_integer(unsigned(pixel_y_i));
    tx <= to_integer(unsigned(tracker_x_i));
    ty <= to_integer(unsigned(tracker_y_i));

    text_y_top <= ty - TEXT_H - TEXT_GAP when ty >= (TEXT_H + TEXT_GAP) else 0;

    -- ==========================================================
    -- Hit-test: white target square
    -- ==========================================================
    in_square <= '1' when (
        px >= to_integer(unsigned(x_pos_i)) and
        px <  to_integer(unsigned(x_pos_i)) + SQUARE_W and
        py >= to_integer(unsigned(y_pos_i)) and
        py <  to_integer(unsigned(y_pos_i)) + SQUARE_H
    ) else '0';

    -- ==========================================================
    -- Hit-test: tracker outer box
    -- ==========================================================
    in_tracker_area <= '1' when (
        px >= tx and px < tx + TRACKER_W and
        py >= ty and py < ty + TRACKER_H
    ) else '0';

    -- ==========================================================
    -- Hit-test: tracker inner area (for border subtraction)
    -- ==========================================================
    in_tracker_inner <= '1' when (
        px >= tx + BORDER and px < tx + TRACKER_W - BORDER and
        py >= ty + BORDER and py < ty + TRACKER_H - BORDER
    ) else '0';

    -- Border = outer area minus inner area
    in_tracker_border <= in_tracker_area and (not in_tracker_inner);

    -- ==========================================================
    -- Hit-test: tracker label (above the tracker box)
    -- ==========================================================
    in_text_area <= '1' when (
        tracker_act_i = '1'          and
        ty >= (TEXT_H + TEXT_GAP)    and
        px >= tx and px < tx + TEXT_W and
        py >= text_y_top and py < text_y_top + TEXT_H
    ) else '0';

    -- ==========================================================
    -- Hit-test: colored decoys
    -- ==========================================================
    in_red <= '1' when (
        red_en_i = '1' and
        px >= to_integer(unsigned(red_x_i)) and
        px <  to_integer(unsigned(red_x_i)) + SQUARE_W and
        py >= to_integer(unsigned(red_y_i)) and
        py <  to_integer(unsigned(red_y_i)) + SQUARE_H
    ) else '0';

    in_blue <= '1' when (
        blue_en_i = '1' and
        px >= to_integer(unsigned(blue_x_i)) and
        px <  to_integer(unsigned(blue_x_i)) + SQUARE_W and
        py >= to_integer(unsigned(blue_y_i)) and
        py <  to_integer(unsigned(blue_y_i)) + SQUARE_H
    ) else '0';

    in_yellow <= '1' when (
        yellow_en_i = '1' and
        px >= to_integer(unsigned(yellow_x_i)) and
        px <  to_integer(unsigned(yellow_x_i)) + SQUARE_W and
        py >= to_integer(unsigned(yellow_y_i)) and
        py <  to_integer(unsigned(yellow_y_i)) + SQUARE_H
    ) else '0';

    -- ==========================================================
    -- Process: RGB output (registered, priority-encoded)
    -- Async reset
    -- ==========================================================
    p_rgb : process(clk_i, rst_i)
        variable rel_x      : integer range 0 to 27;
        variable rel_y      : integer range 0 to 7;
        variable text_pixel : std_logic;
    begin
        if rst_i = '1' then
            vga_r_o <= (others => '0');
            vga_g_o <= (others => '0');
            vga_b_o <= (others => '0');

        elsif rising_edge(clk_i) then

            if active_i = '1' then

                if in_square = '1' then
                    -- White target (highest priority)
                    vga_r_o <= "1111";
                    vga_g_o <= "1111";
                    vga_b_o <= "1111";

                elsif in_tracker_border = '1' and tracker_act_i = '1' then
                    -- Green tracker border
                    vga_r_o <= "0000";
                    vga_g_o <= "1111";
                    vga_b_o <= "0000";

                elsif in_text_area = '1' then
                    -- Tracker label bitmap
                    rel_x      := px - tx;
                    rel_y      := py - text_y_top;
                    text_pixel := TRACKER_TEXT(rel_y)(27 - rel_x);
                    if text_pixel = '1' then
                        vga_r_o <= "0000";
                        vga_g_o <= "1111";
                        vga_b_o <= "0000";
                    else
                        vga_r_o <= "0000";
                        vga_g_o <= "0000";
                        vga_b_o <= "0000";
                    end if;

                elsif in_red = '1' then
                    vga_r_o <= "1111";
                    vga_g_o <= "0000";
                    vga_b_o <= "0000";

                elsif in_blue = '1' then
                    vga_r_o <= "0000";
                    vga_g_o <= "0000";
                    vga_b_o <= "1111";

                elsif in_yellow = '1' then
                    vga_r_o <= "1111";
                    vga_g_o <= "1111";
                    vga_b_o <= "0000";

                else
                    -- Black background
                    vga_r_o <= "0000";
                    vga_g_o <= "0000";
                    vga_b_o <= "0000";
                end if;

            else
                -- Blanking region
                vga_r_o <= "0000";
                vga_g_o <= "0000";
                vga_b_o <= "0000";
            end if;
        end if;
    end process p_rgb;

end architecture Behavioral;