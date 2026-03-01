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

# Version metadata (overrides Xcode defaults at build time)
APP_VERSION ?= 0.1.0
GIT_COMMIT_SHORT := $(shell git rev-parse --short=8 HEAD 2>/dev/null || echo nogit)
GIT_COMMIT_COUNT := $(shell git rev-list --count HEAD 2>/dev/null || echo 0)
VERSION_WITH_COMMIT := $(APP_VERSION)+$(GIT_COMMIT_SHORT)

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
	@echo "Building Bourbaki $(VERSION_WITH_COMMIT) ($(GIT_COMMIT_COUNT))"
	bash -o pipefail -c 'xcodebuild -project Bourbaki.xcodeproj -scheme Bourbaki -configuration Debug build -skipMacroValidation MARKETING_VERSION="$(VERSION_WITH_COMMIT)" CURRENT_PROJECT_VERSION="$(GIT_COMMIT_COUNT)" 2>&1 | mise exec -- xcsift -qw --format toon'
	@settings="$$(xcodebuild -project Bourbaki.xcodeproj -scheme Bourbaki -configuration Debug -showBuildSettings -json MARKETING_VERSION="$(VERSION_WITH_COMMIT)" CURRENT_PROJECT_VERSION="$(GIT_COMMIT_COUNT)" 2>/dev/null)"; \
	build_dir="$$(echo "$$settings" | jq -r '.[0].buildSettings.BUILT_PRODUCTS_DIR')"; \
	product="$$(echo "$$settings" | jq -r '.[0].buildSettings.FULL_PRODUCT_NAME')"; \
	plist="$$build_dir/$$product/Contents/Info.plist"; \
	short_version="$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$$plist")"; \
	build_version="$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$$plist")"; \
	echo "Built version: $$short_version ($$build_version)"

run-app: build-app # Build then launch (Debug) with log streaming
	@settings="$$(xcodebuild -project Bourbaki.xcodeproj -scheme Bourbaki -configuration Debug -showBuildSettings -json 2>/dev/null)"; \
	build_dir="$$(echo "$$settings" | jq -r '.[0].buildSettings.BUILT_PRODUCTS_DIR')"; \
	product="$$(echo "$$settings" | jq -r '.[0].buildSettings.FULL_PRODUCT_NAME')"; \
	exec_name="$$(echo "$$settings" | jq -r '.[0].buildSettings.EXECUTABLE_NAME')"; \
	"$$build_dir/$$product/Contents/MacOS/$$exec_name"

install-app: build-ghostty-xcframework # Release build and install to /Applications
	@echo "Building Bourbaki $(VERSION_WITH_COMMIT) ($(GIT_COMMIT_COUNT))"
	bash -o pipefail -c 'xcodebuild -project Bourbaki.xcodeproj -scheme Bourbaki -configuration Release build -skipMacroValidation MARKETING_VERSION="$(VERSION_WITH_COMMIT)" CURRENT_PROJECT_VERSION="$(GIT_COMMIT_COUNT)" 2>&1 | mise exec -- xcsift -qw --format toon'
	@settings="$$(xcodebuild -project Bourbaki.xcodeproj -scheme Bourbaki -configuration Release -showBuildSettings -json MARKETING_VERSION="$(VERSION_WITH_COMMIT)" CURRENT_PROJECT_VERSION="$(GIT_COMMIT_COUNT)" 2>/dev/null)"; \
	build_dir="$$(echo "$$settings" | jq -r '.[0].buildSettings.BUILT_PRODUCTS_DIR')"; \
	product="$$(echo "$$settings" | jq -r '.[0].buildSettings.FULL_PRODUCT_NAME')"; \
	plist="$$build_dir/$$product/Contents/Info.plist"; \
	short_version="$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$$plist")"; \
	build_version="$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$$plist")"; \
	echo "Built version: $$short_version ($$build_version)"; \
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
