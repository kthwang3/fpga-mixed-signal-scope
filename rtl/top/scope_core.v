module scope_core (clk, resetn, SW, KEY, gpio_in, LEDR, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, x, y, colour, write);
    input  wire        clk;   // 50 MHz clock
    input  wire        resetn;
    input  wire [9:0]  SW;         // switches
    input  wire [3:0]  KEY;        // pushbuttons (active-low)
    input  wire [3:0]  gpio_in;
    output wire [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    output wire [9:0]  LEDR;
    output wire [8:0]  x;      
    output wire [7:0]  y;      
    output wire [8:0]  colour;  
    output wire        write;   

    assign LEDR = 10'b0;
    assign HEX0 = 7'b1111111;
    assign HEX1 = 7'b1111111;
    assign HEX2 = 7'b1111111;
    assign HEX3 = 7'b1111111;
    assign HEX4 = 7'b1111111;
    assign HEX5 = 7'b1111111;
    
    assign x = 9'b0;
    assign y = 8'b0;
    assign colour = 9'b0;
    assign write = 1'b0;


    wire req;
    


endmodule