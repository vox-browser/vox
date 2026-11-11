// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Loader/{NavigatorCompatibilityMode,UserAgent}.h.
module loader

pub const browser_name = 'Ladybird'
pub const browser_version = '1.0'
pub const compatibility_token = 'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36'
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

// Servers only recognize the frozen platform tokens sent by major browsers.
// Keep this decoupled from the actual OS/CPU reported by default_platform().
pub fn ua_platform_string() string {
	$if macos {
		return 'Macintosh; Intel Mac OS X 10_15_7'
	} $else $if ios {
		return 'iPhone; CPU iPhone OS 17_5 like Mac OS X'
	} $else $if android {
		return 'Linux; Android 10'
	} $else $if windows {
		return 'Windows NT 10.0; Win64; x64'
	} $else {
		return 'X11; Linux x86_64'
	}
}

pub fn default_user_agent() string {
	return 'Mozilla/5.0 (${ua_platform_string()}) ${browser_name}/${browser_version} ${compatibility_token}'
}

// navigator.platform uses kernel machine names rather than the browser's
// human-readable architecture labels used by cpu_string().
fn navigator_platform_machine() string {
	$if amd64 {
		return 'x86_64'
	} $else $if arm64 {
		return 'aarch64'
	} $else $if i386 {
		return 'i686'
	} $else $if rv64 {
		return 'riscv64'
	} $else $if ppc64le {
		return 'ppc64le'
	} $else $if ppc64 {
		return 'ppc64'
	} $else $if ppc {
		return 'ppc'
	} $else {
		return cpu_string()
	}
}

// navigator.platform follows the platform tokens exposed by other browsers,
// rather than the host's literal uname spelling on macOS and Windows.
pub fn default_platform() string {
	$if macos {
		return 'MacIntel'
	} $else $if ios {
		return 'iPhone'
	} $else $if windows {
		return 'Win32'
	} $else $if android {
		return 'Linux ${navigator_platform_machine()}'
	} $else {
		return '${os_string()} ${navigator_platform_machine()}'
	}
}
