----------------------------------------------------------------------------------
-- Module Name  : tracker_controller
-- Description  : Follows the white object centroid with a bounding box overlay.
--                On each frame tick the tracker snaps directly to the target
--                position (centroid minus centering offset).
-- Clock        : 25.175 MHz pixel clock
-- Frame Tick   : One-cycle pulse per frame (from VGA controller)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ============================================================
-- Entity
-- ============================================================
entity tracker_controller is
    port (
        clk_i          : in  std_logic;                     -- 25.175 MHz pixel clock
        rst_i          : in  std_logic;                     -- Asynchronous reset, active high
        frame_tick_i   : in  std_logic;                     -- One-cycle pulse per frame
        enable_i       : in  std_logic;                     -- Enable tracker movement
        centroid_x_i   : in  std_logic_vector(9 downto 0); 	-- Target centroid X
        centroid_y_i   : in  std_logic_vector(9 downto 0); 	-- Target centroid Y
        tracker_x_o    : out std_logic_vector(9 downto 0); 	-- Tracker box top-left X
        tracker_y_o    : out std_logic_vector(9 downto 0); 	-- Tracker box top-left Y
        tracker_act_o  : out std_logic                      -- Tracker active flag
    );
end entity tracker_controller;

-- ============================================================
-- Architecture
-- ============================================================
architecture Behavioral of tracker_controller is

    -- Centering offset: shifts tracker so the box is centered over the target
    -- (tracker is 28x28, target square is 16x16 › offset = 28/2
    constant OFFSET : unsigned(9 downto 0) := to_unsigned(14, 10);

    -- ----------------------------------------------------------
    -- Internal signals
    -- ----------------------------------------------------------
    signal tx_reg   : unsigned(9 downto 0) := to_unsigned(306, 10);  -- Tracker X register
    signal ty_reg   : unsigned(9 downto 0) := to_unsigned(226, 10);  -- Tracker Y register
    signal target_x : unsigned(9 downto 0);                           -- Offset-adjusted target X
    signal target_y : unsigned(9 downto 0);                           -- Offset-adjusted target Y

begin

    -- ==========================================================
    -- Concurrent: Compute offset-adjusted target position
    -- Clamps to zero to avoid underflow
    -- ==========================================================
    target_x <= OFFSET when unsigned(centroid_x_i) < OFFSET
                else unsigned(centroid_x_i) - OFFSET;

    target_y <= OFFSET when unsigned(centroid_y_i) < OFFSET
                else unsigned(centroid_y_i) - OFFSET;

    -- ==========================================================
    -- Process: Tracker position update (direct snap to target)
    -- Async reset
    -- ==========================================================
    p_tracker : process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            tx_reg <= to_unsigned(306, 10);
            ty_reg <= to_unsigned(226, 10);

        elsif rising_edge(clk_i) then
            if frame_tick_i = '1' and enable_i = '1' then
                tx_reg <= target_x;
                ty_reg <= target_y;
            end if;
        end if;
    end process p_tracker;

    -- ==========================================================
    -- Output assignments
    -- ==========================================================
    tracker_x_o   <= std_logic_vector(tx_reg);
    tracker_y_o   <= std_logic_vector(ty_reg);
    tracker_act_o <= enable_i;

end architecture Behavioral;