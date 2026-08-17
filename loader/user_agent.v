// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Loader/{NavigatorCompatibilityMode,UserAgent}.h.
module loader

pub const browser_name = 'Ladybird'
pub const browser_version = '1.0'
pub const compatibility_token = 'Chrome/146.0.0.0 AppleWebKit/537.36 Safari/537.36'
pub const default_navigator_compatibility_mode = NavigatorCompatibilityMode.chrome

pub fn cpu_string() string {
	$if amd64 {
		return 'x86_64'
	} $else $if arm64 {
		return 'AArch64'
	} $else $if i386 {
		return 'x86'
	} $else $if rv64 {
		return 'RISC-V 64'
	} $else $if ppc64le {
		return 'PowerPC 64'
	} $else $if ppc64 {
		return 'PowerPC 64'
	} $else $if ppc {
		return 'PowerPC'
	} $else {
		return 'Unknown'
	}
}

pub fn os_string() string {
	$if serenity {
		return 'SerenityOS'
	} $else $if android {
		return 'Android 10'
	} $else $if macos {
		return 'macOS'
	} $else $if ios {
		return 'iOS'
	} $else $if linux {
		return 'Linux'
	} $else $if windows {
		return 'Windows'
	} $else $if freebsd {
		return 'FreeBSD'
	} $else $if openbsd {
		return 'OpenBSD'
	} $else $if netbsd {
		return 'NetBSD'
	} $else $if dragonfly {
		return 'DragonFly'
	} $else $if solaris {
		return 'SunOS'
	} $else $if haiku {
		return 'Haiku'
	} $else {
		return 'Unknown'
	}
}

pub fn default_user_agent() string {
	return 'Mozilla/5.0 (${os_string()}; ${cpu_string()}) ${browser_name}/${browser_version} ${compatibility_token}'
}

pub fn default_platform() string {
	return '${os_string()} ${cpu_string()}'
}
