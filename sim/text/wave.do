onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -label test     -radix unsigned /testbench/test
add wave -noupdate -label clk      -radix binary   /testbench/clk
add wave -noupdate -label resetn   -radix binary   /testbench/resetn
add wave -noupdate -divider byte_log
add wave -noupdate -label in_byte  -radix ascii    /testbench/in_byte
add wave -noupdate -label in_valid -radix binary   /testbench/in_valid
add wave -noupdate -label rd_idx   -radix unsigned /testbench/rd_idx
add wave -noupdate -label rd_char  -radix ascii    /testbench/rd_char
add wave -noupdate -divider font_rom
add wave -noupdate -label char     -radix ascii    /testbench/char
add wave -noupdate -label row      -radix unsigned /testbench/row
add wave -noupdate -label bits     -radix binary   /testbench/bits
add wave -noupdate -divider checker
add wave -noupdate -label errors   -radix unsigned /testbench/errors
TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 160
configure wave -valuecolwidth 80
configure wave -timelineunits ns
update
