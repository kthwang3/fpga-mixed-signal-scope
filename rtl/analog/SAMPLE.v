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
		