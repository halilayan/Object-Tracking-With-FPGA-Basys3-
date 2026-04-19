----------------------------------------------------------------------------------
-- Module Name  : vga
-- Description  : VGA sync signal generator for 640x480 @ 60Hz
--                Generates hsync, vsync, active area flag,
--                pixel coordinates, and a frame tick pulse.
-- Clock        : 25.175 MHz pixel clock required
-- Sync Polarity: Negative (active low)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;          -- Standard and recommended numeric library

-- ============================================================
-- Entity
-- ============================================================
entity vga is
    port (
        clk_i        : in  std_logic;                      -- 25.175 MHz pixel clock
        rst_i        : in  std_logic;                      -- Asynchronous reset, active high
        hsync_o      : out std_logic;                      -- Horizontal sync (active low)
        vsync_o      : out std_logic;                      -- Vertical sync   (active low)
        active_o     : out std_logic;                      -- High during active display area
        pixel_x_o    : out std_logic_vector(9 downto 0);   -- Current horizontal pixel index
        pixel_y_o    : out std_logic_vector(9 downto 0);   -- Current vertical pixel index
        frame_tick_o : out std_logic                       -- One-cycle pulse at end of each frame
    );
end entity vga;

-- ============================================================
-- Architecture
-- ============================================================
architecture Behavioral of vga is

    -- ----------------------------------------------------------
    -- VGA 640x480 @ 60 Hz timing constants
    -- Total horizontal period : 800 clocks
    -- Total vertical period   : 525 lines
    -- ----------------------------------------------------------
    constant H_ACTIVE  : integer := 640;   -- Active display width  (pixels)
    constant H_FP      : integer := 16;    -- Horizontal front porch
    constant H_SYNC    : integer := 96;    -- Horizontal sync pulse width
    constant H_BP      : integer := 48;    -- Horizontal back porch
    constant H_TOTAL   : integer := 800;   -- Total horizontal period (H_ACTIVE+H_FP+H_SYNC+H_BP)

    constant V_ACTIVE  : integer := 480;   -- Active display height (lines)
    constant V_FP      : integer := 10;    -- Vertical front porch
    constant V_SYNC    : integer := 2;     -- Vertical sync pulse width
    constant V_BP      : integer := 33;    -- Vertical back porch
    constant V_TOTAL   : integer := 525;   -- Total vertical period (V_ACTIVE+V_FP+V_SYNC+V_BP)

    -- ----------------------------------------------------------
    -- Internal signals
    -- ----------------------------------------------------------
    signal h_cnt       : unsigned(9 downto 0) := (others => '0');  -- Horizontal counter
    signal v_cnt       : unsigned(9 downto 0) := (others => '0');  -- Vertical counter
    signal frame_tick_r : std_logic := '0';                         -- Frame tick register

begin

    -- ==========================================================
    -- Process: Horizontal and vertical counter
    -- Async reset, synchronous count
    -- ==========================================================
    p_counters : process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            h_cnt        <= (others => '0');
            v_cnt        <= (others => '0');
            frame_tick_r <= '0';

        elsif rising_edge(clk_i) then

            -- Frame tick: one-cycle pulse at the last pixel of the frame
            if h_cnt = H_TOTAL - 1 and v_cnt = V_TOTAL - 1 then
                frame_tick_r <= '1';
            else
                frame_tick_r <= '0';
            end if;

            -- Horizontal counter
            if h_cnt = H_TOTAL - 1 then
                h_cnt <= (others => '0');

                -- Vertical counter increments at end of each line
                if v_cnt = V_TOTAL - 1 then
                    v_cnt <= (others => '0');
                else
                    v_cnt <= v_cnt + 1;
                end if;

            else
                h_cnt <= h_cnt + 1;
            end if;

        end if;
    end process p_counters;

    -- ==========================================================
    -- Process: Sync signal generation (registered outputs)
    -- Hsync active low during sync pulse window
    -- ==========================================================
    p_sync : process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            hsync_o <= '1';
            vsync_o <= '1';

        elsif rising_edge(clk_i) then

            -- Hsync: active low between (H_ACTIVE + H_FP) and (H_ACTIVE + H_FP + H_SYNC - 1)
            if h_cnt >= H_ACTIVE + H_FP and h_cnt < H_ACTIVE + H_FP + H_SYNC then
                hsync_o <= '0';
            else
                hsync_o <= '1';
            end if;

            -- Vsync: active low between (V_ACTIVE + V_FP) and (V_ACTIVE + V_FP + V_SYNC - 1)
            if v_cnt >= V_ACTIVE + V_FP and v_cnt < V_ACTIVE + V_FP + V_SYNC then
                vsync_o <= '0';
            else
                vsync_o <= '1';
            end if;

        end if;
    end process p_sync;

    -- ==========================================================
    -- Concurrent assignments
    -- ==========================================================

    -- Active area: high only when both counters are within display region
    active_o <= '1' when h_cnt < H_ACTIVE and v_cnt < V_ACTIVE else '0';

    -- Pixel coordinates exposed as std_logic_vector
    pixel_x_o    <= std_logic_vector(h_cnt);
    pixel_y_o    <= std_logic_vector(v_cnt);

    -- Frame tick output
    frame_tick_o <= frame_tick_r;

end architecture Behavioral;