SHELL := /bin/bash

DATA = ../data/input$(DAY).txt
PROGRAMS = p$(DAY)a p$(DAY)b

define make-aoc-mod-target
  $1_test:
	time zig test $1

  test:: $1_test
endef

define make-aoc-prg-target
  $1: $1.zig $(MODULES)
	zig build-exe -mcpu=baseline $1.zig
  $1_clean:
	rm -f $1
  $1_run: $1
	time ./$1 < $(DATA)
  $1_valgrind: $1
	time valgrind ./$1 < $(DATA)

  all:: $1
  clean:: $1_clean
  run:: $1_run
  valgrind:: $1_valgrind
endef

$(foreach prg,$(PROGRAMS),$(eval $(call make-aoc-prg-target,$(prg))))
$(foreach mod,$(MODULES) ,$(eval $(call make-aoc-mod-target,$(mod))))

.PHONY: clean
clean:: ## clean all
	rm -fr zig-cache *.o *.swp

.PHONY: all
all:: ## build all parts of this problem

.PHONY: run
run:: ## run all parts of this problem

.PHONY: valgrind
valgrind:: ## valgrind all parts of this problem

.PHONY: test
test:: ## test all modules

# Borrowed from https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help
help: ## display this help section
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "\033[36m%-38s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
.DEFAULT_GOAL := all
