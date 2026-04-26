# 🎯 VGA Object Tracker — FPGA Visual Tracking System


<p align="center">
  A fully synthesizable VHDL system that generates a VGA video signal, animates a white target square across the screen, and tracks it in real time with a green bounding box overlay — complete with colored decoy objects and LFSR-based pseudo-random motion.
</p>

---

## 📺 Demo Overview

The system renders a **640×480 @ 60 Hz** VGA output with the following live scene:

| Object | Color | Description |
|--------|-------|-------------|
| Target Square | ⬜ White | Bounces across screen; speed is switch-selectable (8 levels) |
| Tracker Box   | 🟩 Green border | 28×28 bounding box that snaps to the detected centroid each frame |
| Red Decoy     | 🟥 Red | LFSR-driven independently bouncing decoy square |
| Blue Decoy    | 🟦 Blue | LFSR-driven independently bouncing decoy square |
| Yellow Decoy  | 🟨 Yellow | LFSR-driven independently bouncing decoy square |

The **white pixel detector** scans every active pixel during each frame to build a bounding box around all white pixels, computes the centroid, and passes it to the tracker — which centers its overlay box over the target on the very next frame.

---

## 🗂️ Module Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Top Level                           │
│                                                             │
│  ┌──────────┐   frame_tick, pixel_x, pixel_y, active       │
│  │   vga    │ ──────────────────────────────────────────►  │
│  └──────────┘                                               │
│       │                                                     │
│       ├──► ┌───────────────────┐                            │
│       │    │ motion_controller │──► x_pos, y_pos            │
│       │    └───────────────────┘    (target square)         │
│       │              │                                      │
│       │              ▼                                      │
│       │    ┌───────────────────┐                            │
│       ├──► │  white_detector   │──► centroid_x, centroid_y  │
│       │    └───────────────────┘    detected                │
│       │              │                                      │
│       │              ▼                                      │
│       │    ┌───────────────────┐                            │
│       ├──► │tracker_controller │──► tracker_x, tracker_y   │
│       │    └───────────────────┘    tracker_act             │
│       │                                                     │
│       ├──► ┌───────────────────┐ ×3                         │
│       │    │ decoy_controller  │──► red/blue/yellow pos     │
│       │    └───────────────────┘                            │
│       │                                                     │
│       └──► ┌──────────┐                                     │
│            │ renderer │──► VGA R[3:0], G[3:0], B[3:0]      │
│            └──────────┘                                     │
└─────────────────────────────────────────────────────────────┘
```

---

## 📁 File Structure

```
vga-object-tracker/
├── rtl/
│   ├── vga.vhd                  # VGA sync signal generator
│   ├── motion_controller.vhd    # Target square motion with speed select
│   ├── decoy_controller.vhd     # Parameterizable bouncing decoy
│   ├── white_detector.vhd       # Bounding box & centroid detector
│   ├── tracker_controller.vhd   # Centroid-following tracker overlay
│   └── renderer.vhd             # Priority-encoded RGB pixel renderer
├── sim/
│   └── (testbenches)
├── constraints/
│   └── (board-specific .xdc / .ucf)
└── README.md
```

---

## 🔧 Module Descriptions

### `vga.vhd` — VGA Sync Generator

Generates standard **640×480 @ 60 Hz** timing with a 25.175 MHz pixel clock. Sync signals are negative polarity (active low), and all outputs are registered.

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk_i` | in | 1 | 25.175 MHz pixel clock |
| `rst_i` | in | 1 | Asynchronous reset (active high) |
| `hsync_o` | out | 1 | Horizontal sync (active low) |
| `vsync_o` | out | 1 | Vertical sync (active low) |
| `active_o` | out | 1 | High during active display region |
| `pixel_x_o` | out | 10 | Current horizontal counter [0–799] |
| `pixel_y_o` | out | 10 | Current vertical counter [0–524] |
| `frame_tick_o` | out | 1 | One-cycle pulse at the last pixel of each frame |

**Timing constants:**

| Parameter | Value |
|-----------|-------|
| H Active | 640 px |
| H Front Porch | 16 px |
| H Sync Pulse | 96 px |
| H Back Porch | 48 px |
| **H Total** | **800 clocks** |
| V Active | 480 lines |
| V Front Porch | 10 lines |
| V Sync Pulse | 2 lines |
| V Back Porch | 33 lines |
| **V Total** | **525 lines** |

---

### `motion_controller.vhd` — Target Motion Controller

