
all: obj_dir/Vram

obj_dir/Vram: main.cpp ../../ram.sv
	verilator --trace --cc --exe --build -j 0 -Wall main.cpp ../../ram.sv

test: obj_dir/Vram
	./obj_dir/Vram

wave: test
	gtkwave simx.vcd &

clean:
	rm -rf obj_dir/

.PHONY: clean all test
