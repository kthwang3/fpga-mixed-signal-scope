module analog_view (clk, resetn, grant, xpixel, ypixel, colour, plot, req, adc_cs_n, adc_saddr, adc_sclk, adc_sdat);

    input wire clk;
    input wire resetn;

    // arbiter
    input wire grant;
    output wire req;
    assign req = 1'b0;

    // vga
    output wire [8:0] xpixel;
    output wire [7:0] ypixel;
    output wire [8:0] colour;
    output wire plot;
    
    wire busy, data_valid, start, captured, startcapture;

    wire [11:0] adc_data, read_data;
    wire [8:0] read_addr;

    output wire adc_cs_n;
    output wire adc_saddr;
    output wire adc_sclk;
    input wire adc_sdat;

    sampler SAMPLER (
        .CLOCK_50 (clk),
        .resetn (resetn),
        .busy (busy),
        .start (start)
    );

    adc_controller ADC (
        .CLOCK_50 (clk),
        .resetn (resetn),
        .start (start),
        .adc_cs_n (adc_cs_n),
        .adc_saddr (adc_saddr),
        .adc_sclk (adc_sclk),
        .adc_sdat (adc_sdat),
        .adc_data (adc_data),
        .data_valid (data_valid),
        .busy (busy)
    );

    memory MEMORY (
        .CLOCK_50 (clk),
        .resetn (resetn),
        .adc_data (adc_data),
        .data_valid (data_valid),
        .read_addr (read_addr),
        .read_data (read_data),
        .captured (captured),
        .startcapture (startcapture)
    );

    waveform_renderer RENDERER (
        .CLOCK_50 (clk),
        .resetn (resetn),
        .captured (captured),
        .startcapture (startcapture),
        .read_addr (read_addr),
        .read_data (read_data),
        .x (xpixel),
        .y (ypixel),
        .colour (colour),
        .plot (plot)
		.grant (grant)
		.req (req)
    );

endmodule

module sampler #(
	// samples at 10 khz
	parameter SAMPLE_PERIOD = 5000)
	(
	input CLOCK_50,
	input resetn,
	input busy,
	
	output reg start );

	reg [31:0] sample_count;
	
	always @(posedge CLOCK_50) begin
	
		if (!resetn) begin
			sample_count <= 32'b0;
			start <= 1'b0;
		end
		
		else begin
		
			start <= 1'b0;
			
			if (sample_count == SAMPLE_PERIOD - 1) begin // essentially a counter for sampling freq
			
				if (!busy) begin
					sample_count <= 32'd0;
					start <= 1'b1;
				end
				
			end
			
			else sample_count <= sample_count + 1'b1;
			
		end
	
	end

endmodule

