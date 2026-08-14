// Copyright (c) 2026, Reimar Pihl Browa <mail@reim.ar>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/External.cpp.
// https://html.spec.whatwg.org/multipage/obsolete.html#external
module html

@[heap]
pub struct External {}

pub fn External.create() &External {
	return &External{}
}

// https://html.spec.whatwg.org/multipage/obsolete.html#dom-external-addsearchprovider
pub fn (e &External) add_search_provider() {
	// Do nothing
}

// https://html.spec.whatwg.org/multipage/obsolete.html#dom-external-issearchproviderinstalled
pub fn (e &External) is_search_provider_installed() {
	// Do nothing
}
