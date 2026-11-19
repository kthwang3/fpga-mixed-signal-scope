onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -label clk    -radix binary   /testbench/clk
add wave -noupdate -label resetn -radix binary   /testbench/resetn
add wave -noupdate -divider FSM
add wave -noupdate -label {state y_Q (DONE,SWEEP,REQ,WAIT)} -radix binary /testbench/DUT/y_Q
add wave -noupdate -label delay_cnt -radix unsigned /testbench/DUT/delay_cnt
add wave -noupdate -label req    -radix binary   /testbench/req
add wave -noupdate -label grant  -radix binary   /testbench/grant
add wave -noupdate -divider pixels
add wave -noupdate -label plot   -radix binary   /testbench/plot
add wave -noupdate -label x      -radix unsigned /testbench/x
add wave -noupdate -label y      -radix unsigned /testbench/y
add wave -noupdate -label colour -radix binary   /testbench/colour
add wave -noupdate -label on_trace -radix binary /testbench/DUT/on_trace
add wave -noupdate -divider checker
add wave -noupdate -label ref_colour -radix binary  /testbench/ref_colour
add wave -noupdate -label errors -radix unsigned /testbench/errors
add wave -noupdate -label pixels -radix unsigned /testbench/pixels
TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 200
configure wave -valuecolwidth 80
configure wave -timelineunits us
update
WaveRestoreZoom {0 ns} {1 us}
