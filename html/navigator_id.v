// Copyright (c) 2022, Andrew Kaster <akaster@serenityos.org>
// Copyright (c) 2024, Jamie Mansfield <jmansfield@cadixdev.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of NavigatorID.cpp. ResourceLoader-owned values are supplied
// when the mixin is constructed.
module html

pub enum NavigatorCompatibilityMode {
	chrome
	gecko
	webkit
}

pub struct NavigatorIDMixin {
pub:
	environment_default_user_agent string
	platform_value                 string
	compatibility_mode             NavigatorCompatibilityMode
}

pub fn (navigator &NavigatorIDMixin) app_code_name() string {
	return 'Mozilla'
}

pub fn (navigator &NavigatorIDMixin) app_name() string {
	return 'Netscape'
}

// https://html.spec.whatwg.org/multipage/system-state.html#dom-navigator-appversion
pub fn (navigator &NavigatorIDMixin) app_version() string {
	user_agent := navigator.environment_default_user_agent
	if !user_agent.starts_with('Mozilla/5.0 (') {
		return ''
	}
	trail := user_agent['Mozilla/'.len..]
	if navigator.compatibility_mode in [.chrome, .webkit] {
		return trail
	}
	if trail.starts_with('5.0 (Windows') {
		return '5.0 (Windows)'
	}
	if semicolon := trail.index(';') {
		return trail[..semicolon] + ')'
	}
	return trail
}

// https://html.spec.whatwg.org/multipage/system-state.html#dom-navigator-platform
pub fn (navigator &NavigatorIDMixin) platform() string {
	return navigator.platform_value
}

pub fn (navigator &NavigatorIDMixin) product() string {
	return 'Gecko'
}

// https://html.spec.whatwg.org/multipage/system-state.html#dom-navigator-productsub
pub fn (navigator &NavigatorIDMixin) product_sub() string {
	return if navigator.compatibility_mode in [.chrome, .webkit] {
		'20030107'
	} else {
		'20100101'
	}
}

// https://html.spec.whatwg.org/multipage/system-state.html#dom-navigator-useragent
pub fn (navigator &NavigatorIDMixin) user_agent() string {
	return navigator.environment_default_user_agent
}

// https://html.spec.whatwg.org/multipage/system-state.html#dom-navigator-vendor
pub fn (navigator &NavigatorIDMixin) vendor() string {
	return match navigator.compatibility_mode {
		.chrome { 'Google Inc.' }
		.gecko { '' }
		.webkit { 'Apple Computer, Inc.' }
	}
}

pub fn (navigator &NavigatorIDMixin) vendor_sub() string {
	return ''
}
