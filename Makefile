# Compiler flags
CFLAGS := -Wall -Wextra -O3 -m64 -D'uint64_t=unsigned long long'

# Bootstrap selfie.c into selfie executable
selfie: selfie.c
	$(CC) $(CFLAGS) $< -o $@

# 32-bit compiler flags
32-BIT-CFLAGS := -Wall -Wextra -Wno-builtin-declaration-mismatch -O3 -m32 -D'uint64_t=unsigned long'

# Bootstrap selfie.c into 32-bit selfie executable, requires 32-bit compiler support
selfie-32: selfie.c
	$(CC) $(32-BIT-CFLAGS) $< -o $@

# Permission flags for selfie-generated executables
XPERMISSIONS := +rx,u+w

# Compile *.c including selfie.c into RISC-U *.m executable
%.m: %.c selfie
	./selfie -c $< -o $@
	chmod $(XPERMISSIONS) $@

# Permission flags for selfie-generated text files
RPERMISSIONS := +r,u+w

# Compile *.c including selfie.c into RISC-U *.s assembly
%.s: %.c selfie
	./selfie -c $< -s $@
	chmod $(RPERMISSIONS) $@

# Generate selfie library as selfie.h
selfie.h: selfie.c
	sed 's/main(/selfie_main(/' selfie.c > selfie.h

# Consider these targets as targets, not files
.PHONY: self self-self quine escape debug replay os vm min mob gib gclib giblib gclibtest sat mon smt mod btor2 all

# Run everything that only requires standard tools
all: self self-self quine escape debug replay os vm min mob gib gclib giblib gclibtest sat mon smt mod btor2

# Self-compile selfie
self: selfie
	./selfie -c selfie.c

# Self-self-compile selfie and check fixed point of self-compilation
self-self: selfie
	./selfie -c selfie.c -o selfie1.m -s selfie1.s -m 2 -c selfie.c -o selfie2.m -s selfie2.s
	chmod $(XPERMISSIONS) selfie1.m selfie2.m
	chmod $(RPERMISSIONS) selfie1.s selfie2.s
	diff -q selfie1.m selfie2.m
	diff -q selfie1.s selfie2.s

# Compile and run quine and compare its output to itself
quine: selfie selfie.h
	./selfie -c selfie.h examples/quine.c -m 1 | sed '/selfie/d' | diff --strip-trailing-cr examples/quine.c -

# Demonstrate available escape sequences
escape: selfie
	./selfie -c examples/escape.c -m 1

# Run debugger
debug: selfie
	./selfie -c examples/pointer.c -d 1

# Run replay engine
replay: selfie
	./selfie -c examples/division-by-zero.c -r 1

# Run emulator on emulator
os: selfie.m
	./selfie -l selfie.m -m 2 -l selfie.m -m 1

# Self-compile on two virtual machines
vm: selfie.m selfie.s
	./selfie -l selfie.m -m 3 -l selfie.m -y 3 -l selfie.m -y 2 -c selfie.c -o selfie-vm.m -s selfie-vm.s
	chmod $(XPERMISSIONS) selfie-vm.m
	chmod $(RPERMISSIONS) selfie-vm.s
	diff -q selfie.m selfie-vm.m
	diff -q selfie.s selfie-vm.s

# Self-compile on two virtual machines on fully mapped virtual memory
min: selfie.m selfie.s
	./selfie -l selfie.m -min 15 -l selfie.m -y 3 -l selfie.m -y 2 -c selfie.c -o selfie-min.m -s selfie-min.s
	chmod $(XPERMISSIONS) selfie-min.m
	chmod $(RPERMISSIONS) selfie-min.s
	diff -q selfie.m selfie-min.m
	diff -q selfie.s selfie-min.s

# Run mobster, the emulator without pager
mob: selfie
	./selfie -c -mob 1

# Self-compile with conservative garbage collector in mipster
gib: selfie selfie.m selfie.s
	./selfie -c selfie.c -gc -m 1 -c selfie.c -o selfie-gib.m -s selfie-gib.s
	chmod $(XPERMISSIONS) selfie-gib.m
	chmod $(RPERMISSIONS) selfie-gib.s
	diff -q selfie.m selfie-gib.m
	diff -q selfie.s selfie-gib.s

