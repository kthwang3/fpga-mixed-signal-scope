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