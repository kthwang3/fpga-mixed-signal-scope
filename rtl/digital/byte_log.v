// remembers the last 40 bytes received from uart_rx, then provides it to digital_view when asked for it

module byte_log(clk, resetn, in_byte, in_valid, rd_idx, rd_char);
    input clk, resetn;
    input [7:0] in_byte; // from uart_rx data
    input in_valid; // from uart_rx valid
    input [5:0] rd_idx; // which slot digital_view wants (x/8, 0-39)
    output [7:0] rd_char;  // the byte stored there
    reg [7:0] log [0:39]; //maps 40 character positions across the screen. (screen is 320 pixesls and each character is 8 pixels wide)
    integer i;

    // new byte goes in on the right, everything moves one slot left
    always @(posedge clk)
        if (!resetn)
            for (i = 0; i < 40; i = i + 1) log[i] <= 8'h20;   // space
        else if (in_valid) begin
            for (i = 0; i < 39; i = i + 1) log[i] <= log[i+1];
            log[39] <= in_byte;
        end

    assign rd_char = log[rd_idx];
endmodule