# Self-compile with conservative garbage collector in hypster
hyb: selfie selfie.m selfie.s
	./selfie -l selfie.m -m 3 -l selfie.m -gc -y 1 -c selfie.c -o selfie-hyb.m -s selfie-hyb.s
	chmod $(XPERMISSIONS) selfie-hyb.m
	chmod $(RPERMISSIONS) selfie-hyb.s
	diff -q selfie.m selfie-hyb.m
	diff -q selfie.s selfie-hyb.s

# Self-compile with conservative garbage collector as library
gclib: selfie selfie.h selfie.m selfie.s
	./selfie -gc -c selfie.h tools/gc.c -m 3 -c selfie.c -o selfie-gclib.m -s selfie-gclib.s
	chmod $(XPERMISSIONS) selfie-gclib.m
	chmod $(RPERMISSIONS) selfie-gclib.s
	diff -q selfie.m selfie-gclib.m
	diff -q selfie.s selfie-gclib.s

# Self-compile with self-collecting garbage collectors
giblib: selfie selfie.h selfie.m selfie.s
	./selfie -gc -c selfie.h tools/gc.c -gc -m 3 -nr -c selfie.c -o selfie-giblib.m -s selfie-giblib.s
	chmod $(XPERMISSIONS) selfie-giblib.m
	chmod $(RPERMISSIONS) selfie-giblib.s
	diff -q selfie.m selfie-giblib.m
	diff -q selfie.s selfie-giblib.s

# Test garbage collector as library
gclibtest: selfie selfie.h examples/garbage_collector_test.c
	./selfie -gc -c selfie.h examples/garbage_collector_test.c -m 1

# Compile babysat.c with selfie.h as library into babysat executable
babysat: tools/babysat.c selfie.h
	$(CC) $(CFLAGS) --include selfie.h $< -o $@

# Run babysat, the naive SAT solver, natively and as RISC-U executable
sat: babysat selfie selfie.h
	./babysat examples/rivest.cnf
	./selfie -c selfie.h tools/babysat.c -m 1 examples/rivest.cnf

# Compile monster.c with selfie.h as library into monster executable
monster: tools/monster.c selfie.h
	$(CC) $(CFLAGS) --include selfie.h $< -o $@

# Run monster, the symbolic execution engine, natively and as RISC-U executable
mon: monster selfie.h selfie
	./monster
	./selfie -c selfie.h tools/monster.c -m 1

# Prevent make from deleting intermediate target monster
.SECONDARY: monster

# Translate *.c including selfie.c into SMT-LIB model
%-35.smt: %-35.c monster
	./monster -c $< - 0 35 --merge-enabled
	chmod $(RPERMISSIONS) $@
%-10.smt: %-10.c monster
	./monster -c $< - 0 10 --merge-enabled
	chmod $(RPERMISSIONS) $@

