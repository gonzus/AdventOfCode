first: all

DATA = ../data/input$(DAY).txt
PROGRAMS = p$(DAY)a p$(DAY)b

define make-aoc-mod-target
  $1_test:
	zig test $1

  test:: $1_test
endef

define make-aoc-prg-target
  $1: $1.zig $(MODULES)
	zig build-exe $1.zig
  $1_clean:
	rm -f $1
  $1_run: $1
	./$1 < $(DATA)

  all:: $1
  clean:: $1_clean
  run:: $1_run
endef

$(foreach prg,$(PROGRAMS),$(eval $(call make-aoc-prg-target,$(prg))))
$(foreach mod,$(MODULES) ,$(eval $(call make-aoc-mod-target,$(mod))))

clean::
	rm -fr zig-cache *.o *.swp
