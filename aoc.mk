SHELL := /bin/bash

DATA = ../data/input$(DAY).txt
PROGRAMS = p$(DAY)

BUILD_OPTS += -freference-trace
ifneq ($(DEVEL),1)
BUILD_OPTS += -OReleaseFast
endif

define make-aoc-mod-target
  $1_test:
	zig test $1 -freference-trace

  test:: $1_test
endef

define make-aoc-prg-target
  $1: $1.zig $(MODULES)
	zig build-exe $1.zig $(BUILD_OPTS)
  $1_clean:
	rm -f $1
  $1_run: $1_run1 $1_run2
  $1_run1: $1
	./$1 1 < $(DATA)
  $1_run2: $1
	./$1 2 < $(DATA)
  $1_valgrind: $1
	valgrind ./$1 < $(DATA)

  all:: $1
  clean:: $1_clean
  run1:: $1_run1
  run2:: $1_run2
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

.PHONY: run run1 run1
run:: ## run all parts of this problem
run1:: ## run part 1 of this problem
run2:: ## run part 2 of this problem

.PHONY: valgrind
valgrind:: ## valgrind all parts of this problem

.PHONY: test
test:: ## test all modules

# Borrowed from https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help
help: ## display this help section
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "\033[36m%-38s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
.DEFAULT_GOAL := all
