# =====================================================================
# Makefile — short commands. Run them from this folder, e.g.  make check
# Type  make  (or make help) to see the list.
# If fastlane is installed with Bundler, use:  make ios-beta FASTLANE="bundle exec fastlane"
# =====================================================================
FASTLANE ?= fastlane
DRAFT ?= false

.PHONY: help setup check run ios-create ios-beta ios-release ios-info ios-privacy android-key android-internal android-closed android-production android-info store-info clean

help:
	@echo "make setup               ONE TIME: turn the template into a new app"
	@echo "make check               get packages, analyze code, run tests"
	@echo "make run                 run the app on a connected device/simulator"
	@echo "make ios-create          ONE TIME: create App ID + App Store Connect app"
	@echo "make ios-beta            build + upload to TestFlight"
	@echo "make ios-release         build + upload to App Store (submit by hand)"
	@echo "make ios-info            upload store texts, URLs, review contact, category"
	@echo "make ios-privacy         fill App Privacy answers (saved once, reused)"
	@echo "make android-key         check the Google Play JSON key"
	@echo "make android-internal    build + upload to Internal testing (add DRAFT=true for a draft app)"
	@echo "make android-closed      build + upload to Closed testing"
	@echo "make android-production  build + upload to Production"
	@echo "make android-info        upload listing texts + contact email/phone/website"
	@echo "make store-info          ios-info + android-info"
	@echo "make clean               delete build files"

setup:
	./setup/new_app.sh

check:
	flutter pub get
	flutter analyze
	flutter test

run:
	flutter run

ios-create:
	cd ios && $(FASTLANE) create_app

ios-beta:
	cd ios && $(FASTLANE) beta

ios-release:
	cd ios && $(FASTLANE) release

ios-info:
	cd ios && $(FASTLANE) info

ios-privacy:
	cd ios && $(FASTLANE) privacy

android-key:
	cd android && $(FASTLANE) validate_key

android-internal:
	cd android && $(FASTLANE) internal draft:$(DRAFT)

android-closed:
	cd android && $(FASTLANE) closed draft:$(DRAFT)

android-production:
	cd android && $(FASTLANE) production draft:$(DRAFT)

android-info:
	cd android && $(FASTLANE) info

store-info: ios-info android-info

clean:
	flutter clean

.PHONY: vclean
vclean:
	python3 release/vclean.py
