
all: obj_dir/Vrv32_core

obj_dir/Vrv32_core: main.cpp ../../rv32_core.sv
	verilator --trace --cc --exe --build -j 0 -Wall main.cpp ../../rv32_core.sv -I../../

test: obj_dir/Vrv32_core
	./obj_dir/Vrv32_core

wave: test
	gtkwave simx.vcd &

clean:
	rm -rf obj_dir/

.PHONY: clean all test
