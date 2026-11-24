quit -sim
vlib work;
vlog ../../rtl/top/arbiter.v
vlog testbench.v
vsim work.testbench -Lf 220model -Lf altera_mf_ver -Lf verilog
do wave.do
run -all
wave zoom range 0ns 700ns
