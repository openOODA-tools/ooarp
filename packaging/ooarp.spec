Name:           ooarp
Version:        0.1.0
Release:        1%{?dist}
Summary:        Inspects and flushes neighbor discovery and ARP tables on local network segments.
License:        ASL 2.0
URL:            https://github.com/openOODA-tools/ooarp
Source0:        ooarp-linux-x86_64
Source1:        uninstall.sh
BuildArch:      x86_64
Requires:       glibc

%description
ooarp is a sovereign, capability-bounded ARP CACHE TOOL written
in pure openOODA, featuring zero ambient authority, oote color themes,
and an MCP stdio server.

%install
mkdir -p %{buildroot}/usr/bin
install -m 0755 %{SOURCE0} %{buildroot}/usr/bin/ooarp
install -m 0755 %{SOURCE1} %{buildroot}/usr/bin/ooarp-uninstall

%files
/usr/bin/ooarp
/usr/bin/ooarp-uninstall

%changelog
* Wed Oct 07 2026 openOODA-tools <ops@openooda.org> - 0.1.0-1
- Initial sovereign blueprint scaffolding
