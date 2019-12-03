first: all

DATA = ../data/input$(DAY).txt
PROGS = p$(DAY)a p$(DAY)b

define make-aoc-target
  $1: $1.zig $(MODULES)
	zig build-exe $1.zig
  $1_clean:
	rm -f $1
  $1_test: $1
	zig test $1.zig
  $1_run: $1
	./$1 < $(DATA)

  all:: $1
  clean:: $1_clean
  test:: $1_test
  run:: $1_run
endef

$(foreach prog,$(PROGS),$(eval $(call make-aoc-target,$(prog))))

clean::
	rm -fr zig-cache *.o *.swp
