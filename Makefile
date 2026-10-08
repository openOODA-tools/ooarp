# ooarp v0.2.0 Makefile

OODA_COMPILER ?= $(firstword $(wildcard $(HOME)/.openooda/bin/oodac $(CURDIR)/../../openOODA/oodac/bin/oodac))
OODACODEX ?= $(HOME)/.openooda/northstar.oot
OO_LIST_AMBIENT_QUOTA ?= 8589934592
BIN := dist/ooarp

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

SRC := $(wildcard *.oo) $(wildcard */*.oo)
VERSION ?= $(shell cat VERSION 2>/dev/null || echo 0.2.0)

.PHONY: build check line-cap file-law academy density verify clean test package package-deb package-rpm package-arch install uninstall

build: $(BIN)

$(BIN): $(SRC)
	@mkdir -p dist .ooda-cache/ooda-tmp
	OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) build main.oo -o $(BIN)
	@chmod +x $(BIN)
	@cp -a $(BIN) dist/ooarp-linux-x86_64
	@sha256sum dist/ooarp-linux-x86_64 > dist/ooarp-linux-x86_64.sha256
	@echo "built $(BIN) (and dist/ooarp-linux-x86_64)"

# --- Verification gate ---------------------------------------------------------

line-cap:
	@violations=0; \
	for f in $$(find . -name "*.oo" -o -name "*.oot" | grep -v "/dist/" | grep -v "/.ooda-cache/"); do \
		n=$$(wc -l < "$$f"); \
		if [ $$n -gt 256 ]; then \
			echo "VIOLATION: $$f = $$n lines (exceeds 256)"; violations=$$((violations+1)); \
			continue; \
		fi; \
		code=$$(grep -vE '^[[:space:]]*(//.*)?$$' "$$f" | grep -cvE '^[[:space:]]*import[[:space:]]+"'); \
		if [ "$$code" = "0" ]; then continue; fi; \
		if [ $$n -lt 16 ]; then \
			echo "VIOLATION: $$f = $$n lines (under 16-line floor, not a shim)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations files violate the Page Rule"; exit 1; fi; \
	echo "PASS: Page Rule sizing (16-256 lines, shims exempt from floor) holds"

file-law:
	@forbidden="js ts rb pl json yaml toml"; \
	violations=0; \
	for ext in $$forbidden; do \
		found=$$(find . -name "*.$$ext" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null | head -3); \
		if [ -n "$$found" ]; then \
			echo "VIOLATION: .$$ext forbidden:"; echo "$$found"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.md" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null); do \
		if [ "$$f" != "./README.md" ] && [ "$$f" != "./AGENTS.md" ]; then \
			echo "VIOLATION: .md forbidden outside README.md and AGENTS.md: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.sh" -not -path "./.git/*" -not -path "./dist/*" 2>/dev/null); do \
		if [ "$$f" != "./install.sh" ] && [ "$$f" != "./uninstall.sh" ]; then \
			echo "VIOLATION: .sh forbidden outside install.sh and uninstall.sh: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: file-law violations"; exit 1; fi; \
	echo "PASS: file law holds"

academy:
	@failures=0; \
	for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		header=$$(head -7 "$$f"); \
		missing=""; \
		echo "$$header" | grep -q "^// # "        || missing="$$missing title"; \
		echo "$$header" | grep -q "^// Logline:"  || missing="$$missing logline"; \
		echo "$$header" | grep -q "^// Setup:"    || missing="$$missing setup"; \
		echo "$$header" | grep -q "^// Beats:"    || missing="$$missing beats"; \
		if [ -n "$$missing" ]; then \
			echo "FAIL: $$f missing Academy element(s):$$missing"; failures=$$((failures+1)); \
		fi; \
	done; \
	if [ $$failures -gt 0 ]; then echo "FAIL: $$failures academy header violations"; exit 1; fi; \
	echo "PASS: academy headers hold (all 4 elements present in first 7 lines)"

density:
	@violations=0; \
	for d in $$(find . -type d -not -path "./.git*" -not -path "./dist*" -not -path "./.ooda-cache*" -not -path "./packaging*" -not -path "./qa*"); do \
		n=$$(ls "$$d"/*.oo "$$d"/*.oot 2>/dev/null | grep -v '\*' | wc -l); \
		if [ $$n -gt 8 ]; then \
			echo "VIOLATION: $$d holds $$n pages (exceeds 8)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations directories exceed the density bound"; exit 1; fi; \
	echo "PASS: directory density (<= 8 pages per directory) holds"

check:
	@for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) check "$$f" > /dev/null || exit 1; \
	done; \
	echo "PASS: oodac check holds on all .oo files"

verify: line-cap file-law academy density check

test: $(BIN)
	@echo "=== testing --help ==="
	@./$(BIN) --help > /dev/null && echo "PASS: --help"
	@echo "=== testing --version ==="
	@./$(BIN) --version | grep -q "0.2.0" && echo "PASS: --version"
	@echo "=== testing MAC validation (valid) ==="
	@./$(BIN) --validate-mac "00:1a:2b:3c:4d:5e" | grep -q "Valid Syntax: YES" && echo "PASS: validate-mac valid"
	@echo "=== testing MAC validation (multicast) ==="
	@./$(BIN) --validate-mac "01:00:5e:00:00:01" | grep -q "Multicast:    YES" && echo "PASS: validate-mac multicast"
	@echo "=== testing MAC validation (broadcast) ==="
	@./$(BIN) --validate-mac "ff:ff:ff:ff:ff:ff" | grep -q "Broadcast:    YES" && echo "PASS: validate-mac broadcast"
	@echo "=== testing sample ARP table ==="
	@rm -rf /tmp/ooarp-test && mkdir -p /tmp/ooarp-test
	@printf "IP address       HW type     Flags       HW address            Mask     Device\n192.168.1.1     0x1         0x2         00:11:22:33:44:55     *        eth0\n192.168.1.50    0x1         0x2         66:77:88:99:aa:bb     *        eth0\n" > /tmp/ooarp-test/sample_arp
	@./$(BIN) /tmp/ooarp-test/sample_arp | grep -q "192.168.1.1" && echo "PASS: parse sample arp"
	@echo "=== testing json mode ==="
	@./$(BIN) /tmp/ooarp-test/sample_arp --json | grep -q '"ip":"192.168.1.1"' && echo "PASS: json mode"
	@echo "=== testing audit mode (healthy) ==="
	@./$(BIN) --audit /tmp/ooarp-test/sample_arp | grep -q "HEALTHY" && echo "PASS: audit healthy"
	@echo "=== testing audit mode (duplicate MAC detection) ==="
	@printf "IP address       HW type     Flags       HW address            Mask     Device\n192.168.1.1     0x1         0x2         aa:bb:cc:dd:ee:ff     *        eth0\n192.168.1.2     0x1         0x2         aa:bb:cc:dd:ee:ff     *        eth0\n" > /tmp/ooarp-test/poison_arp
	@./$(BIN) --audit /tmp/ooarp-test/poison_arp || true
	@./$(BIN) --audit /tmp/ooarp-test/poison_arp --json | grep -q '"duplicates":1' && echo "PASS: audit detected spoofing"
	@echo "=== testing MCP initialize ==="
	@printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' | ./$(BIN) --mcp | grep -q "protocolVersion" && echo "PASS: MCP initialize"
	@echo "=== testing MCP tools/list ==="
	@printf '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "arp_audit" && echo "PASS: MCP tools/list"
	@echo "=== testing MCP tools/call arp_validate_mac ==="
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"arp_validate_mac","arguments":{"mac":"00:11:22:33:44:55"}}}\n' | ./$(BIN) --mcp | grep -q 'is_valid.*true' && echo "PASS: MCP arp_validate_mac"
	@echo "=== testing MCP tools/call arp_audit ==="
	@printf '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"arp_audit","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q 'total' && echo "PASS: MCP arp_audit"
	@rm -rf /tmp/ooarp-test
	@echo "ALL TESTS PASSED"

install: $(BIN)
	@mkdir -p $(DESTDIR)$(BINDIR)
	install -m 0755 $(BIN) $(DESTDIR)$(BINDIR)/ooarp
	install -m 0755 uninstall.sh $(DESTDIR)$(BINDIR)/ooarp-uninstall
	@echo "installed ooarp and ooarp-uninstall to $(DESTDIR)$(BINDIR)"

uninstall:
	@rm -f $(DESTDIR)$(BINDIR)/ooarp $(DESTDIR)$(BINDIR)/ooarp-uninstall
	@if [ "$(PURGE)" = "1" ]; then rm -rf $(HOME)/.cache/ooarp $(HOME)/.config/ooarp; echo "purged user cache and config"; fi
	@echo "uninstalled ooarp and ooarp-uninstall from $(DESTDIR)$(BINDIR)"

package-deb: $(BIN)
	@mkdir -p dist/deb-root/DEBIAN dist/deb-root/usr/bin
	@sed "s/^Version:.*/Version: $(VERSION)-1/" packaging/debian/control.binary > dist/deb-root/DEBIAN/control
	@cp $(BIN) dist/deb-root/usr/bin/ooarp
	@chmod 0755 dist/deb-root/usr/bin/ooarp
	@cp uninstall.sh dist/deb-root/usr/bin/ooarp-uninstall
	@chmod 0755 dist/deb-root/usr/bin/ooarp-uninstall
	@dpkg-deb --build --root-owner-group dist/deb-root dist/ooarp_$(VERSION)-1_amd64.deb
	@rm -rf dist/deb-root
	@echo "built dist/ooarp_$(VERSION)-1_amd64.deb"

package-rpm: $(BIN)
	@mkdir -p ~/rpmbuild/SOURCES ~/rpmbuild/SPECS ~/rpmbuild/RPMS
	@cp $(BIN) ~/rpmbuild/SOURCES/ooarp-linux-x86_64
	@cp uninstall.sh ~/rpmbuild/SOURCES/uninstall.sh
	@sed "s/^Version:.*/Version: $(VERSION)/" packaging/ooarp.spec > ~/rpmbuild/SPECS/ooarp.spec
	@rpmbuild -bb ~/rpmbuild/SPECS/ooarp.spec
	@cp ~/rpmbuild/RPMS/x86_64/ooarp-$(VERSION)*.rpm dist/
	@echo "built dist RPM package"

package-arch: $(BIN)
	@mkdir -p dist/arch-pkg/usr/bin
	@cp $(BIN) dist/arch-pkg/usr/bin/ooarp
	@chmod 0755 dist/arch-pkg/usr/bin/ooarp
	@cp uninstall.sh dist/arch-pkg/usr/bin/ooarp-uninstall
	@chmod 0755 dist/arch-pkg/usr/bin/ooarp-uninstall
	@printf "pkgname = ooarp\npkgbase = ooarp\npkgver = $(VERSION)-1\npkgdesc = Inspects and flushes neighbor discovery and ARP tables on local network segments.\nurl = https://github.com/openOODA-tools/ooarp\nbuilddate = $$(date +%s)\npackager = openOODA-tools <ops@openooda.org>\nsize = $$(stat -c %s $(BIN))\narch = x86_64\nlicense = Apache-2.0\ndepend = glibc\nprovides = ooarp\n" > dist/arch-pkg/.PKGINFO
	@tar --zstd -cf dist/ooarp-$(VERSION)-1-x86_64.pkg.tar.zst -C dist/arch-pkg .PKGINFO usr
	@rm -rf dist/arch-pkg
	@bash -n packaging/arch/PKGBUILD
	@cp packaging/arch/PKGBUILD packaging/PKGBUILD
	@echo "built dist/ooarp-$(VERSION)-1-x86_64.pkg.tar.zst and validated PKGBUILD"

package: package-deb package-rpm package-arch
	@cd dist && sha256sum ooarp* > checksums.txt 2>/dev/null || true
	@echo "built all packages and dist/checksums.txt"

clean:
	@rm -rf dist .ooda-cache
	@echo "cleaned"
