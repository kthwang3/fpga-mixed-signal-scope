module uart_rx(clk, resetn, rx, data, valid);
    input clk, resetn;
    input rx; //the line to decode (ch0)
    output reg [7:0] data; //last byte received, and only meaningful when valid = 1
    output valid; //1 clock pulse "new byte in data" because you can send duplicate bytes and later on you wouldnt know when it was sent or whether its a new letter
    parameter CLKS_PER_BIT = 5208;

    //this is because outside signal can change at any moment, causing sync1 to get stuck between 0 and 1
    reg sync1;
    reg sync2;

    always @(posedge clk) begin
        sync1 <= rx;
        sync2 <= sync1;
    end

    parameter IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
    reg [12:0] baud_cnt, bit_cnt;
    wire bit_done = (baud_cnt == CLKS_PER_BIT - 1);
    wire half_done = (baud_cnt == CLKS_PER_BIT/2 - 1);
    reg[1:0] state;

    //baud counter: counts 0 -> CLKS_PER_BIT -1 and says time for next bit
    always @(posedge clk)
        if (!resetn || (state == IDLE)) baud_cnt <= 0;
        else if (state == START && half_done) baud_cnt <= 0; // middle of start bit: restart
        else if (bit_done) baud_cnt <= 0;
        else baud_cnt <= baud_cnt + 1;

    //bit counter: counts which of the 10 bits we're on, and when to stop (UART has a start stop and 8 bits)
    always @(posedge clk)
        if (!resetn || (state == IDLE)) bit_cnt <= 0;
        else if (state == DATA && bit_done) bit_cnt <= bit_cnt + 1;
    //shift register
    always @(posedge clk)
        if (!resetn) data <= 0;
        else if (state == DATA && bit_done) data <= {sync2, data[7:1]};
    assign valid = (state == STOP && bit_done && sync2);
    //fsm
    always @(posedge clk)
        if (!resetn) state <= IDLE;
        else case (state)
            IDLE: if (sync2 == 0) state <= START;
            START: if (half_done) state <= (sync2 == 0) ? DATA : IDLE;  //taking middle of bit ensures its accurate
            DATA: if (bit_cnt == 8) state <= STOP;
            STOP: if (bit_done) state <= IDLE;
        endcase 
endmodule