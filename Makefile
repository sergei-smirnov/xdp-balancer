CLANG ?= clang
LLC ?= llc

CFLAGS = \
	-Ihelpers \
	-I/usr/include/x86_64-linux-gnu \
	-D__KERNEL__ \
	-Wno-int-to-void-pointer-cast \
	-Wno-compare-distinct-pointer-types \
	-fno-stack-protector -O2 -g

xdp_%.o: xdp_%.c Makefile
	$(CLANG) -c -emit-llvm $(CFLAGS) $< -o - | \
	$(LLC) -march=bpf -filetype=obj -o $@

.PHONY: all clean

all: xdp_balancer.o

clean:
	rm -f ./*.o