Controls the white target square with 8-level **one-hot switch speed selection** and LFSR-based pseudo-random direction overrides.

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk_i` | in | 1 | Pixel clock |
| `rst_i` | in | 1 | Async reset |
| `frame_tick_i` | in | 1 | Frame pulse |
| `sw_i` | in | 8 | One-hot speed select |
| `x_pos_o` | out | 10 | Target X position |
| `y_pos_o` | out | 10 | Target Y position |

**Speed selection (one-hot encoded):**

| Switch Bit | Speed (px/frame) |
|------------|-----------------|
| `SW[7]` | 128 |
| `SW[6]` | 64 |
| `SW[5]` | 32 |
| `SW[4]` | 16 |
| `SW[3]` | 8 |
| `SW[2]` | 4 |
| `SW[1]` | 2 |
| `SW[0]` | 1 |
| *(none)* | 0 (frozen) |

- Object is 16×16 px; movement is bounded to X: [0, 624] and Y: [0, 464].
- A **16-bit Fibonacci LFSR** (taps: 16, 14, 13, 11; seed: `0xACDC`) triggers random direction flips approximately every 256 frames.

---

### `decoy_controller.vhd` — Parameterizable Decoy Controller

A generic bouncing object controller intended for multiple instantiation. Each instance is independently configured via generics.

| Generic | Type | Default | Description |
|---------|------|---------|-------------|
| `SPEED_MULT` | integer | 1 | Movement speed in px/frame |
| `START_X` | integer | 100 | Initial X position |
| `START_Y` | integer | 100 | Initial Y position |
| `LFSR_SEED` | std_logic_vector(15:0) | `0xBEEF` | LFSR initial value (unique per instance) |

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk_i` | in | 1 | Pixel clock |
| `rst_i` | in | 1 | Async reset |
| `frame_tick_i` | in | 1 | Frame pulse |
| `enable_i` | in | 1 | Enable movement |
| `x_pos_o` | out | 10 | Decoy X position |
| `y_pos_o` | out | 10 | Decoy Y position |

Each instance runs its own 16-bit Fibonacci LFSR with a different seed to ensure statistically independent random motion.

---

### `white_detector.vhd` — White Pixel Centroid Detector

Scans every active pixel per frame and maintains a **running bounding box** around all pixels with R=G=B=`1111`. At the `frame_tick` pulse, the centroid is computed and latched.

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk_i` | in | 1 | Pixel clock |
| `rst_i` | in | 1 | Async reset |
| `frame_tick_i` | in | 1 | Frame pulse (latch and reset trigger) |
| `pixel_x_i` | in | 10 | Current pixel X |
| `pixel_y_i` | in | 10 | Current pixel Y |
| `vga_r_i` | in | 4 | Pixel red channel |
| `vga_g_i` | in | 4 | Pixel green channel |
| `vga_b_i` | in | 4 | Pixel blue channel |
| `centroid_x_o` | out | 10 | Detected centroid X |
| `centroid_y_o` | out | 10 | Detected centroid Y |
| `detected_o` | out | 1 | High if any white pixel found this frame |

**Centroid computation:**
```
centroid_x = (x_min + x_max) / 2
centroid_y = (y_min + y_max) / 2
```

- Bounding box registers reset each frame (`x_min` ← all-1s, `x_max` ← all-0s).
- If no white pixel is detected, the previous centroid is preserved.
- Sum uses 11-bit intermediate registers to prevent overflow before halving.

---

### `tracker_controller.vhd` — Tracker Overlay Controller

Follows the white detector's centroid output, centering a **28×28 px tracker box** over the 16×16 target square each frame.

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk_i` | in | 1 | Pixel clock |
| `rst_i` | in | 1 | Async reset |
| `frame_tick_i` | in | 1 | Frame pulse |
| `enable_i` | in | 1 | Enable tracking |
| `centroid_x_i` | in | 10 | Centroid X from white_detector |
| `centroid_y_i` | in | 10 | Centroid Y from white_detector |
| `tracker_x_o` | out | 10 | Tracker box top-left X |
| `tracker_y_o` | out | 10 | Tracker box top-left Y |
| `tracker_act_o` | out | 1 | Tracker active flag (equals enable_i) |

**Centering offset:**
```
tracker_x = centroid_x - 14   (clamped to 0 to prevent underflow)
tracker_y = centroid_y - 14   (clamped to 0 to prevent underflow)
```
Offset = 14 px = 28 (tracker size) / 2, so the tracker box is always centered over the target.

Tracking is **direct snap** (no interpolation or smoothing) — the position updates instantaneously to the new centroid on every frame tick.

---

### `renderer.vhd` — Priority-Encoded RGB Pixel Renderer

Generates the 12-bit RGB output (4 bits per channel) for the VGA DAC based on all object positions. Uses combinational hit-tests followed by a **registered output stage** (1-clock pipeline).

**Render priority (highest → lowest):**

| Priority | Object | RGB Output |
|----------|--------|-----------|
| 1 | White target square | `F F F` |
| 2 | Green tracker border | `0 F 0` |
| 3 | Tracker label ("TRACKER") | `0 F 0` / `0 0 0` (bitmap) |
| 4 | Red decoy | `F 0 0` |
| 5 | Blue decoy | `0 0 F` |
| 6 | Yellow decoy | `F F 0` |
| 7 | Background / blanking | `0 0 0` |

