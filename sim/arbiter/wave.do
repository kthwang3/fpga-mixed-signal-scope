onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -label test   -radix unsigned /testbench/test
add wave -noupdate -label clk    -radix binary   /testbench/clk
add wave -noupdate -label resetn -radix binary   /testbench/resetn
add wave -noupdate -divider requests
add wave -noupdate -label {r[0] digital} -radix binary {/testbench/r[0]}
add wave -noupdate -label {r[1] analog}  -radix binary {/testbench/r[1]}
add wave -noupdate -divider arbiter
add wave -noupdate -label {state y (0 IDLE, 1 GNT0, 2 GNT1)} -radix unsigned /testbench/DUT/y
add wave -noupdate -label {g[0] digital} -radix binary {/testbench/g[0]}
add wave -noupdate -label {g[1] analog}  -radix binary {/testbench/g[1]}
add wave -noupdate -divider checker
add wave -noupdate -label errors -radix unsigned /testbench/errors
TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 220
configure wave -valuecolwidth 60
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {700 ns}
