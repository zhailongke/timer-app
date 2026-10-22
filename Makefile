SWIFTLINT := $(shell command -v swiftlint 2>/dev/null || echo mise exec -- swiftlint)
APP_NAME := Timer
INSTALL_DIR := /Applications
VERSION := $(shell grep -m1 'MARKETING_VERSION' Timer.xcodeproj/project.pbxproj \
	| sed -E 's/.*MARKETING_VERSION = (.*);/\1/')

.PHONY: default clean build open test uitest lint analyze format install-cli build-local open-local install dmg uninstall

default: clean build open

clean:
	xcodebuild -quiet clean

build:
	xcodebuild -quiet build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

open: build
	open ./build/Release/Timer.app

test:
	xcodebuild -quiet test -scheme Timer -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

uitest:
	xcodebuild -quiet test -scheme TimerUITests -destination 'platform=macOS' -allowProvisioningUpdates

lint:
	$(SWIFTLINT)

analyze:
	xcodebuild build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO > /tmp/xcodebuild-timer.log 2>&1 || true
	$(SWIFTLINT) analyze --compiler-log-path /tmp/xcodebuild-timer.log

format:
	$(SWIFTLINT) --fix

install-cli:
	install -m 755 timer-cli /usr/local/bin/timer

# 不依赖 Xcode 的构建：swiftc + 手工打包，产物 .build/Timer.app
build-local:
	Scripts/build.sh

open-local: build-local
	open .build/Timer.app

# 把 Release 版装到 /Applications，出现在启动台与应用程序列表里
install: build
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	ditto build/Release/$(APP_NAME).app "$(INSTALL_DIR)/$(APP_NAME).app"
	codesign --force --deep --sign - "$(INSTALL_DIR)/$(APP_NAME).app"
	xattr -cr "$(INSTALL_DIR)/$(APP_NAME).app" || true
	@echo "已安装：$(INSTALL_DIR)/$(APP_NAME).app ($(VERSION))"

uninstall:
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "已卸载：$(INSTALL_DIR)/$(APP_NAME).app"

# 生成可分发磁盘镜像（含 /Applications 快捷方式）
dmg: build
	rm -rf build/dmg build/$(APP_NAME)-$(VERSION).dmg
	mkdir -p build/dmg
	ditto build/Release/$(APP_NAME).app build/dmg/$(APP_NAME).app
	ln -s /Applications build/dmg/Applications
	hdiutil create -quiet -volname "$(APP_NAME)" -srcfolder build/dmg -ov -format UDZO \
		"build/$(APP_NAME)-$(VERSION).dmg"
	rm -rf build/dmg
	@echo "已生成：build/$(APP_NAME)-$(VERSION).dmg"
