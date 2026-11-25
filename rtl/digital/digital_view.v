module digital_view (clk, resetn, grant, sample, ready, x, y, font_bits, colour, plot, req, rd_addr, start_capture, text_idx, text_row);

    input wire clk;
    input wire resetn;
    input wire grant;
    input wire sample;    // stored 0/1 for column rd_addr, from gpio_capture (1 clock late)
    input wire ready;    // gpio_capture is full: a complete recording is ready to draw. we can only start when we have everything
    output reg [8:0] x;
    output reg [7:0] y;
    output wire [8:0] colour;
    output wire plot;
    output wire req;
    output wire [8:0] rd_addr;      // which column's sample to read from gpio_capture
    output wire start_capture;      // pulse: tell gpio_capture to record again

    output [5:0] text_idx;   // which character slot (x/8)
    output [2:0] text_row;   // which row of the character
    input  [7:0] font_bits;  // 8 pixels of that row, from font_rom

    wire [7:0] ty = y - 8'd122;
    wire on_text = (y >= 122) && (y <= 129);
    assign text_idx = x[8:3];
    assign text_row = ty[2:0];
    wire text_pixel = font_bits[7 - x[2:0]];

    parameter DELAY = 1666666;   // 50 MHz / 30 ≈ 1.67M clks → redraw ~30 times/sec (board). DESim overrides to 1000, ModelSim to 5.
    reg [20:0] delay_cnt;

    wire[3:0] y_Q; //present state
    wire [3:0] Y; // next state

    wire delay_done = (delay_cnt == DELAY);
    wire last_pixel = (x == 319) && (y == 239);

    // each state: (enter from previous state) || (stay because not finished)
    // WAIT leaves only when the delay is over AND a full recording is ready
    assign Y[0] = ~resetn || y_Q[3] || (y_Q[0] && !(delay_done && ready));        //wait, delay counter counts up
    assign Y[1] = resetn && ((y_Q[0] && delay_done && ready) || (y_Q[1] && !grant)); //req, wait for grant
    assign Y[2] = resetn && ((y_Q[1] && grant) || (y_Q[2] && !(last_pixel && grant))); //sweep, run x/y counters
    assign Y[3] = resetn && y_Q[2] && last_pixel && grant;                            //done, 1 clock

    assign req = y_Q[1] | y_Q[2];
    assign start_capture = y_Q[3];  // DONE (1 clock): frame drawn, record a fresh one

    //reading samples from gpio_capture
    // The RAM answers 1 clock late, so we ask for the column x will be
    // on next clock. Then when x gets there, its sample has just arrived.
    wire advance = y_Q[2] && grant; // x moves this clock, used to be x <= x + 1
    assign rd_addr = !advance ? x : ((x == 319) ? 9'd0 : x + 9'd1);

    //what to draw at (x, y)
    parameter HIGH = 150;   // row for logic 1
    parameter LOW  = 210;   // row for logic 0

    wire s = sample; // the recorded 0/1 for column x
    reg  s_last; // the sample of the column we just drew
    always @(posedge clk)
        if (advance) s_last <= s;
    wire s_prev = (x == 0) ? s : s_last;   // column 0 has no column before it: no edge

    wire on_level = (y == (s ? HIGH : LOW));               // horizontal part of the trace
    wire on_edge  = (s != s_prev) && (y >= HIGH) && (y <= LOW); // vertical line where it switches
    wire on_trace = on_level || on_edge;

    assign colour = on_text  ? (text_pixel ? 9'b111_111_111 : 9'b000_000_000) :
        on_trace ? 9'b000_111_000 : 9'b000_000_000; // white text, green trace, black elsewhere (erases)
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