module scope_core (clk, resetn, SW, KEY, gpio_in, LEDR, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, x, y, colour, write, test_wave, adc_cs_n, adc_saddr, adc_sdat, adc_sclk);
    parameter DV_DELAY = 1666666;   // digital_view redraw delay; desim/top.v overrides to 1000
    parameter CAP_N    = 650;       // gpio_capture: clocks per sample (13 us); desim/top.v overrides
    parameter WAVE_BIT = 15;        // which counter bit is the test square wave; desim/top.v overrides
    parameter FONT_FILE = "font8x8.hex"; // path to the font, relative to where the tool runs; wrappers override

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

    output wire adc_cs_n, adc_saddr, adc_sclk;
    input wire adc_sdat;

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

    wire [7:0] tx_data;
    wire tx_send, tx_busy, uart_line;

    msg_seq MSG(
        .clk (clk),
        .resetn (resetn),
        .busy (tx_busy),
        .data (tx_data),
        .send (tx_send)
    );

    uart_tx UTX(
        .clk(clk),
        .resetn (resetn),
        .data(tx_data),
        .send(tx_send),
        .tx (uart_line),
        .busy(tx_busy)
    );


    //CH0 source: the switch selects which source. SW[1]=1 = UART from FPGA, SW[0]=1 -> internal test wave, SW[0]=0 -> real GPIO pin
    // 2 to 1 mux as a ternary operator
    wire ch0 = SW[1] ? uart_line : (SW[0] ? test_wave : gpio_in[0]);

    wire [7:0] rx_byte;
    wire rx_valid;
    uart_rx URX (
        .clk (clk),
        .resetn (resetn),
        .rx (ch0),
        .data (rx_byte),
        .valid (rx_valid)
    );

    wire [5:0] text_idx;
    wire [2:0] text_row;
    wire [7:0] log_char, font_bits;

    byte_log LOG (
        .clk(clk), 
        .resetn(resetn), 
        .in_byte(rx_byte), 
        .in_valid(rx_valid),
        .rd_idx(text_idx), 
        .rd_char(log_char)
    );
    font_rom #(.FONT_FILE(FONT_FILE)) FONT (
        .char(log_char[6:0]), 
        .row(text_row), 
        .bits(font_bits)
    );

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

    wire dv_req, av_req; //requests
    wire dv_grant, av_grant; //grants
    //digital view and analog has its own set of wires
    wire [8:0] dv_x, av_x;
    wire [7:0] dv_y, av_y;
    wire [8:0] dv_colour, av_colour;
    wire dv_plot, av_plot;

    digital_view #(.DELAY(DV_DELAY)) d1 (
        .clk           (clk),
        .resetn        (resetn),
        .grant         (dv_grant),
        .req           (dv_req),
        .sample        (rd_data),
        .ready         (cap_full),
        .x             (dv_x),
        .y             (dv_y),
        .colour        (dv_colour),
        .plot          (dv_plot),
        .rd_addr       (rd_addr),
        .start_capture (cap_start),
        .text_idx (text_idx),
        .text_row(text_row),
        .font_bits(font_bits)
    );

    analog_view d2 (
        .clk (clk),
        .resetn (resetn),
        .grant (av_grant),
        .xpixel (av_x),
        .ypixel (av_y),
        .colour (av_colour),
        .plot (av_plot),
        .req (av_req),
        .adc_cs_n (adc_cs_n),
        .adc_saddr (adc_saddr),
        .adc_sclk (adc_sclk),
        .adc_sdat (adc_sdat),
        .lvl (SW[9:7]),
        .pos (SW[6:4]),
        .mode (SW[3:2]),
        .slope (KEY[2]),
        .arm (KEY[1])
    );
    arbiter ARB (
        .clk (clk),
        .resetn (resetn),
        .r ({av_req, dv_req}), // r[1] == analog, r[0] == digital
        .g ({av_grant, dv_grant})
    );

    wire use_analog = av_grant;   // SW[9] = temporary override, see below
    assign x      = use_analog ? av_x      : dv_x;
    assign y      = use_analog ? av_y      : dv_y;
    assign colour = use_analog ? av_colour : dv_colour;
    assign write  = use_analog ? av_plot   : dv_plot;

    /*
    //TEMPORARY: UNTIL WE HAVE ARBITER DOWN = DIGITAL HALF, UP = ANALOG
    assign x      = SW[9] ? av_x      : dv_x;
    assign y      = SW[9] ? av_y      : dv_y;
    assign colour = SW[9] ? av_colour : dv_colour;
    assign write  = SW[9] ? av_plot   : dv_plot;
    */
endmodule
