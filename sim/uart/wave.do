onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -label test   -radix unsigned /testbench/test
add wave -noupdate -label clk    -radix binary   /testbench/clk
add wave -noupdate -label resetn -radix binary   /testbench/resetn
add wave -noupdate -divider uart_tx
add wave -noupdate -label data     -radix hexadecimal /testbench/data
add wave -noupdate -label send     -radix binary      /testbench/send
add wave -noupdate -label {tx state} -radix unsigned  /testbench/TX/state
add wave -noupdate -label baud_cnt -radix unsigned    /testbench/TX/baud_cnt
add wave -noupdate -label bit_cnt  -radix unsigned    /testbench/TX/bit_cnt
add wave -noupdate -label busy     -radix binary      /testbench/busy
add wave -noupdate -label tx       -radix binary      /testbench/tx
add wave -noupdate -divider uart_rx
add wave -noupdate -label {rx state (0 IDLE 1 START 2 DATA 3 STOP)} -radix unsigned /testbench/RX/state
add wave -noupdate -label half_done -radix binary     /testbench/RX/half_done
add wave -noupdate -label bit_done  -radix binary     /testbench/RX/bit_done
add wave -noupdate -label rx_data   -radix hexadecimal /testbench/rx_data
add wave -noupdate -label rx_valid  -radix binary     /testbench/rx_valid
add wave -noupdate -divider checker
add wave -noupdate -label errors -radix unsigned /testbench/errors
TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 260
configure wave -valuecolwidth 60
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {8000 ns}
