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
	assert shadow_root.custom_element_registry() == voidptr(0)

	mut mutable_shadow_root := unsafe { &dom.ShadowRoot(shadow_root) }
	mutable_shadow_root.set_custom_element_registry(voidptr(registry))
	assert shadow_root.custom_element_registry() == voidptr(registry)
}

fn test_cloned_document_retains_custom_element_registry_identity() {
	document := dom.Document.create(dom.url_about_blank())
	registry := CustomElementRegistry.create(document)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_custom_element_registry(voidptr(registry))

	cloned_node := document.as_node().clone_single_node(document)!
	cloned_document := cloned_node.as_document() or { panic('expected a cloned document') }
	assert cloned_document.custom_element_registry() == voidptr(registry)
}