module adc_controller #(
	// 1/2 period = 20ns x  25 = 0.5us
	parameter HALF_PERIOD = 25, 
	// select channel 0 of 8
	parameter [2:0] ADC_CHANNEL = 3'd0 )
	(
	input CLOCK_50,
	input resetn,
	input start,

	output reg adc_cs_n, // chip select
	output reg adc_saddr, // serial address
	output reg adc_sclk, // serial clock

	input adc_sdat, // serial data

	output reg [11:0] adc_data, // dout 12 bits
	output reg data_valid,
	output reg busy );
	
	// FSM states
	
	localparam IDLE = 2'b00;
	localparam TRANSFER = 2'b01;
	
	reg [1:0] state; // state register represented by 2 bits for 4 states
	
	reg [15:0] clk_div;
	reg [3:0] clk_count; // counts # of clk cycles
	reg [11:0] sr;
	
	// clock divider
	
	wire adc_clk;
	assign adc_clk = (clk_div == HALF_PERIOD - 1);
	
	always @(posedge CLOCK_50) begin
		if (!resetn)
			clk_div <= 16'd0;
		else if (adc_clk)
			clk_div <= 16'd0; // reset count when ADC clock occurs (24 count)
		else
			clk_div <= clk_div + 1'b1; // keep on adding until half period
	end
	
	// FSM
	
	always @(posedge CLOCK_50) begin
	
		// active low reset
		if (!resetn) begin
			state <= IDLE; // idle at start
			adc_cs_n <= 1'b1; // chip select is active low so start at 1
			adc_saddr <= 1'b0; // no address yet
			adc_sclk <= 1'b1; // so clock high
			adc_data <= 12'd0; // no data yet
			data_valid <= 1'b0; // data not yet validated
			busy <= 1'b0; // not busy
			clk_count <= 4'd0;
			sr <= 12'd0; // need to shift 12 bits later
		end
		
		// not reset
		else begin
		
			data_valid <= 1'b0;
			
			case (state)
						
				
				// IDLE
					
					IDLE: begin
						adc_cs_n <= 1'b1;
						adc_sclk <= 1'b1;
						busy <= 1'b0;
						
						if (start) begin
							adc_cs_n <= 1'b0; // select chip! (to activate ADC)
							adc_sclk <= 1'b1; // start low
							adc_saddr <= 1'b0; // according to timing diagram, 2 cycles (0, 1) are idle
							clk_count <= 4'd0;
							sr <= 12'd0;
							busy <= 1'b1;
							state <= TRANSFER; // once sampling starts, setup begins
						end
					end
					
				// TRANSFER
				
					TRANSFER: begin
						// genereate serial clock
						if (adc_clk) begin
							// since adc_clk is running at 1Mhz and adc_sclk is clocked by 2 toggles, sclk is at 500 khz
							if (adc_sclk == 1'b1) begin
								adc_sclk <= 1'b0; // create a rising edge for SPI clock
								// send address
								case (clk_count)
									 4'd2: adc_saddr <= ADC_CHANNEL[2];
									 4'd3: adc_saddr <= ADC_CHANNEL[1];
									 4'd4: adc_saddr <= ADC_CHANNEL[0];
									 default: adc_saddr <= 1'b0;
								endcase
							end
									 
							else begin
								adc_sclk <= 1'b1; // else create falling edge
				
								// shift register
								// only starts at d3 since first 3 clock cycles are used for channel selection
								// sr will store adc dout w/ lowest bit first
								if (clk_count >= 4'd4) 
									sr <= {sr[10:0], adc_sdat};
								// on the final bit, make adc_data into its reversed bits and data is valid
								if (clk_count == 4'd15) begin
									adc_data <= {sr[10:0], adc_sdat};
									data_valid <= 1'b1;
									adc_cs_n <= 1'b1;
									busy <= 1'b0;
									state <= IDLE;
								end
								
								else 
									clk_count <= clk_count + 1'b1;
							end
						end
					end
				endcase
			end
	end
endmodule

module memory (
	input CLOCK_50,
	input resetn,
	
	input [11:0] adc_data,
	input data_valid,
    input startcapture,
	
	input [8:0] read_addr, // 10 bits to store up to 640 samples
	
	output reg captured,
    output reg [11:0] read_data );
	
	// memory is in sample units
	// each sample contains 12 bits
	reg [11:0] memory [0:319];
	reg [9:0] write_addr;
	
	always @(posedge CLOCK_50) begin
		
		if (!resetn || startcapture) begin
			write_addr <= 10'b0;
			captured <=  1'b0;
		end
		
		else begin
		
			// memory can only start writing if it is NOT DONE (captured) and ADC is done sampling
			if (data_valid && !captured) begin
			
				// memory stores the 12 bit value
				memory[write_addr] <= adc_data;
				
				// capture once 640 samples
				if (write_addr == 10'd319) captured <= 1'b1;
				else write_addr <= write_addr + 1'b1;
			end
		end
	end
	
	// set output (read_data) to the 320 samples stored at the location requested (read_addr)
	always @(posedge CLOCK_50)
        read_data <= memory[read_addr];
	
endmodule

module waveform_renderer (

	input grant,
	output req,

    input CLOCK_50,
    input resetn,

    input captured,
    output startcapture,

    output [8:0] read_addr,
    input  [11:0] read_data,

    output [8:0] x,
    output [7:0] y,
    output [8:0] colour,
    output plot );

    localparam S_IDLE  = 3'd0, // waiting for capture
               S_CLEAR = 3'd1, // black out screen
               S_ADDR  = 3'd2, // idle for 1 clk
               S_LATCH = 3'd3, // fill in vertical gap between levels
               S_DRAW  = 3'd4, // draw horizontal lines
               S_DONE  = 3'd5; // done drawing

    reg [2:0] state;
    reg [8:0] col;
    reg [7:0] row;
    reg [7:0] prev_y, cur_y, hi;

	wire drawing = (state == S_CLEAR) || (state == S_DRAW);
    assign req  = (state == S_CLEAR) || (state == S_ADDR) || (state == S_LATCH) || (state == S_DRAW);
    assign plot = drawing && gnt;

    wire [19:0] prod = read_data * 8'd119;
    wire [7:0]  trace_y = 8'd119 - prod[19:12];

    wire [7:0] lo_next = (col == 9'd0) ? trace_y : (prev_y < trace_y ? prev_y : trace_y);
    wire [7:0] hi_next = (col == 9'd0) ? trace_y : (prev_y < trace_y ? trace_y : prev_y);

    assign read_addr = col;
    assign x = col;
    assign y = row;
    assign plot = (state == S_CLEAR) || (state == S_DRAW);
    assign colour = (state == S_CLEAR) ? 9'b000_000_000 : 9'b000_111_000; // green on black
    assign startcapture = (state == S_DONE);

    always @(posedge CLOCK_50) begin
        if (!resetn) begin
            state  <= S_IDLE;
            col    <= 9'd0; // column
            row    <= 8'd0; // row
            prev_y <= 8'd0; // previous y value
            cur_y  <= 8'd0; // current y value
            hi     <= 8'd0;
        end
        else begin
            case (state)
                S_IDLE: begin
                    col <= 9'd0;
                    row <= 8'd0;
                    if (captured) state <= S_CLEAR;
                end

                S_CLEAR: begin
					if (grant) begin
						if (col == 9'd319) begin
							col <= 9'd0;
							if (row == 8'd239) begin
								row   <= 8'd0;
								state <= S_ADDR;
							end
							else row <= row + 1'b1;
						end
						else col <= col + 1'b1;
					end
                end

                S_ADDR: state <= S_LATCH;   // read_addr = col; read_data valid next clock

                S_LATCH: begin
                    cur_y <= trace_y;
                    row   <= lo_next;
                    hi    <= hi_next;
                    state <= S_DRAW;
                end

                S_DRAW: begin
					if (grant) begin
						if (row == hi) begin
							prev_y <= cur_y;
							if (col == 9'd319) state <= S_DONE;
							else begin
								col   <= col + 1'b1;
								state <= S_ADDR;
							end
						end
						else row <= row + 1'b1;
					end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule

/*
module trigger (
	input [2:0] lvl
	input [2:0] pos
	input slope
	input on

	output 
)


endmodule
*/