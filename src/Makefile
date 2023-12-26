CXX_FLAGS = -O3
ARCH_FLAGS = --target=riscv32-none-eabi -march=rv32im
# ARCH_FLAGS = --with-arch=rv32i 

all: build/test.dhex

build/.keeper:
	mkdir  -p build
	touch build/.keeper

build/test.o: test.cpp Makefile build/.keeper
	# rv32 in clang is rv32i, see https://lvm.org/docs/RISCVUsage.html
	clang++ $(CXX_FLAGS) -mno-relax -nostdlib $(ARCH_FLAGS) -c test.cpp -o build/test.o
	#for c files: clang -mno-relax -nostdlib $(ARCH_FLAGS) -c test.c -o build/test.o

build/test.asm: test.cpp Makefile build/.keeper
	clang++ $(CXX_FLAGS) -mno-relax -nostdlib $(ARCH_FLAGS) -c test.cpp -o build/test.asm -S

build/test.elf: build/test.o link.txt
	# a more correct way of doing this probably exist!!
	ld.lld --script link.txt -o build/test.elf build/test.o

build/test.hex: build/test.elf
	# convert to intel hex format: https://en.wikipedia.org/wiki/Intel_HEX
	llvm-objcopy -O ihex build/test.elf build/test.hex

objdump: build/test.elf
	llvm-objdump -DS build/test.elf

asm: build/test.asm

build/test.dhex: build/test.hex
	./hexdump.py -i build/test.hex -o build/test.dhex

clean:
	rm -rf build/

.PHONY: clean all asm
