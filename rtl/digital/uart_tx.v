//fpga controlled uart transmitter, will add a laptop usb adapter later

module uart_tx(clk, resetn, data, send, tx, busy);
    input clk, resetn;
    input [7:0] data; // the byte to send
    input send; // 1 -clock pulse to send data now
    output tx;
    output busy; // 1 while sending
    parameter CLKS_PER_BIT = 5208; // 9600 baud at 50 Mhz

    parameter IDLE = 1'b0, SEND = 1'b1;
    reg [9:0] shift;
    reg [12:0] baud_cnt, bit_cnt;
    wire bit_done = (baud_cnt == CLKS_PER_BIT - 1);
    reg[1:0] state;

    //baud counter: counts 0 -> CLKS_PER_BIT -1 and says time for next bit
    always @(posedge clk)
        if (!resetn || (state == IDLE && send)) baud_cnt <= 0;
        else if (bit_done) baud_cnt <= 0;
        else if (state == SEND) baud_cnt <= baud_cnt + 1;

    //bit counter: counts which of the 10 bits we're on, and when to stop (UART has a start stop and 8 bits)
    always @(posedge clk)
        if (!resetn || (state == IDLE && send)) bit_cnt <= 0;
        else if (state == SEND && bit_done) bit_cnt <= bit_cnt + 1;

    //shift register
    always @(posedge clk)
        if (state == IDLE && send) shift <= {1'b1, data, 1'b0};
        else if (state == SEND && bit_done) shift <= {1'b1, shift[9:1]};

    //fsm
    always @(posedge clk)
        if (!resetn) state <= IDLE;
        else case (state)
            IDLE: if (send) 
                state <= SEND;
            SEND: 
                if (bit_cnt == 10) state <= IDLE;
        endcase
    
    assign tx = (state == SEND) ? shift[0] : 1'b1;
    assign busy = (state == SEND);


endmodule