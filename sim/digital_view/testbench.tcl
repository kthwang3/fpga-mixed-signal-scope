# stop any simulation that is currently running
quit -sim

# create the default "work" library
vlib work;

# compile the design under test
vlog ../../rtl/digital/digital_view.v
# compile the testbench
vlog testbench.v
# start the simulator, including some libraries that may be needed
vsim work.testbench -Lf 220model -Lf altera_mf_ver -Lf verilog
# show waveforms specified in wave.do
do wave.do
# run until the testbench calls $stop (after 2 frames, about 1.5 ms)
run -all
