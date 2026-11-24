// feeds uart_tx the message "HELLO", then leaves the line idle for GAP_CLKS clocks, forever

module msg_seq(clk, resetn, busy, data, send);
    input clk, resetn;
    input busy; // from uart_tx: 1 while a byte is going out
    output reg [7:0] data; // byte for uart_tx
    output send; // 1-clock pulse: send data now
    parameter GAP_CLKS = 500000; // idle clocks between messages (10 ms at 50 MHz)

    parameter SEND = 2'd0, WAIT_DONE = 2'd1, GAP = 2'd2;
    reg [1:0] state;
    reg [2:0] idx; // which letter, 0-4
    reg [19:0] gap_cnt;
    wire last = (idx == 4);
    wire gap_done = (gap_cnt == GAP_CLKS - 1);

    //letters of the message
    always @(*)
        case (idx)
            0: data = "H";
            1: data = "E";
            2: data = "L";
            3: data = "L";
            default: data = "O";
        endcase

    //fsm: SEND pulses send for 1 clock, WAIT_DONE waits for uart_tx to finish the byte,
    //GAP idles after the last letter so the trigger sees a clean start bit
    always @(posedge clk)
        if (!resetn) state <= GAP;
        else case (state)
            SEND: state <= WAIT_DONE;
            WAIT_DONE: if (!busy) state <= last ? GAP : SEND;
            GAP: if (gap_done) state <= SEND;
            default: state <= GAP;
        endcase

    //next letter after each byte finishes, back to H after O
    always @(posedge clk)
        if (!resetn) idx <= 0;
        else if (state == WAIT_DONE && !busy) idx <= last ? 0 : idx + 1;

    always @(posedge clk)
        if (!resetn || state != GAP) gap_cnt <= 0;
        else gap_cnt <= gap_cnt + 1;

    assign send = (state == SEND);

endmodule
