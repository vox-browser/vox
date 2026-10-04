// Source Window.cpp accessors over the actual associated Document tree.
module dom

// https://html.spec.whatwg.org/multipage/window-object.html#dom-length
pub fn (window &Window) length() u32 {
	document := window.associated_document() or { panic('Source Window length requires its associated Document') }
	return u32(document.document_tree_child_navigables().len)
}
