
all: obj_dir/Vtop

obj_dir/Vtop: main.cpp ../../top.sv ../../rv32_core.sv ../../ram.sv
	verilator --trace --cc --exe --build -j 0 -Wall main.cpp ../../top.sv -I../../

test: obj_dir/Vtop
	./obj_dir/Vtop

wave: test
	gtkwave simx.vcd &

clean:
	rm -rf obj_dir/

.PHONY: clean all test
