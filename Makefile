# Touch Bar Rainbow
# Copyright (C) 2026 nilouabdi
# SPDX-License-Identifier: GPL-3.0-or-later

APP_NAME := TouchBarRainbow
APP      := build/$(APP_NAME).app
BIN_DIR   = $(shell swift build -c release --show-bin-path)

.PHONY: all app install uninstall run test preview clean

all: app

## Build build/TouchBarRainbow.app (ad-hoc signed)
app:
	swift build -c release --product $(APP_NAME)
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp "$(BIN_DIR)/$(APP_NAME)" "$(APP)/Contents/MacOS/$(APP_NAME)"
	cp Packaging/Info.plist "$(APP)/Contents/Info.plist"
	codesign --force --sign - "$(APP)"
	@echo "Built $(APP)"

## Copy the app to /Applications and start it
install: app
	-pkill -x $(APP_NAME)
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(APP)" /Applications/
	open "/Applications/$(APP_NAME).app"

uninstall:
	-pkill -x $(APP_NAME)
	rm -rf "/Applications/$(APP_NAME).app"

## Run straight from the build folder
run: app
	open "$(APP)"

## Unit + visual tests
test:
	swift test

## Render docs/preview.png and docs/preview.gif (needs Pillow: pip3 install pillow)
preview:
	swift run -c release rainbow-preview build/frames --frames 60 --fps 10
	python3 scripts/make-preview.py build/frames docs/preview

clean:
	rm -rf .build build
