// DE1-SoC board wrapper for the FPGA mixed-signal oscilloscope.
//
// Plumbing only: connects the real board pins to scope_core and to the
// board version of the course VGA adapter. All project logic lives in
// rtl/top/scope_core.v (same core as the DESim wrapper in desim/top.v).
//
// Port names must match the pin assignments in scope_top.qsf
// (copied from the course DE1_SoC.qsf).
//
// Adapter instance follows the ECE241 VGA Adapter examples (FPGAcademy).

`default_nettype none

module scope_top (CLOCK_50, SW, KEY, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, LEDR, GPIO_0,
                  VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK, ADC_CS_N, ADC_SCLK, ADC_DIN, ADC_DOUT);

    input  wire        CLOCK_50;   // 50 MHz clock
    input  wire [9:0]  SW;         // switches
    input  wire [3:0]  KEY;        // pushbuttons (active-low)
    output wire [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    output wire [9:0]  LEDR;
    inout  wire [35:0] GPIO_0;     // 40-pin header JP1 (36 I/O pins)

    output wire [7:0]  VGA_R;      // to the board's video DAC
    output wire [7:0]  VGA_G;
    output wire [7:0]  VGA_B;
    output wire        VGA_HS;     // horizontal sync
    output wire        VGA_VS;     // vertical sync
    output wire        VGA_BLANK_N;
    output wire        VGA_SYNC_N;
    output wire        VGA_CLK;

    output wire ADC_CS_N;
    output wire ADC_SCLK;
    output wire ADC_DIN;
    input wire ADC_DOUT;

    parameter RESOLUTION  = "320x240";
    parameter COLOR_DEPTH = 9;

    // Signals between the core and the adapter (320x240: x is 9 bits, y is 8 bits)
    wire [8:0] core_x;
    wire [7:0] core_y;
    wire [8:0] core_colour;
    wire       core_write;
    wire       test_wave;

    // Board timing uses scope_core's defaults; only the font path changes
    // (Quartus runs from board/, so the path is relative to that folder)
    scope_core #(.FONT_FILE("../rtl/digital/font8x8.hex")) CORE (
        .clk     (CLOCK_50),
        .resetn  (KEY[0]),
        .SW      (SW),
        .KEY     (KEY),
        .gpio_in (GPIO_0[3:0]),    // digital channels CH0-CH3
        .LEDR    (LEDR),
        .HEX0    (HEX0), .HEX1(HEX1), .HEX2(HEX2),
        .HEX3    (HEX3), .HEX4(HEX4), .HEX5(HEX5),
        .x       (core_x),
        .y       (core_y),
        .colour  (core_colour),
        .write   (core_write),
        .test_wave (test_wave),
        .adc_cs_n (ADC_CS_N),
        .adc_sclk (ADC_SCLK),
        .adc_saddr (ADC_DIN),
        .adc_sdat (ADC_DOUT)
    );

    // Board adapter: framebuffer (dual-port RAM) + VGA controller + 25 MHz PLL.
    vga_adapter VGA (
        .resetn      (KEY[0]),
        .clock       (CLOCK_50),
        .color       (core_colour),
        .x           (core_x),
        .y           (core_y),
        .write       (core_write),
        .VGA_R       (VGA_R),
        .VGA_G       (VGA_G),
        .VGA_B       (VGA_B),
        .VGA_HS      (VGA_HS),
        .VGA_VS      (VGA_VS),
        .VGA_BLANK_N (VGA_BLANK_N),
        .VGA_SYNC_N  (VGA_SYNC_N),
        .VGA_CLK     (VGA_CLK)
    );
        defparam VGA.RESOLUTION       = RESOLUTION;
        defparam VGA.COLOR_DEPTH      = COLOR_DEPTH;
        // starting screen: all black, sized for 320x240 x 9-bit (76,800 words)
        defparam VGA.BACKGROUND_IMAGE = "black_320_9.mif";

    // GPIO_0[3:0] = CH0-CH3 inputs (never driven).
    // GPIO_0[4] (header pin 5) outputs the test square wave:
    // jumper header pin 5 -> pin 1 (GPIO_0[0]) to see it on CH0 with SW[0]=0.
    assign GPIO_0[3:0]  = 4'bz;
    assign GPIO_0[4]    = test_wave;
    assign GPIO_0[35:5] = 31'bz;

endmodule

`default_nettype wire
