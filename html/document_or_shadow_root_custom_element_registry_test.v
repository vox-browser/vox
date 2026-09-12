module html

import dom

fn test_document_and_shadow_root_retain_custom_element_registry_identity() {
	document := dom.Document.create(dom.url_about_blank())
	registry := CustomElementRegistry.create(document)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_custom_element_registry(voidptr(registry))

	assert document.custom_element_registry() == voidptr(registry)

	mut host := dom.create_element(document, 'div', 'http://www.w3.org/1999/xhtml', none, none, false)!
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	assert shadow_root.custom_element_registry() == voidptr(registry)

	mut mutable_shadow_root := unsafe { &dom.ShadowRoot(shadow_root) }
	mutable_shadow_root.set_custom_element_registry(voidptr(registry))
	assert shadow_root.custom_element_registry() == voidptr(registry)
}

fn test_cloned_document_only_retains_a_scoped_custom_element_registry() {
	document := dom.Document.create(dom.url_about_blank())
	registry := CustomElementRegistry.create(document)

	cloned_node := document.as_node().clone_single_node(document)!
	cloned_document := cloned_node.as_document() or { panic('expected a cloned document') }
	assert cloned_document.custom_element_registry() == voidptr(0)

	scoped_registry := CustomElementRegistry.construct(document)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_custom_element_registry(voidptr(scoped_registry))
	cloned_scoped_node := document.as_node().clone_single_node(document)!
	cloned_scoped_document := cloned_scoped_node.as_document() or {
		panic('expected a cloned document')
	}
	assert cloned_scoped_document.custom_element_registry() == voidptr(scoped_registry)
}

fn test_window_returns_its_documents_custom_element_registry() {
	document := dom.Document.create(dom.url_about_blank())
	context := BrowsingContextModel.create(document, none, 'top')
	window := WindowModel.create(document, context)!
	assert voidptr(window.custom_elements()) == document.custom_element_registry()

	replacement := CustomElementRegistry.create(document)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_custom_element_registry(voidptr(replacement))
	assert window.custom_elements() == replacement
}

fn test_element_retains_custom_element_registry_identity() {
	document := dom.Document.create(dom.url_about_blank())
	registry := CustomElementRegistry.create(document)
	mut element := dom.create_element(document, 'x-widget', 'http://www.w3.org/1999/xhtml', none, none, false)!
	assert element.custom_element_registry() == voidptr(registry)

	replacement := CustomElementRegistry.construct(document)
	element.set_custom_element_registry(voidptr(replacement))
	assert element.custom_element_registry() == voidptr(replacement)
}
