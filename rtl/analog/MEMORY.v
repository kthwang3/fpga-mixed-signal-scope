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
	// total 7680 bits
	reg [11:0] memory [0:639];
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
				if (write_addr == 10'd639) captured <= 1'b1;
				else write_addr <= write_addr + 1'b1;
			end
		end
	end
	
	// set output (read_data) to the 640 samples stored at the location requested (read_addr)
	assign read_data = memory[read_addr];
	
endmodule
