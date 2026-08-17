// Copyright (c) 2025, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/BarProp.{h,cpp}.
module html

// https://html.spec.whatwg.org/multipage/nav-history-apis.html#barprop
pub struct BarProp {
pub:
	// none represents a null browsing context. Otherwise this is the popup
	// flag of the associated top-level browsing context.
	top_level_is_popup ?bool
}

pub fn BarProp.create(top_level_is_popup ?bool) &BarProp {
	return &BarProp{
		top_level_is_popup: top_level_is_popup
	}
}

// https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-barprop-visible
pub fn (bar &BarProp) visible() bool {
	// A missing browsing context is visible. Otherwise visibility is the
	// negation of the top-level browsing context's popup flag.
	return !(bar.top_level_is_popup or { return true })
}
