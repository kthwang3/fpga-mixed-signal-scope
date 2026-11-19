# Timing constraints for the DE1-SoC scope project.
# Tells Quartus the board clock is 50 MHz (20 ns period) so it can check
# that every path in the design is fast enough.

create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]

# The VGA adapter's PLL makes the 25 MHz pixel clock; derive it automatically.
derive_pll_clocks
derive_clock_uncertainty