The **"TRACKER" label** is rendered from a hardcoded `8×28` pixel bitmap stored as an array of `std_logic_vector`, positioned above the tracker box with a 2-pixel gap. The bitmap is indexed at runtime using the relative pixel coordinates within the label area.

---

## ⚙️ Design Notes

### Clock Domain
All modules share a single **25.175 MHz** pixel clock. The design is entirely single-clock-domain with no CDC crossings.

### Reset Strategy
All processes use **asynchronous reset** (active high `rst_i`). On deassertion, all counters and registers return to their defined initial values.

### Output Pipeline
All VGA outputs (sync signals, RGB data) are **registered**, introducing a uniform 1-clock pipeline delay. Combinational hit-test logic uses the current-cycle pixel coordinates, so no pipeline compensation is needed.

### LFSR Design
Both `motion_controller` and `decoy_controller` use a **16-bit Fibonacci LFSR** with polynomial taps at positions 16, 14, 13, 11.

> ⚠️ **Lock-up state warning:** An all-zero LFSR state is self-locking. The provided seeds (`0xACDC`, `0xBEEF`, etc.) avoid this. **Never initialize an LFSR to `0x0000`.**

---

## 🚀 Getting Started

### Requirements

- VHDL-2008 compatible synthesis tool (Vivado, Quartus Prime, etc.)
- FPGA board with:
  - VGA connector (12-bit resistor ladder or DAC: 4 bits per R/G/B channel)
  - 25.175 MHz pixel clock (or PLL/MMCM configured to generate it)
  - At least 8 slide switches for speed selection

### Synthesis Steps

1. Add all `.vhd` files from the `rtl/` directory to your project.
2. Create a top-level wrapper that instantiates all six modules and wires them together.
3. Apply your board's pin constraint file for VGA, clock, switches, and reset.
4. Synthesize → Implement → Generate Bitstream.
5. Program the FPGA and connect a VGA monitor.

### Clock Generation Example (Vivado)

If your board provides a 100 MHz system clock, configure an MMCM to generate the pixel clock:

```tcl
# Example Vivado Clocking Wizard settings
# Input:  100.000 MHz
# Output: 25.175 MHz  (or 25.000 MHz as a common approximation)
```

---

## 📐 VGA Resistor Ladder

If your board does not have a dedicated VGA DAC, use a simple R-2R resistor ladder per channel:

```
FPGA [3] (MSB) ──┤ 4K Ω  ├──┐
FPGA [2]       ──┤ 2K Ω  ├──┼──► VGA Channel (75 Ω to GND)
FPGA [1]       ──┤ 1K Ω  ├──┤
FPGA [0] (LSB) ──┤ 510 Ω ├──┘
```

Repeat for R, G, and B channels independently.

---

## 📊 Resource Utilization (Estimated)

| Resource | Estimated Count |
|----------|----------------|
| LUTs | 611 |
| Flip-Flops | 268 |
| Block RAM | 0 |
| DSP Slices | 0 |
| Global Clock Buffers | 1 |

*Actual utilization depends on the target device, tool version, and synthesis settings.*

---

## 🧪 Simulation Tips

Each module can be verified in isolation:

| Module | What to Test |
|--------|-------------|
| `vga` | `hsync`/`vsync` polarity and period; `active` window; counter wrap-around at H=800, V=525; `frame_tick` pulse width |
| `motion_controller` | Boundary bounce at X=0, X=624, Y=0, Y=464; speed changes via `sw_i`; LFSR direction override |
| `decoy_controller` | Independent motion with different generics; `enable_i` gating |
| `white_detector` | Inject synthetic white pixels at known coordinates; verify centroid output the following frame tick |
| `tracker_controller` | Step `centroid_x/y`; confirm snap tracking with 14 px offset; underflow clamp at boundary |
| `renderer` | Drive all hit-test conditions; verify priority ordering; check bitmap label pixels |


---

## 🙏 References

- VGA timing specification: [VESA_timing_parameters](https://glenwing.github.io/docs/VESA-GTF-1.1.pdf)
- Fibonacci LFSR theory: [Xilinx XAPP052](https://www.xilinx.com/support/documentation/application_notes/xapp052.pdf)
- https://github.com/Digilent/Basys3/blob/master/Projects/XADC_Demo/src/constraints/Basys3_Master.xdc
- https://digilent.com/reference/programmable-logic/basys-3/reference-manual
- Developed and tested on Xilinx Artix-7 (Basys3 board)

---

<p align="center">
  Built in VHDL &nbsp;·&nbsp; 640×480 @ 60 Hz &nbsp;·&nbsp; 25.175 MHz pixel clock
</p>