# Gather symbolic execution example files as .smt files
smts-1 := $(patsubst %.c,%.smt,$(wildcard examples/symbolic/*-1-*.c))
smts-2 := $(patsubst %.c,%.smt,$(wildcard examples/symbolic/*-2-*.c))
smts-3 := $(patsubst %.c,%.smt,$(wildcard examples/symbolic/*-3-*.c))

# Run monster on *.c files in symbolic
smt: $(smts-1) $(smts-2) $(smts-3)

# Compile modeler.c with selfie.h as library into modeler executable
modeler: tools/modeler.c selfie.h
	$(CC) $(CFLAGS) --include selfie.h $< -o $@

# Run modeler, the symbolic model generator, natively and as RISC-U executable
mod: modeler selfie.h selfie
	./modeler
	./selfie -c selfie.h tools/modeler.c -m 1

# Prevent make from deleting intermediate target modeler
.SECONDARY: modeler

# Translate *.c including selfie.c into BTOR2 model
%.btor2: %.c modeler
	./modeler -c $< - 0 --check-block-access
	chmod $(RPERMISSIONS) $@

# Gather symbolic execution example files as .btor2 files
btor2s := $(patsubst %.c,%.btor2,$(wildcard examples/symbolic/*.c))

# Run modeler on *.c files in symbolic and even on selfie
btor2: $(btor2s) selfie.btor2

# Consider these targets as targets, not files
.PHONY: spike qemu assemble 32-bit boolector btormc extras

# Run everything that requires non-standard tools
extras: spike qemu assemble 32-bit boolector btormc

# Run selfie on spike
spike: selfie.m selfie.s
	spike pk selfie.m -c selfie.c -o selfie-spike.m -s selfie-spike.s -m 1
	chmod $(XPERMISSIONS) selfie-spike.m
	chmod $(RPERMISSIONS) selfie-spike.s
	diff -q selfie.m selfie-spike.m
	diff -q selfie.s selfie-spike.s

# Run selfie on qemu usermode emulation
qemu: selfie.m selfie.s
	qemu-riscv64-static selfie.m -c selfie.c -o selfie-qemu.m -s selfie-qemu.s -m 1
	chmod $(XPERMISSIONS) selfie-qemu.m
	chmod $(RPERMISSIONS) selfie-qemu.s
	diff -q selfie.m selfie-qemu.m
	diff -q selfie.s selfie-qemu.s

# Assemble RISC-U with GNU toolchain for RISC-V
assemble: selfie.s
	riscv64-linux-gnu-as selfie.s

# Self-self-compile, self-execute, self-host 32-bit selfie
32-bit: selfie-32
	./selfie-32 -c selfie.c -o selfie-32.m -s selfie-32.s -m 2 -c selfie.c -o selfie-32-2-32.m -s selfie-32-2-32.s
	chmod $(XPERMISSIONS) selfie-32.m selfie-32-2-32.m
	chmod $(RPERMISSIONS) selfie-32.s selfie-32-2-32.s
	diff -q selfie-32.m selfie-32-2-32.m
	diff -q selfie-32.s selfie-32-2-32.s
	./selfie-32 -l selfie-32.m -m 2 -l selfie-32.m -m 1
	./selfie-32 -l selfie-32.m -m 2 -l selfie-32.m -y 1 -l selfie-32.m -y 1
	qemu-riscv32-static selfie-32.m -c selfie.c -o selfie-qemu-32.m -s selfie-qemu-32.s -m 1
	chmod $(XPERMISSIONS) selfie-qemu-32.m
	chmod $(RPERMISSIONS) selfie-qemu-32.s
	diff -q selfie-32.m selfie-qemu-32.m
	diff -q selfie-32.s selfie-qemu-32.s
	riscv64-linux-gnu-as selfie-32.s

# Run boolector SMT solver on SMT-LIB files generated by monster
boolector: smt
	$(foreach file, $(smts-1), [ $$(boolector $(file) -e 0 | grep -c ^sat$$) -eq 1 ] &&) true
	$(foreach file, $(smts-2), [ $$(boolector $(file) -e 0 | grep -c ^sat$$) -eq 2 ] &&) true
	$(foreach file, $(smts-3), [ $$(boolector $(file) -e 0 | grep -c ^sat$$) -eq 3 ] &&) true

# Run btormc bounded model checker on BTOR2 files generated by modeler
btormc: btor2
	$(foreach file, $(btor2s), btormc $(file) &&) true

# Consider these targets as targets, not files
.PHONY: validator grader grade pythons

# Run everything that requires python
pythons: validator grader grade

# files where validator fails (e.g. timeout) and succeeds
failingFiles := $(wildcard examples/symbolic/*-fail-*.c)
succeedFiles := $(filter-out $(failingFiles),$(wildcard examples/symbolic/*.c))

# Run validator on *.c files in symbolic
validator: selfie modeler
	$(foreach file, $(succeedFiles), tools/validator.py $(file) &&) true
	$(foreach file, $(failingFiles), ! tools/validator.py $(file) &&) true

# Test autograder
grader: selfie
	cd grader && python3 -m unittest discover -v

# Run autograder
grade:
	grader/self.py self-compile

# Consider these targets as targets, not files
.PHONY: everything clean

# Run everything, except anything that requires python
everything: all extras

# Clean up
clean:
	rm -f *.m
	rm -f *.s
	rm -f *.smt
	rm -f *.btor2
	rm -f selfie selfie-32 selfie.h selfie.exe
	rm -f babysat monster modeler
	rm -f examples/*.m
	rm -f examples/*.s
	rm -f examples/symbolic/*.smt
	rm -f examples/symbolic/*.btor2
