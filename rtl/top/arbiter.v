// Author: Kyle Wang
// November 20, 2026
// arbiter is round robin style, deciding between digital and analog write to vga
module arbiter (clk, resetn, r, g);
    input wire clk, resetn;
    input wire [1:0] r; // r[0] = digital_view req, r[1] = analog_view req
    output reg [1:0] g; // g[0] = digital grant, g[1] = analog grant
    reg [1:0] y, Y;

    //3 states: IDLE, GNT0 (digital), GNT1 (analog)

    parameter IDLE = 2'b00, GNT0 = 2'b01, GNT1 = 2'b10;

    //state table
    always @(*)
        //if digital and analog both ask, digital goes first
        case (y)
            IDLE: if (r[0]) Y = GNT0;
                else if (r[1]) Y = GNT1;
                else Y = IDLE;
            GNT0: if (r[0]) Y = GNT0;
                else if (r[1]) Y = GNT1;
                else Y = IDLE;
            GNT1: if (r[1]) Y = GNT1;
                else if (r[0]) Y = GNT0;
                else Y = IDLE;
            default: Y = IDLE;
        endcase
    
    //state FFS
    always @(posedge clk)
        if (!resetn)
            y <= IDLE;
        else y <= Y;
    
    //fsm outputs
    always @(*) begin
        g = 2'b00; //default: nobody granted
        if (y == GNT0) g[0] = 1'b1;
        if (y == GNT1) g[1] = 1'b1; 
    end
endmodule