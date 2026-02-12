# Sensible defaults
.ONESHELL:
SHELL := bash
.SHELLFLAGS := -e -u -c -o pipefail
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

# Derived values (DO NOT TOUCH).
CURRENT_MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
CURRENT_MAKEFILE_DIR := $(patsubst %/,%,$(dir $(CURRENT_MAKEFILE_PATH)))
GHOSTTY_XCFRAMEWORK_PATH := $(CURRENT_MAKEFILE_DIR)/Frameworks/GhosttyKit.xcframework
GHOSTTY_RESOURCE_PATH := $(CURRENT_MAKEFILE_DIR)/Resources/ghostty
GHOSTTY_TERMINFO_PATH := $(CURRENT_MAKEFILE_DIR)/Resources/terminfo
GHOSTTY_BUILD_OUTPUTS := $(GHOSTTY_XCFRAMEWORK_PATH) $(GHOSTTY_RESOURCE_PATH) $(GHOSTTY_TERMINFO_PATH)
.DEFAULT_GOAL := help
.PHONY: help build-ghostty-xcframework build-app run-app install-app check test

help:  # Display this help.
	@-+echo "Run make with one of the following targets:"
	@-+echo
	@-+grep -Eh "^[a-z-]+:.*#" $(CURRENT_MAKEFILE_PATH) | sed -E 's/^(.*:)(.*#+)(.*)/  \1 @@@ \3 /' | column -t -s "@@@"

build-ghostty-xcframework: $(GHOSTTY_BUILD_OUTPUTS) # Build ghostty framework

$(GHOSTTY_BUILD_OUTPUTS):
	@cd $(CURRENT_MAKEFILE_DIR)/ThirdParty/ghostty && mise exec -- zig build -Doptimize=ReleaseFast -Demit-xcframework=true -Dsentry=false
	rsync -a ThirdParty/ghostty/macos/GhosttyKit.xcframework Frameworks
	@src="$(CURRENT_MAKEFILE_DIR)/ThirdParty/ghostty/zig-out/share/ghostty"; \
	dst="$(GHOSTTY_RESOURCE_PATH)"; \
	terminfo_src="$(CURRENT_MAKEFILE_DIR)/ThirdParty/ghostty/zig-out/share/terminfo"; \
	terminfo_dst="$(GHOSTTY_TERMINFO_PATH)"; \
	mkdir -p "$$dst"; \
	rsync -a --delete "$$src/" "$$dst/"; \
	mkdir -p "$$terminfo_dst"; \
	rsync -a --delete "$$terminfo_src/" "$$terminfo_dst/"

build-app: build-ghostty-xcframework # Build the macOS app (Debug)
	bash -o pipefail -c 'xcodebuild -project Bourbaki.xcodeproj -scheme Bourbaki -configuration Debug build -skipMacroValidation 2>&1 | mise exec -- xcsift -qw --format toon'

run-app: build-app # Build then launch (Debug) with log streaming
	@settings="$$(xcodebuild -project Bourbaki.xcodeproj -scheme Bourbaki -configuration Debug -showBuildSettings -json 2>/dev/null)"; \
	build_dir="$$(echo "$$settings" | jq -r '.[0].buildSettings.BUILT_PRODUCTS_DIR')"; \
	product="$$(echo "$$settings" | jq -r '.[0].buildSettings.FULL_PRODUCT_NAME')"; \
	exec_name="$$(echo "$$settings" | jq -r '.[0].buildSettings.EXECUTABLE_NAME')"; \
	"$$build_dir/$$product/Contents/MacOS/$$exec_name"

install-app: build-ghostty-xcframework # Release build and install to /Applications
	bash -o pipefail -c 'xcodebuild -project Bourbaki.xcodeproj -scheme Bourbaki -configuration Release build -skipMacroValidation 2>&1 | mise exec -- xcsift -qw --format toon'
	@settings="$$(xcodebuild -project Bourbaki.xcodeproj -scheme Bourbaki -configuration Release -showBuildSettings -json 2>/dev/null)"; \
	build_dir="$$(echo "$$settings" | jq -r '.[0].buildSettings.BUILT_PRODUCTS_DIR')"; \
	product="$$(echo "$$settings" | jq -r '.[0].buildSettings.FULL_PRODUCT_NAME')"; \
	echo "Installing $$product to /Applications..."; \
	rm -rf "/Applications/$$product"; \
	cp -R "$$build_dir/$$product" /Applications/; \
	echo "Installed /Applications/$$product"

check: # Format and lint
	swift-format -p --in-place --recursive --configuration ./.swift-format.json Bourbaki
	mise exec -- swiftlint --fix --quiet
	mise exec -- swiftlint lint --quiet --config .swiftlint.yml

test: build-ghostty-xcframework # Run tests
	xcodebuild test -project Bourbaki.xcodeproj -scheme Bourbaki -destination "platform=macOS" -skipMacroValidation 2>&1
