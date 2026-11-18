module digital_view (clk, resetn, grant, x, y, colour, plot);

    input wire clk;
    input wire resetn;
    input wire grant;
    output reg [8:0] x;
    output reg [7:0] y;
    output wire [8:0] colour;
    output wire plot;

    assign colour = 9'b000_111_000; //green green me say alone ramp
    assign plot = grant;

    always @(posedge clk)
        if (!resetn) x <= 0;
        else if (x == 319 && grant) x <= 0;
        else if (grant) x <= x + 1;
    always @(posedge clk)
        if (!resetn) y <= 120;
        else if (x == 319 && y == 239 && grant) y <= 120;
        else if (x == 319 && grant) y <= y + 1; 

endmodule