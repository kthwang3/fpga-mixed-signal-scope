`timescale 1ns / 1ps
`default_nettype none

// Self-checking testbench for gpio_capture.
//
// gpio_in gets a new random 0/1 every clock, so any timing mistake
// (wrong sync delay, sampling on the wrong clock, wrong slot) shows up.
//
// Test 1  record : every clock, full must be 1 exactly when 320 samples are in
// Test 2  stop   : after full, keep running 25 more sample periods;
//                  full must stay 1 and the memory must not change
// Test 3  read   : read all 320 slots back-to-back (like digital_view does)
//                  and compare with the reference model, 1-clock read latency
// Test 4  rerun  : press reset again, record new data, read it back again
// Test 5  re-arm : pulse start (no reset), record fresh data, read it back
//
// Prints PASS or the number of errors at the end, then $stop.

module testbench ( );

    parameter CLOCK_PERIOD = 20;     // 50 MHz
    parameter N            = 4;      // sample every 4 clocks (board uses 650)

    reg        clk;
    reg        resetn;
    reg        start;
    reg        gpio_in;
    reg  [8:0] rd_addr;
    wire       rd_data;
    wire       full;

    integer errors = 0;
    integer test   = 0;              // which test is running (shown in wave.do)
    integer a;

    // ---------------- clock ----------------
    initial clk = 1'b0;
    always #(CLOCK_PERIOD/2) clk = ~clk;

    // ---------------- input signal ----------------
    // new random bit on every falling edge (inputs change away from the rising edge)
    always @(negedge clk) gpio_in <= $random;

    // ---------------- device under test ----------------
    gpio_capture #(.N(N)) DUT (
        .clk     (clk),
        .resetn  (resetn),
        .start   (start),
        .gpio_in (gpio_in),
        .rd_addr (rd_addr),
        .rd_data (rd_data),
        .full    (full)
    );

    // ---------------- reference model ----------------
    // Written separately from the DUT: what SHOULD be in each slot.
    //   g2      = gpio_in delayed 2 clocks (what the synchronizer outputs)
    //   ref_cnt = its own sample counter, ref_k = how many samples stored so far
    reg     g1, g2;
    integer ref_cnt, ref_k;
    reg     ref_mem [0:319];

    always @(posedge clk) begin
        g1 <= gpio_in;
        g2 <= g1;
        if (!resetn) begin
            ref_cnt <= 0;
            ref_k   <= 0;
        end
        else if (ref_cnt == N-1) begin
            ref_cnt <= 0;
            if (start)                 // re-arm: start over at slot 0
                ref_k <= 0;
            else if (ref_k < 320) begin
                ref_mem[ref_k] <= g2;
                ref_k          <= ref_k + 1;
            end
        end
        else begin
            ref_cnt <= ref_cnt + 1;
            if (start) ref_k <= 0;     // re-arm: start over at slot 0
        end
    end

    // ---------------- checker: full flag, every clock ----------------
    always @(negedge clk)
        if (resetn && full !== (ref_k == 320)) begin
            if (errors < 10)
                $display("ERROR t=%0t: full=%b but %0d samples stored", $time, full, ref_k);
            errors = errors + 1;
        end

    // ---------------- read all 320 slots and compare ----------------
    // Address changes every clock; the answer for address a arrives
    // one clock later, so we check slot a-1 while asking for slot a.
    task read_back;
        begin
            @(negedge clk) rd_addr = 0;
            for (a = 1; a <= 320; a = a + 1) begin
                @(negedge clk);
                if (rd_data !== ref_mem[a-1]) begin
                    if (errors < 10)
                        $display("ERROR t=%0t: slot %0d read %b, expected %b",
                                 $time, a-1, rd_data, ref_mem[a-1]);
                    errors = errors + 1;
                end
                if (a < 320) rd_addr = a;
            end
        end
    endtask

    // ---------------- test sequence ----------------
    initial begin
        rd_addr = 0;
        start   = 0;

        // Test 1: reset for 3 clocks, then let it record until full
        test = 1;
        resetn = 1'b0;
        repeat (3) @(negedge clk);
        resetn = 1'b1;
        @(posedge full);
        $display("Test 1: full after %0d samples at t=%0t", ref_k, $time);

        // Test 2: keep running 25 more sample periods, nothing may change
        test = 2;
        repeat (25*N) @(negedge clk);

        // Test 3: read everything back
        test = 3;
        read_back;
        $display("Test 3: read back 320 slots, errors so far = %0d", errors);

        // Test 4: reset again, record new random data, read it back
        test = 4;
        resetn = 1'b0;
        repeat (3) @(negedge clk);
        if (full !== 1'b0) begin
            $display("ERROR t=%0t: full did not clear on reset", $time);
            errors = errors + 1;
        end
        resetn = 1'b1;
        @(posedge full);
        read_back;
        $display("Test 4: re-recorded and read back, errors so far = %0d", errors);

        // Test 5: re-arm with a 1-clock start pulse (no reset), like digital_view does
        test = 5;
        @(negedge clk) start = 1;
        @(negedge clk) start = 0;
        if (full !== 1'b0) begin
            $display("ERROR t=%0t: full did not clear on start", $time);
            errors = errors + 1;
        end
        @(posedge full);
        read_back;
        $display("Test 5: re-armed with start and read back, errors so far = %0d", errors);

        if (errors == 0) $display("PASS: all 5 tests passed");
        else             $display("FAIL: %0d errors", errors);
        $stop;
    end

endmodule

`default_nettype wire
