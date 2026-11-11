module dom

// ShadowRoot inherits DocumentFragment's nodeName, regardless of visibility.
// Ladybird 6062e3396a9e47f1d1fbf78642ddaddee75020a1.
fn test_shadow_root_node_name_is_document_fragment() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	for mode in [ShadowRootMode.open, .closed] {
		mut host := document.create_element_ns(namespace_html_uri, 'div')!
		root := host.attach_shadow(ShadowRootInit{ mode: mode })!
		assert root.node_name() == '#document-fragment'
		assert root.as_node().node_name() == '#document-fragment'
		assert root.as_node().type_() == .document_fragment_node
		assert root.is_shadow_root()
	}
}
