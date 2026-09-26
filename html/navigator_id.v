// Copyright (c) 2022, Andrew Kaster <akaster@serenityos.org>
// Copyright (c) 2024, Jamie Mansfield <jmansfield@cadixdev.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of NavigatorID.cpp.
module html

import dom
import loader

pub struct NavigatorIDMixin {
pub:
	// NavigatorIDMixin::navigator_id_url() is virtual upstream: a Navigator answers with its Window's associated
	// Document's URL, and a WorkerNavigator with its global scope's URL.
	navigator_id_document ?&dom.Document
	navigator_id_global_url dom.URL
}

fn (navigator &NavigatorIDMixin) navigator_id_url() dom.URL {
	if document := navigator.navigator_id_document {
		return document.url
	}
	return navigator.navigator_id_global_url
}

pub fn (navigator &NavigatorIDMixin) app_code_name() string {
	return 'Mozilla'
}

pub fn (navigator &NavigatorIDMixin) app_name() string {
	return 'Netscape'
}

// https://html.spec.whatwg.org/multipage/system-state.html#dom-navigator-appversion
pub fn (navigator &NavigatorIDMixin) app_version() string {
	// 1. Let userAgent be this's relevant settings object's environment default `User-Agent` value.
	// FIXME: Store that on the settings object?
	user_agent := loader.ResourceLoader.the().user_agent_for_url(navigator.navigator_id_url())

	// 2. If userAgent does not start with `Mozilla/5.0 (`, then return the empty string.
	if !user_agent.starts_with('Mozilla/5.0 (') {
		return ''
	}
	// 3. Let trail be the substring of userAgent, isomorphic decoded, that follows the "Mozilla/" prefix.
	trail := user_agent['Mozilla/'.len..]

	// 4. -> If the navigator compatibility mode is Chrome or WebKit
	navigator_compatibility_mode := loader.ResourceLoader.the().navigator_compatibility_mode()
	if navigator_compatibility_mode in [.chrome, .webkit] {
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
	// FIXME: Use some portion of the user agent string to make spoofing work 100%
	return loader.ResourceLoader.the().platform()
}

pub fn (navigator &NavigatorIDMixin) product() string {
	return 'Gecko'
}

// https://html.spec.whatwg.org/multipage/system-state.html#dom-navigator-productsub
pub fn (navigator &NavigatorIDMixin) product_sub() string {
	return if loader.ResourceLoader.the().navigator_compatibility_mode() in [.chrome, .webkit] {
		'20030107'
	} else {
		'20100101'
	}
}

// https://html.spec.whatwg.org/multipage/system-state.html#dom-navigator-useragent
pub fn (navigator &NavigatorIDMixin) user_agent() string {
	// Must return the default `User-Agent` value.
	return loader.ResourceLoader.the().user_agent_for_url(navigator.navigator_id_url())
}

// https://html.spec.whatwg.org/multipage/system-state.html#dom-navigator-vendor
pub fn (navigator &NavigatorIDMixin) vendor() string {
	return match loader.ResourceLoader.the().navigator_compatibility_mode() {
		.chrome { 'Google Inc.' }
		.gecko { '' }
		.webkit { 'Apple Computer, Inc.' }
	}
}

pub fn (navigator &NavigatorIDMixin) vendor_sub() string {
	return ''
}
