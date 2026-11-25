quit -sim
vlib work;
vlog ../../rtl/digital/uart_tx.v
vlog ../../rtl/digital/uart_rx.v
vlog testbench.v
vsim work.testbench -Lf 220model -Lf altera_mf_ver -Lf verilog
do wave.do
run -all
wave zoom range 0ns 8000ns
