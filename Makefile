.DEFAULT_GOAL := run

E_OPTIMIZE := Debug ReleaseSafe ReleaseFast ReleaseSmall

OPTIMIZE ?= Debug
ifeq ($(filter $(OPTIMIZE),$(E_OPTIMIZE)),)
$(error Invalid option: '$(OPTIMIZE)')
endif

BIN := metronome
OUT_DIR := zig-out/bin

$(OUT_DIR)/$(BIN):
	zig build -Doptimize=$(OPTIMIZE) --summary all

run: $(OUT_DIR)/$(BIN)
	$<

debug: OPTIMIZE := Debug
debug: $(OUT_DIR)/$(BIN)

release: OPTIMIZE := ReleaseSmall
release: $(OUT_DIR)/$(BIN)

clean:
	rm -rf .zig-cache zig-out

.PHONY: $(OUT_DIR)/$(BIN) run debug release clean
