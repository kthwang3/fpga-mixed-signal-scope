// DESim wrapper for the FPGA mixed-signal oscilloscope.
//
// Plumbing only: connects the DESim "board" (tb.v) to scope_core and to the
// DESim version of the course VGA adapter. All project logic lives in
// rtl/top/scope_core.v so the same core can be reused by the board wrapper.
//
// Structure adapted from the ECE241 VGA Adapter "animate" DESim example (FPGAcademy).

`default_nettype none

module top (CLOCK_50, SW, KEY, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, LEDR,
            VGA_X, VGA_Y, VGA_COLOR, plot, GPIO);

    input  wire        CLOCK_50;   // 50 MHz clock
    input  wire [9:0]  SW;         // switches
    input  wire [3:0]  KEY;        // pushbuttons (active-low)
    output wire [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    output wire [9:0]  LEDR;
    output wire [9:0]  VGA_X;      // DESim VGA window: pixel column
    output wire [8:0]  VGA_Y;      // DESim VGA window: pixel row
    output wire [23:0] VGA_COLOR;  // DESim VGA window: 24-bit colour
    output wire        plot;       // DESim VGA window: draw this pixel
    inout  wire [31:0] GPIO;       // 40-pin header (DESim exposes 32 pins)

    parameter RESOLUTION  = "320x240";
    parameter COLOR_DEPTH = 9;

    // Signals between the core and the adapter (320x240: x is 9 bits, y is 8 bits)
    wire [8:0] core_x;
    wire [7:0] core_y;
    wire [8:0] core_colour;
    wire       core_write;

    scope_core CORE (
        .clk     (CLOCK_50),
        .resetn  (KEY[0]),
        .SW      (SW),
        .KEY     (KEY[3:1]),
        .gpio_in (GPIO[3:0]),      // digital channels CH0-CH3
        .LEDR    (LEDR),
        .HEX0    (HEX0), .HEX1(HEX1), .HEX2(HEX2),
        .HEX3    (HEX3), .HEX4(HEX4), .HEX5(HEX5),
        .x       (core_x),
        .y       (core_y),
        .colour  (core_colour),
        .write   (core_write)
    );

    // VGA_MEMORY is not defined, so the adapter has no background image:
    // our pixels go straight to the DESim window and VGA_SYNC is always 1.
    vga_adapter VGA (
        .resetn    (KEY[0]),
        .clock     (CLOCK_50),
        .color     (core_colour),
        .x         (core_x),
        .y         (core_y),
        .write     (core_write),
        .VGA_X     (VGA_X[8:0]),
        .VGA_Y     (VGA_Y[7:0]),
        .VGA_COLOR (VGA_COLOR),
        .VGA_SYNC  (),
        .plot      (plot)
    );
        defparam VGA.RESOLUTION  = RESOLUTION;
        defparam VGA.COLOR_DEPTH = COLOR_DEPTH;

    // Unused top bits of the DESim coordinate buses
    assign VGA_X[9] = 1'b0;
    assign VGA_Y[8] = 1'b0;

    // We only read GPIO, never drive it
    assign GPIO = 32'hZZZZZZZZ;

endmodule

`default_nettype wire
