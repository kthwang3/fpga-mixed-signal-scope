`timescale 1ns / 1ps
`default_nettype none

// Self-checking testbench for byte_log and font_rom.
//
// 1  reset  : all 40 log slots read as space (0x20)
// 2  shift  : "ABC" lands in slots 37-39, the rest stay spaces
// 3  hold   : no valid pulse -> nothing moves
// 4  scroll : 45 more bytes -> oldest drop off the left, matches a model of the log
// 5  font   : "H" rows match the known shape, bit 7 is the leftmost pixel,
//             space and control characters are blank, every printable character has pixels

module testbench ( );

    parameter CLOCK_PERIOD = 20;

    reg        clk;
    reg        resetn;
    reg  [7:0] in_byte;
    reg        in_valid;
    reg  [5:0] rd_idx;
    wire [7:0] rd_char;
    reg  [6:0] char;
    reg  [2:0] row;
    wire [7:0] bits;

    integer errors = 0;
    integer test = 0;

    initial clk = 1'b0;
    always #(CLOCK_PERIOD/2) clk = ~clk;

    byte_log LOG (.clk(clk), .resetn(resetn), .in_byte(in_byte), .in_valid(in_valid),
                  .rd_idx(rd_idx), .rd_char(rd_char));
    font_rom #(.FONT_FILE("../../rtl/digital/font8x8.hex")) FONT (.char(char), .row(row), .bits(bits));

    // model of what the log should hold
    reg [7:0] model [0:39];
    integer i;

    task push;
        input [7:0] b;
        begin
            in_byte = b; in_valid = 1'b1;
            @(negedge clk) in_valid = 1'b0;
            for (i = 0; i < 39; i = i + 1) model[i] = model[i+1];
            model[39] = b;
        end
    endtask

    task check_log;
        begin
            for (i = 0; i < 40; i = i + 1) begin
                rd_idx = i;
                #1;
                if (rd_char !== model[i]) begin
                    if (errors < 10) $display("ERROR test %0d: slot %0d = %h, expected %h", test, i, rd_char, model[i]);
                    errors = errors + 1;
                end
            end
        end
    endtask

    reg [7:0] h_rows [0:7];
    integer c, r, lit;

    initial begin
        resetn = 1'b0; in_valid = 1'b0; in_byte = 8'h00; rd_idx = 0; char = 0; row = 0;
        for (i = 0; i < 40; i = i + 1) model[i] = 8'h20;
        repeat (3) @(negedge clk);
        resetn = 1'b1;

        test = 1;
        check_log;

        test = 2;
        push("A"); push("B"); push("C");
        check_log;

        test = 3;
        repeat (10) @(negedge clk);
        check_log;

        test = 4;
        for (c = 0; c < 45; c = c + 1) push(8'h30 + (c % 10));   // "0123456789..."
        check_log;
        $display("Tests 1-4 (byte_log): errors so far = %0d", errors);

        test = 5;
        h_rows[0] = 8'hCC; h_rows[1] = 8'hCC; h_rows[2] = 8'hCC; h_rows[3] = 8'hFC;
        h_rows[4] = 8'hCC; h_rows[5] = 8'hCC; h_rows[6] = 8'hCC; h_rows[7] = 8'h00;
        char = "H";
        for (r = 0; r < 8; r = r + 1) begin
            row = r; #1;
            if (bits !== h_rows[r]) begin
                if (errors < 10) $display("ERROR test 5: H row %0d = %h, expected %h", r, bits, h_rows[r]);
                errors = errors + 1;
            end
        end
        row = 0; #1;
        if (bits[7] !== 1'b1 || bits[0] !== 1'b0) begin
            $display("ERROR test 5: H row 0 should start with a lit pixel on the left (bit 7)");
            errors = errors + 1;
        end

        for (c = 0; c < 128; c = c + 1) begin
            lit = 0;
            char = c;
            for (r = 0; r < 8; r = r + 1) begin
                row = r; #1;
                if (bits !== 8'h00) lit = lit + 1;
            end
            if (c <= 8'h20 && lit != 0) begin
                if (errors < 10) $display("ERROR test 5: char %h should be blank", c);
                errors = errors + 1;
            end
            if (c > 8'h20 && c < 8'h7F && lit == 0) begin
                if (errors < 10) $display("ERROR test 5: printable char %h has no pixels", c);
                errors = errors + 1;
            end
        end
        $display("Test 5 (font_rom): errors so far = %0d", errors);

        if (errors == 0) $display("PASS: all 5 tests passed");
        else             $display("FAIL: %0d errors", errors);
        $stop;
    end

endmodule

`default_nettype wire
