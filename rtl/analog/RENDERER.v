
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
	assign sample_address = (pixel_x > 10'd639) ? 10'd639 : pixel_x;
	
	// map every possible of sampled to the max height of the vga
	assign scaled_value = sample_value * 9'd479;
	assign trace_y = 10'd479 - (scaled_value / 12'd4095);

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
		(pixel_x < 10'd640) &&
		(pixel_y < 10'd480) &&
		(pixel_difference <= 10'd2);

	// assign waverform colours
	// when waveform_pixel is true, screen is green
	// green on black waveform
	assign VGA_R = waveform_pixel ? 8'h00 : 8'h00;
	assign VGA_G = waveform_pixel ? 8'hFF : 8'h00;
	assign VGA_B = waveform_pixel ? 8'h00 : 8'h00;

endmodule
