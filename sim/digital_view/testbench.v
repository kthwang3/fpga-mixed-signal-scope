`timescale 1ns / 1ps
`default_nettype none

// Self-checking testbench for digital_view.
//
// Runs two full frames and checks every pixel the DUT plots:
//   1. it is inside the digital region (x 0-319, y 120-239)
//   2. it is only plotted in the SWEEP state
//   3. its colour matches a reference model of the square-wave trace
//   4. each frame plots exactly 320 x 120 = 38400 pixels
// Prints PASS or the number of errors at the end.

module testbench ( );

    parameter CLOCK_PERIOD = 20;     // 50 MHz
    parameter FRAMES       = 2;      // how many frames to check before stopping

    localparam GREEN = 9'b000_111_000;
    localparam BLACK = 9'b000_000_000;
    localparam HIGH  = 150;
    localparam LOW   = 210;

    reg        clk;
    reg        resetn;
    wire       req;
    wire       grant;
    wire [8:0] x;
    wire [7:0] y;
    wire [8:0] colour;
    wire       plot;

    // no arbiter yet: granted as soon as it asks (same as scope_core)
    assign grant = req;

    // ---------------- clock ----------------
    initial clk = 1'b0;
    always #(CLOCK_PERIOD/2) clk = ~clk;

    // ---------------- reset ----------------
    initial begin
        resetn = 1'b0;               // hold reset for 3 clocks
        #(3*CLOCK_PERIOD) resetn = 1'b1;
    end

    // ---------------- device under test ----------------
    // DELAY overridden to 5 so we don't simulate 1.67M idle clocks
    digital_view #(.DELAY(5)) DUT (
        .clk    (clk),
        .resetn (resetn),
        .grant  (grant),
        .x      (x),
        .y      (y),
        .colour (colour),
        .plot   (plot),
        .req    (req)
    );

    // ---------------- reference model ----------------
    // Expected colour, written independently of the DUT:
    // the signal is 1 on columns 16-31, 48-63, ... (x/16 is odd),
    // and an edge is drawn on every 16th column.
    wire       ref_bit   = (x / 16) % 2;
    wire [7:0] ref_row   = ref_bit ? HIGH : LOW;
    wire       ref_edge  = (x % 16 == 0) && (y >= HIGH) && (y <= LOW);
    wire [8:0] ref_colour = ((y == ref_row) || ref_edge) ? GREEN : BLACK;

    // ---------------- checker (scoreboard) ----------------
    integer errors     = 0;
    integer pixels     = 0;   // pixels plotted in the current frame
    integer frames     = 0;
    reg     req_prev   = 1'b0;

    always @(posedge clk) begin
        if (resetn) begin
            if (plot) begin
                pixels = pixels + 1;

                // check 1: stay inside the digital region
                if (x > 319 || y < 120 || y > 239) begin
                    errors = errors + 1;
                    $display("ERROR %0t: plotted outside region at (%0d,%0d)", $time, x, y);
                end

                // check 2: only plot while sweeping
                if (!DUT.y_Q[2]) begin
                    errors = errors + 1;
                    $display("ERROR %0t: plot high outside SWEEP state", $time);
                end

                // check 3: colour matches the reference model
                if (colour !== ref_colour) begin
                    errors = errors + 1;
                    if (errors <= 10)   // don't flood the transcript
                        $display("ERROR %0t: (%0d,%0d) colour %b, expected %b",
                                 $time, x, y, colour, ref_colour);
                end
            end

            // end of a frame = req falling edge
            if (req_prev && !req) begin
                frames = frames + 1;

                // check 4: every pixel of the region drawn exactly once
                if (pixels != 320*120) begin
                    errors = errors + 1;
                    $display("ERROR: frame %0d plotted %0d pixels, expected 38400", frames, pixels);
                end else
                    $display("frame %0d done at %0t: 38400 pixels plotted", frames, $time);

                pixels = 0;

                if (frames == FRAMES) begin
                    if (errors == 0) $display("PASS: %0d frames, no errors", frames);
                    else             $display("FAIL: %0d errors", errors);
                    $stop;
                end
            end
            req_prev = req;
        end
    end

endmodule

`default_nettype wire
