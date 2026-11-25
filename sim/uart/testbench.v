`timescale 1ns / 1ps
`default_nettype none

// Self-checking testbench for uart_tx and uart_rx (CLKS_PER_BIT = 32 to keep it short).
// tx is checked bit by bit against the UART frame it should send.
// rx is checked with a scoreboard: every good byte must come out once, in order,
// with one valid pulse, and bad frames must produce nothing.
//
// 1  idle    : after reset tx = 1, busy = 0
// 2  tx      : fixed bytes, every bit of every frame checked mid-bit, busy checked
// 3  loop    : 200 random bytes back-to-back, tx -> rx, all received in order
// 4  framing : stop bit = 0 -> no valid; glitch shorter than half a bit -> no valid
// 5  baud    : rx still decodes bytes sent about 3% too fast and too slow
//              (UART tolerates about 5%: half a bit of drift over 9.5 bits)

module testbench ( );

    parameter CLOCK_PERIOD = 20;
    parameter C = 32;   // clocks per bit

    reg        clk;
    reg        resetn;
    reg  [7:0] data;
    reg        send;
    wire       tx, busy;
    reg        line;     // rx input when the testbench drives the line itself
    reg        use_tx;   // 1: rx listens to uart_tx, 0: rx listens to line
    wire [7:0] rx_data;
    wire       rx_valid;

    integer errors = 0;
    integer test = 0;

    initial clk = 1'b0;
    always #(CLOCK_PERIOD/2) clk = ~clk;

    uart_tx #(.CLKS_PER_BIT(C)) TX (.clk(clk), .resetn(resetn), .data(data), .send(send), .tx(tx), .busy(busy));
    uart_rx #(.CLKS_PER_BIT(C)) RX (.clk(clk), .resetn(resetn), .rx(use_tx ? tx : line),
                                   .data(rx_data), .valid(rx_valid));

    task fail;
        input [8*48:1] msg;
        begin
            if (errors < 10) $display("ERROR t=%0t test %0d: %0s", $time, test, msg);
            errors = errors + 1;
        end
    endtask

    // scoreboard: bytes rx should produce, in order
    reg [7:0] exp [0:255];
    integer wr = 0, rd = 0;

    task expect_byte;
        input [7:0] b;
        begin
            exp[wr % 256] = b;
            wr = wr + 1;
        end
    endtask

    always @(posedge clk)
        if (resetn && rx_valid) begin
            if (rd == wr) fail("rx produced a byte nobody sent");
            else begin
                if (rx_data !== exp[rd % 256]) begin
                    if (errors < 10) $display("ERROR t=%0t test %0d: rx got %h, expected %h",
                                              $time, test, rx_data, exp[rd % 256]);
                    errors = errors + 1;
                end
                rd = rd + 1;
            end
        end

    task check_all_received;
        begin
            while (busy) @(negedge clk);
            repeat (12*C) @(negedge clk);    // a whole frame plus margin for the last byte
            if (rd != wr) begin
                if (errors < 10) $display("ERROR test %0d: sent %0d bytes, rx produced %0d", test, wr, rd);
                errors = errors + 1;
                rd = wr;
            end
        end
    endtask

    // send one byte through uart_tx and check the frame on tx bit by bit
    reg [9:0] frame;
    integer k;

    task send_and_check;
        input [7:0] b;
        begin
            while (busy) @(negedge clk);
            data = b; send = 1'b1;
            @(negedge clk) send = 1'b0;
            frame = {1'b1, b, 1'b0};             // stop, data, start (start sent first)
            repeat (C/2 - 1) @(negedge clk);     // middle of the start bit
            for (k = 0; k < 10; k = k + 1) begin
                if (tx !== frame[k]) begin
                    if (errors < 10) $display("ERROR t=%0t test %0d: byte %h bit %0d is %b, expected %b",
                                              $time, test, b, k, tx, frame[k]);
                    errors = errors + 1;
                end
                if (busy !== 1'b1) fail("busy low in the middle of a frame");
                if (k < 9) repeat (C) @(negedge clk);
            end
            repeat (C/2 + 2) @(negedge clk);     // past the end of the stop bit
            if (busy !== 1'b0) fail("busy still high after the stop bit");
            if (tx !== 1'b1)   fail("tx not idle (1) after the stop bit");
        end
    endtask

    // drive the rx line directly: bitlen clocks per bit, chosen stop bit value
    integer j;
    task drive_byte;
        input [7:0] b;
        input integer bitlen;
        input stop_val;
        begin
            line = 1'b0; repeat (bitlen) @(negedge clk);
            for (j = 0; j < 8; j = j + 1) begin
                line = b[j]; repeat (bitlen) @(negedge clk);
            end
            line = stop_val; repeat (bitlen) @(negedge clk);
            line = 1'b1; repeat (2*C) @(negedge clk);
        end
    endtask

    integer n;
    reg [7:0] r;

    initial begin
        resetn = 1'b0; send = 1'b0; data = 8'h00; line = 1'b1; use_tx = 1'b1;
        repeat (3) @(negedge clk);
        resetn = 1'b1;

        test = 1;
        @(negedge clk);
        if (tx !== 1'b1)   fail("tx not 1 after reset");
        if (busy !== 1'b0) fail("busy not 0 after reset");

        test = 2;
        expect_byte(8'h48); send_and_check(8'h48);  // H
        expect_byte(8'h00); send_and_check(8'h00);
        expect_byte(8'hFF); send_and_check(8'hFF);
        expect_byte(8'h55); send_and_check(8'h55);
        expect_byte(8'hAA); send_and_check(8'hAA);
        expect_byte(8'h80); send_and_check(8'h80);
        expect_byte(8'h01); send_and_check(8'h01);
        check_all_received;
        $display("Tests 1-2 (idle, tx frames): errors so far = %0d", errors);

        test = 3;
        for (n = 0; n < 200; n = n + 1) begin
            r = $random;
            expect_byte(r);
            while (busy) @(negedge clk);
            data = r; send = 1'b1;
            @(negedge clk) send = 1'b0;
            @(negedge clk);
        end
        check_all_received;
        $display("Test 3 (200 random bytes tx -> rx): errors so far = %0d", errors);

        test = 4;
        use_tx = 1'b0;
        repeat (2*C) @(negedge clk);
        drive_byte(8'h41, C, 1'b0);                 // bad stop bit: nothing expected
        line = 1'b0; repeat (C/4) @(negedge clk);   // glitch, shorter than half a bit
        line = 1'b1; repeat (2*C) @(negedge clk);
        expect_byte(8'h5A); drive_byte(8'h5A, C, 1'b1);  // rx must still work afterwards
        check_all_received;
        $display("Test 4 (framing error, glitch): errors so far = %0d", errors);

        test = 5;
        expect_byte(8'hC3); drive_byte(8'hC3, C - 1, 1'b1);   // about 3% fast
        expect_byte(8'h3C); drive_byte(8'h3C, C + 1, 1'b1);   // about 3% slow
        check_all_received;
        $display("Test 5 (baud tolerance): errors so far = %0d", errors);

        if (errors == 0) $display("PASS: all 5 tests passed (%0d bytes received)", rd);
        else             $display("FAIL: %0d errors", errors);
        $stop;
    end

endmodule

`default_nettype wire
