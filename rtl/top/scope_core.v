module scope_core (clk, resetn, SW, KEY, gpio_in, LEDR, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, x, y, colour, write, test_wave);
    parameter DV_DELAY = 1666666;   // digital_view redraw delay; desim/top.v overrides to 1000
    parameter CAP_N    = 650;       // gpio_capture: clocks per sample (13 us); desim/top.v overrides
    parameter WAVE_BIT = 15;        // which counter bit is the test square wave; desim/top.v overrides

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
    output wire        test_wave;  // built-in square wave, sent out a GPIO pin by scope_top

    assign HEX0 = 7'b1111111;
    assign HEX1 = 7'b1111111;
    assign HEX2 = 7'b1111111;
    assign HEX3 = 7'b1111111;
    assign HEX4 = 7'b1111111;
    assign HEX5 = 7'b1111111;

    // test signal: square wave from a free-running counter
    // board: bit 15 flips every 2^15 clocks = 0.66 ms -> period 1.3 ms, ~3 periods on screen
    reg [15:0] wave_cnt;
    always @(posedge clk)
        if (!resetn) wave_cnt <= 0;
        else wave_cnt <= wave_cnt + 1;
    assign test_wave = wave_cnt[WAVE_BIT];

    //CH0 source: the switch selects which source. SW[0]=1 -> internal test wave, SW[0]=0 -> real GPIO pin
    // 2 to 1 mux as a ternary operator
    wire ch0 = SW[0] ? test_wave : gpio_in[0];

    assign LEDR[0]   = ch0;            // shows what CH0 is seeing (blinks fast = signal present)
    assign LEDR[9:1] = 9'b0;

    // digital channel 0: capture RAM + drawing
    wire [8:0] rd_addr;
    wire       rd_data;
    wire       cap_full;
    wire       cap_start;

    gpio_capture #(.N(CAP_N)) cap0 (
        .clk     (clk),
        .resetn  (resetn),
        .start   (cap_start),
        .gpio_in (ch0),
        .rd_addr (rd_addr),
        .rd_data (rd_data),
        .full    (cap_full)
    );

    wire req;

    digital_view #(.DELAY(DV_DELAY)) d1 (
        .clk           (clk),
        .resetn        (resetn),
        .grant         (req),          // no arbiter yet: granted as soon as it asks
        .sample        (rd_data),
        .ready         (cap_full),
        .x             (x),
        .y             (y),
        .colour        (colour),
        .plot          (write),
        .req           (req),
        .rd_addr       (rd_addr),
        .start_capture (cap_start)
    );

endmodule
