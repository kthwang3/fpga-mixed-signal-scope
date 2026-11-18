module digital_view (clk, resetn, grant, x, y, colour, plot, req);

    input wire clk;
    input wire resetn;
    input wire grant;
    output reg [8:0] x;
    output reg [7:0] y;
    output wire [8:0] colour;
    output wire plot;
    output wire req;

    parameter DELAY = 1000;   // 50 MHz / 30 ≈ 1.67M clks → redraw ~30 times/sec , on DESIM set to 1000 board set 1 666 666
    reg [20:0] delay_cnt;

    wire[3:0] y_Q; //present state
    wire [3:0] Y; // next state

    wire delay_done = (delay_cnt == DELAY);
    wire last_pixel = (x == 319) && (y == 239);

    // each state: (enter from previous state) || (stay because not finished)
    assign Y[0] = ~resetn || y_Q[3] || (y_Q[0] && !delay_done);                   //wait, delay counter counts up
    assign Y[1] = resetn && ((y_Q[0] && delay_done) || (y_Q[1] && !grant));         //req, wait for grant
    assign Y[2] = resetn && ((y_Q[1] && grant) || (y_Q[2] && !(last_pixel && grant))); //sweep, run x/y counters
    assign Y[3] = resetn && y_Q[2] && last_pixel && grant;                            //done, 1 clock

    assign req = y_Q[1] | y_Q[2];
    assign colour = 9'b000_111_000; //green green me say alone ramp
    assign plot = y_Q[2] && grant;

    always @(posedge clk)
        if (!resetn) x <= 0;
        else if (y_Q[2] && x == 319 && grant) x <= 0;
        else if (y_Q[2] && grant) x <= x + 1;
    always @(posedge clk)
        if (!resetn) y <= 120;
        else if (y_Q[2] && x == 319 && y == 239 && grant) y <= 120;
        else if (y_Q[2] && x == 319 && grant) y <= y + 1; 
    always @(posedge clk)
        if (!resetn) delay_cnt <= 0;
        else if (y_Q[0] && delay_cnt == DELAY) delay_cnt <= 0;
        else if (y_Q[0]) delay_cnt <= delay_cnt + 1;

    //State flip flops
    my_dff F0 (Y[0], clk, y_Q[0]);
    my_dff F1 (Y[1], clk, y_Q[1]);
    my_dff F2 (Y[2], clk, y_Q[2]);
    my_dff F3 (Y[3], clk, y_Q[3]);

endmodule

module my_dff(D, clk, Q);
    input D, clk;
    output reg Q;

    always @(posedge clk)
        Q <= D;
endmodule