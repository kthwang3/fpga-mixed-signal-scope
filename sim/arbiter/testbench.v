`timescale 1ns / 1ps
`default_nettype none

// Self-checking testbench for arbiter (r[0]/g[0] = digital, r[1]/g[1] = analog).
// Tests 1-7 check each transition directly. Test 8 runs 5000 random clocks
// and checks the rules every clock: at most one grant, only to a requester,
// never taken away while still requested, nobody waits too long.

module testbench ( );

    parameter CLOCK_PERIOD = 20;
    parameter MAX_WAIT     = 20;   // longest a requester may wait (other holds <= 16)

    reg        clk;
    reg        resetn;
    reg  [1:0] r;
    wire [1:0] g;

    integer errors    = 0;
    integer test      = 0;
    integer handovers = 0;         // direct GNT0 <-> GNT1 transitions seen in test 8

    initial clk = 1'b0;
    always #(CLOCK_PERIOD/2) clk = ~clk;

    arbiter DUT (.clk(clk), .resetn(resetn), .r(r), .g(g));

    // inputs change on the falling edge; g is checked one rising edge later
    task step_expect;
        input [1:0] exp;
        begin
            @(negedge clk);
            if (g !== exp) begin
                $display("ERROR t=%0t test %0d: r=%b g=%b, expected %b", $time, test, r, g, exp);
                errors = errors + 1;
            end
        end
    endtask

    task fail;
        input [8*40:1] msg;
        begin
            if (errors < 10) $display("ERROR t=%0t test 8: %0s (r=%b g=%b)", $time, msg, r, g);
            errors = errors + 1;
        end
    endtask

    // random requesters that behave like the views: raise req, wait for grant,
    // hold it for 1-16 clocks, drop req, stay quiet for a random time
    integer held [0:1];
    integer len  [0:1];
    integer wait_cnt [0:1];
    reg [1:0] g_prev;

    task random_run;
        input integer n;
        integer k, i;
        begin
            for (i = 0; i < 2; i = i + 1) begin
                held[i] = 0; len[i] = 0; wait_cnt[i] = 0;
            end
            g_prev = g;
            for (k = 0; k < n; k = k + 1) begin
                @(negedge clk);

                if (g === 2'b11) fail("both granted");
                if ((g_prev == 2'b01 && g == 2'b10) || (g_prev == 2'b10 && g == 2'b01))
                    handovers = handovers + 1;

                for (i = 0; i < 2; i = i + 1) begin
                    if (g[i] && !r[i])               fail("granted without a request");
                    if (g_prev[i] && r[i] && !g[i])  fail("grant taken away");
                    if (r[i] && !g[i]) begin
                        wait_cnt[i] = wait_cnt[i] + 1;
                        if (wait_cnt[i] > MAX_WAIT)  fail("requester starved");
                    end
                    else wait_cnt[i] = 0;
                end

                for (i = 0; i < 2; i = i + 1) begin
                    if (!r[i]) begin
                        if (($random & 7) == 0) begin
                            r[i]    = 1'b1;
                            len[i]  = 1 + ($random & 15);
                            held[i] = 0;
                        end
                    end
                    else if (g[i]) begin
                        held[i] = held[i] + 1;
                        if (held[i] >= len[i]) r[i] = 1'b0;
                    end
                end
                g_prev = g;
            end
        end
    endtask

    initial begin
        r = 2'b00;
        resetn = 1'b0;
        repeat (3) @(negedge clk);
        resetn = 1'b1;
        step_expect(2'b00);

        // 1: digital alone is granted next clock, keeps it, releases it
        test = 1;
        r = 2'b01; step_expect(2'b01);
        repeat (4) step_expect(2'b01);
        r = 2'b00; step_expect(2'b00);

        // 2: analog alone
        test = 2;
        r = 2'b10; step_expect(2'b10);
        repeat (4) step_expect(2'b10);
        r = 2'b00; step_expect(2'b00);

        // 3: both ask from IDLE, digital wins the tie
        test = 3;
        r = 2'b11; step_expect(2'b01);

        // 4: digital finishes while analog waits, handed straight over (round-robin)
        test = 4;
        r = 2'b10; step_expect(2'b10);

        // 5: digital asks while analog is drawing, analog keeps it (no preemption)
        test = 5;
        r = 2'b11; repeat (4) step_expect(2'b10);

        // 6: analog finishes while digital waits, handed straight over
        test = 6;
        r = 2'b01; step_expect(2'b01);
        r = 2'b00; step_expect(2'b00);

        // 7: reset during a grant returns to IDLE
        test = 7;
        r = 2'b01; step_expect(2'b01);
        resetn = 1'b0; step_expect(2'b00);
        resetn = 1'b1; r = 2'b00; step_expect(2'b00);
        $display("Tests 1-7 (directed): errors so far = %0d", errors);

        // 8: random requests
        test = 8;
        random_run(5000);
        $display("Test 8 (5000 random clocks): %0d direct handovers, errors so far = %0d",
                 handovers, errors);

        if (errors == 0) $display("PASS: all 8 tests passed");
        else             $display("FAIL: %0d errors", errors);
        $stop;
    end

endmodule

`default_nettype wire
