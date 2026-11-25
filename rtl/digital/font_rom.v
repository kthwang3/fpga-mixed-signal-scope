// knows what every character looks like, providees the row's 8 pixels given a character and row number
module font_rom(char, row, bits);
    input  [6:0] char; // ASCII code
    input  [2:0] row; // which of the 8 rows
    output [7:0] bits; // the 8 pixels of that row
    reg [7:0] font [0:1023]; // array of 1024 slots each 8 bits wide
    parameter FONT_FILE = "font8x8.hex";
    initial $readmemh(FONT_FILE, font);   // fill from the file
    assign bits = font[{char, row}];          // look up
endmodule