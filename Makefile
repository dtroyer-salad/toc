# Kale Makefile
#
# Common targets:
# * build - Build all of the binaries in this project
# * test - Run the tests for this project
# * deb - Build Debian packaging for the project
# * lint - run golangci-lint on the Go projects in the repo
# * lint-new - run golangci-lint on the projects in the repo, but only flag
#   errors that are included since REV NEW_FROM_COMMIT
#
# lint* targets require golang-lint
# MacOS: brew install golang-lint

PKG_NAME = kale
PKG_PREFIX ?= ./build
PKG_BIN_DIR = /usr/bin
PKG_BIN_FILES = bin/kale bin/kale-repo
VERSION_VAR = salad.com/kale/internal/core.Version

# Create a version from commit date and commit hash if one is not set
DATE := $(shell git log -1 --format=%cd --date=format:"%Y%m%d")
COMMIT := $(shell git rev-parse --short HEAD)
VERSION ?= $(DATE)-$(COMMIT)
VERSION_LD := -ldflags "-X $(VERSION_VAR)=$(VERSION)"

# Linters
LINT_ARGS_NEW = -n
LINT_ARGS =

.PHONY: build
build: build-repo

build-repo: CGO_ENABLED=0
build-repo:
	go build -o ./bin/kale-repo ./cmd/kale-repo/main.go

clean: clean-test
	rm -rf ./bin ./build $(PKG_PREFIX)/package-build $(PKG_PREFIX)/package-src
	go clean

clean-test:
	go clean -testcache

.PHONY: lint
lint:
	golangci-lint run ./... $(LINT_ARGS)

# Only raise errors in code since REV NEW_FROM_COMMIT
.PHONY: lint-new
lint-new:
	$(MAKE) LINT_ARGS="$(LINT_ARGS_NEW)" lint

test: test-repo

test-repo:
	(cd cmd/kale-repo; go test ./...)

tidy: tidy-repo

tidy-repo:
	(cd cmd/kale-repo; go mod tidy)
	(cd pkg/config; go mod tidy)
	(cd pkg/keys; go mod tidy)

# Packaging

$(PKG_PREFIX)/package-build $(PKG_PREFIX)/package-src/DEBIAN:
	mkdir -p $@

.PHONY: $(PKG_PREFIX)/package-src/DEBIAN/control
$(PKG_PREFIX)/package-src/DEBIAN/control:
	echo "Package: salad-$(PKG_NAME)" > $(PKG_PREFIX)/package-src/DEBIAN/control && \
	echo "Version: ${VERSION}" >> $(PKG_PREFIX)/package-src/DEBIAN/control && \
	echo "Architecture: amd64" >> $(PKG_PREFIX)/package-src/DEBIAN/control && \
	echo "Maintainer: Salad Technologies, Inc." >> $(PKG_PREFIX)/package-src/DEBIAN/control && \
	echo "Description: Salad $(PKG_NAME)" >> $(PKG_PREFIX)/package-src/DEBIAN/control

deb: $(PKG_PREFIX)/package-build $(PKG_PREFIX)/package-src/DEBIAN $(PKG_PREFIX)/package-src/DEBIAN/control
	mkdir -p $(PKG_PREFIX)/package-src$(PKG_BIN_DIR) && \
	cp -p $(PKG_BIN_FILES) $(PKG_PREFIX)/package-src$(PKG_BIN_DIR) && \
	dpkg-deb -Zxz --build $(PKG_PREFIX)/package-src $(PKG_PREFIX)/package-build
