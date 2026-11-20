module analog_view (clk, resetn, start, grant, xpixel, ypixel, colour, plot, req, adc_cs_n, adc_saddr, adc_sclk, adc_sdat, adc_data);

    input wire clk;
    input wire resetn;
    input wire start;

    // arbiter
    input wire grant;
    output wire req;

    // vga
    output reg [8:0] xpixel;
    output reg [7:0] ypixel;
    output wire [8:0] colour;
    output wire plot;
    
    wire busy;
    assign busy = 1'b0;

    wire data_valid;
    assign data_valid = 1'b0;

    wire reg [11:0] adc_data;

    read_addr
    read_data
    captured
    

    sampler SAMPLER (
        .CLOCK_50 (clk)
        .resetn (resetn)
        .busy (busy)
    );

    adc_controller ADC (
        .CLOCK_50 (clk)
        .resetn (resetn)
        .start (start)
        .adc_cs_n (adc_cs_n)
        .adc_saddr (adc_saddr)
        .adc_sclk (adc_sclk)
        .adc_sdat (adc_sdat)
        .adc_data (adc_data)
        .data_valid (data_valid)
        .busy (busy)
    );

    memory MEMORY (
        .CLOCK_50 (clk)
        .resetn (resetn)
        .adc_data (adc_data)
        .data_valid (data_valid)
        .read_addr (read_addr)
        .read_data (read_data)
        .captured (captured)
    );

    waveform_renderer RENDERER (
        .pixel_x (xpixel)
        .pixel_y (ypixel)
        .video_on (video_on)
        .sample_address (read_addr)
        .sample_value (sample_value)
        .VGA_R (VGA_R)
        .VGA_G (VGA_G)
        .VGA_B (VGA_B)
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
	parameter HALF_PERIOD = 25; 
	// select channel 0 of 8
	parameter [2:0] ADC_CHANNEL = 3'd0 );
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
	output reg busy,
	
	// FSM states
	
	localparam IDLE = 2'b00;
	localparam TRANSFER = 2'b01 );
	
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
						adc_sclk <= 1'b0;
						busy <= 1'b0;
						
						if (start) begin
							adc_cs_n <= 1'b0; // select chip! (to activate ADC)
							adc_sclk <= 1'b0; // start low
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
								if (clk_count == 4'd14) begin
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
	
	input [9:0] read_addr, // 10 bits to store up to 640 samples
	output [11:0] read_data,
	
	output reg captured );
	
	// memory is in sample units
	// each sample contains 12 bits
	reg [11:0] memory [0:319];
	reg [9:0] write_addr;
	
	always @(posedge CLOCK_50) begin
		
		if (!resetn) begin
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
	assign read_data <= memory[read_addr];
	
endmodule

module waveform_renderer (

	// vga controller will tell the renderer where it is
	input [9:0] pixel_x,
	input [9:0] pixel_y,
	input video_on,

	// tells the memory where it wants the value
	// then receives 12-bit value for voltage
	output [9:0] sample_address,
	input [11:0] sample_value,

	output wire [7:0] VGA_R,
	output wire [7:0] VGA_G,
	output wire [7:0] VGA_B );

	// scale management
	// convert 4096 resolution to the vga 480 pixels
	wire [20:0] scaled_value;
	wire [9:0] trace_y;
	wire [9:0] pixel_difference;

	wire waveform_pixel;

	// assign sample_address based on x coord
	assign sample_address = (pixel_x > 10'd319) ? 10'd319 : pixel_x;
	
	// map every possible of sampled to the max height of the vga
	assign scaled_value = sample_value * 9'd119;
	assign trace_y = 10'd119 - (scaled_value / 12'd4095);

	// distance between current point and next
	assign pixel_difference =
        (pixel_y >= trace_y) ?
        (pixel_y - trace_y) :
        (trace_y - pixel_y);

	// requirements to draw
	// video_on
	// pixels within frame
	// 5 pixel waveform
	assign waveform_pixel =
		video_on && 
		(pixel_x < 10'd320) &&
		(pixel_y < 10'd120) &&
		(pixel_difference <= 10'd2);

	// assign waverform colours
	// when waveform_pixel is true, screen is green
	// green on black waveform
	assign VGA_R = waveform_pixel ? 8'h00 : 8'h00;
	assign VGA_G = waveform_pixel ? 8'hFF : 8'h00;
	assign VGA_B = waveform_pixel ? 8'h00 : 8'h00;

endmodule