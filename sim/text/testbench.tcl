quit -sim
vlib work;
vlog ../../rtl/digital/byte_log.v
vlog ../../rtl/digital/font_rom.v
vlog testbench.v
vsim work.testbench -Lf 220model -Lf altera_mf_ver -Lf verilog
do wave.do
run -all
wave zoom full
