.PHONY: build test app dmg preview integration-test closed-lid-integration-test clean

build:
	swift build

test:
	swift run WakeBarLogicTests

app:
	./scripts/build-app.sh

dmg:
	./scripts/build-dmg.sh

preview:
	./scripts/render-preview.sh

integration-test:
	./scripts/run-integration-test.sh

closed-lid-integration-test:
	./scripts/run-closed-lid-integration-test.sh

clean:
	swift package clean
	rm -rf .build-arm64 .build-x86_64 .build-x86 .build-universal
	rm -rf dist
