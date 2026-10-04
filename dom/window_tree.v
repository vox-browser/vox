// Source Window.cpp accessors over the actual associated Document tree.
module dom

// https://html.spec.whatwg.org/multipage/window-object.html#dom-length
pub fn (window &Window) length() u32 {
	document := window.associated_document() or { panic('Source Window length requires its associated Document') }
	return u32(document.document_tree_child_navigables().len)
}

// https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-top
pub fn (window &Window) top() ?&WindowProxy {
	navigable := window.navigable() or { return none }
	return navigable.top_level_traversable().active_window_proxy()
}

// https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-parent
pub fn (window &Window) parent() ?&WindowProxy {
	navigable := window.navigable() or { return none }
	if parent := navigable.parent() {
		return parent.active_window_proxy()
	}
	return navigable.active_window_proxy()
}
