onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -label test    -radix unsigned /testbench/test
add wave -noupdate -label clk     -radix binary   /testbench/clk
add wave -noupdate -label resetn  -radix binary   /testbench/resetn
add wave -noupdate -divider synchronizer
add wave -noupdate -label gpio_in -radix binary   /testbench/gpio_in
add wave -noupdate -label sync1   -radix binary   /testbench/DUT/sync1
add wave -noupdate -label sync2   -radix binary   /testbench/DUT/sync2
add wave -noupdate -divider decimator
add wave -noupdate -label dec_cnt -radix unsigned /testbench/DUT/dec_cnt
add wave -noupdate -label tick    -radix binary   /testbench/DUT/tick
add wave -noupdate -divider write
add wave -noupdate -label wr_addr -radix unsigned /testbench/DUT/wr_addr
add wave -noupdate -label full    -radix binary   /testbench/full
add wave -noupdate -divider read
add wave -noupdate -label rd_addr -radix unsigned /testbench/rd_addr
add wave -noupdate -label rd_data -radix binary   /testbench/rd_data
add wave -noupdate -divider checker
add wave -noupdate -label ref_k   -radix unsigned /testbench/ref_k
add wave -noupdate -label errors  -radix unsigned /testbench/errors
TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 150
configure wave -valuecolwidth 80
configure wave -timelineunits us
update
WaveRestoreZoom {0 ns} {400 ns}
