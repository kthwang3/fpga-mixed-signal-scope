module gpio_capture (clk, resetn, gpio_in, rd_addr, rd_data, full);
    //rd_addr = read addresss that digital_view asks for
    //rd_data = the answer that is stored in the RAM address

    parameter N = 650; // number of clocks betweens samples, ie. 650 x 20 ns per clock = 13 micro secs

    input wire clk;
    input wire resetn;
    input wire gpio_in;
    input wire [8:0] rd_addr;
    output reg rd_data;
    output reg full; // once we have caputred all 320 samples (columns = timestamp)

    //this is because outside signal can change at any moment, causing sync1 to get stuck between 0 and 1
    reg sync1;
    reg sync2;

    reg mem [0:319];
    reg [15:0] dec_cnt; 
    wire tick = (dec_cnt == N - 1); // means take a sample now
    reg [8:0] wr_addr; //keep track of which address we are writing to
    always @(posedge clk) begin
        sync1 <= gpio_in;
        sync2 <= sync1;
    end

    always @(posedge clk) rd_data <= mem[rd_addr];

    always @(posedge clk)
        if (!resetn) dec_cnt <= 0;
        else if (tick) dec_cnt <= 0;
        else dec_cnt <= dec_cnt + 1;
    
    always @(posedge clk)
        if (!resetn) wr_addr <= 0;
        else if (tick && !full) begin
            mem[wr_addr] <= sync2;
            wr_addr <= wr_addr + 1;
        end
        
    always @(posedge clk)
        if (!resetn) full <= 0;
        else if (tick && wr_addr == 319) full <= 1; // just wrote the last slot

endmodule