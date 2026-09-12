module html

import dom

const scoped_registry_html_namespace = 'http://www.w3.org/1999/xhtml'

fn scoped_registry_document() (&dom.Document, &CustomElementRegistry) {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	document.set_document_type(.html)
	registry := CustomElementRegistry.create(document)
	return document, registry
}

fn test_scoped_registry_creation_and_definition_restrictions() {
	document, _ := scoped_registry_document()
	mut registry := CustomElementRegistry.construct(document)
	assert registry.is_scoped()
	if _ := registry.define('x-button', CustomElementConstructor{ id: 1 }, ElementDefinitionOptions{
		extends: 'button'
	}) {
		assert false
	} else {
		assert err.msg().starts_with('NotSupportedError:')
	}
}

fn test_scoped_registry_upgrades_only_elements_using_that_registry() {
	document, global_registry := scoped_registry_document()
	mut scoped_registry := CustomElementRegistry.construct(document)
	mut root := dom.create_element(document, 'div', scoped_registry_html_namespace, none, none, false)!
	mut scoped_element := document.create_element_with_options('x-widget', dom.ElementCreationOptions{
		custom_element_registry: voidptr(scoped_registry)
	})!
	global_element := document.create_element('x-widget')!
	mut root_node := root.as_node()
	root_node.append_child(scoped_element.as_node())!
	root_node.append_child(global_element.as_node())!
	mut document_node := document.as_node()
	document_node.append_child(root.as_node())!

	scoped_registry.define('x-widget', CustomElementConstructor{ id: 2 }, ElementDefinitionOptions{})!
	assert scoped_element.ensure_custom_element_reaction_queue().len == 1
	assert global_element.ensure_custom_element_reaction_queue().len == 0
	assert global_registry.get('x-widget') == none
}

fn test_initialize_assigns_registry_and_upgrades_unassigned_subtree() {
	document, _ := scoped_registry_document()
	mut registry := CustomElementRegistry.construct(document)
	registry.define('x-widget', CustomElementConstructor{ id: 3 }, ElementDefinitionOptions{})!
	mut root := dom.create_element_with_registry(document, 'section', scoped_registry_html_namespace, none, none, false, voidptr(0))!
	mut child := dom.create_element_with_registry(document, 'x-widget', scoped_registry_html_namespace, none, none, false, voidptr(0))!
	mut root_node := root.as_node()
	root_node.append_child(child.as_node())!

	registry.initialize(root.as_node())!
	assert root.custom_element_registry() == voidptr(registry)
	assert child.custom_element_registry() == voidptr(registry)
	assert child.ensure_custom_element_reaction_queue().len == 1
}

fn test_shadow_root_accepts_scoped_registry_and_rejects_foreign_global_registry() {
	document, _ := scoped_registry_document()
	scoped_registry := CustomElementRegistry.construct(document)
	mut host := document.create_element('div')!
	shadow_root := host.attach_shadow(dom.ShadowRootInit{
		mode: .open
		custom_element_registry: voidptr(scoped_registry)
	})!
	assert shadow_root.custom_element_registry() == voidptr(scoped_registry)

	other_document := dom.Document.create(dom.URL{ value: 'https://other.test/' })
	other_global_registry := CustomElementRegistry.create(other_document)
	mut other_host := document.create_element('section')!
	if _ := other_host.attach_shadow(dom.ShadowRootInit{
		mode: .open
		custom_element_registry: voidptr(other_global_registry)
	}) {
		assert false
	} else {
		assert err.msg().starts_with('NotSupportedError:')
	}
}

fn test_clone_and_adoption_preserve_scoped_and_retarget_global_registries() {
	source_document, source_global := scoped_registry_document()
	destination_document, destination_global := scoped_registry_document()
	scoped_registry := CustomElementRegistry.construct(source_document)

	scoped_element := dom.create_element_with_registry(source_document, 'x-widget', scoped_registry_html_namespace, none, none, false, voidptr(scoped_registry))!
	scoped_clone := scoped_element.as_node().clone_node(destination_document, false, none)!
	assert scoped_clone.as_element()?.custom_element_registry() == voidptr(scoped_registry)

	global_element := source_document.create_element('x-global')!
	global_clone := global_element.as_node().clone_node(destination_document, false, none)!
	assert global_clone.as_element()?.custom_element_registry() == voidptr(destination_global)
	assert global_element.custom_element_registry() == voidptr(source_global)

	mut mutable_destination := unsafe { &dom.Document(destination_document) }
	mutable_destination.adopt_node(global_element.as_node())
	assert global_element.custom_element_registry() == voidptr(destination_global)

	mutable_destination.adopt_node(scoped_element.as_node())
	assert scoped_element.custom_element_registry() == voidptr(scoped_registry)
}

fn test_creation_and_import_options_validate_and_apply_registries() {
	document, _ := scoped_registry_document()
	scoped_registry := CustomElementRegistry.construct(document)
	if _ := document.create_element_with_options('x-widget', dom.ElementCreationOptions{
		custom_element_registry: voidptr(scoped_registry)
		is_: 'x-built-in'
	}) {
		assert false
	} else {
		assert err.msg().starts_with('NotSupportedError:')
	}

	source_document, _ := scoped_registry_document()
	mut source_root := dom.create_element_with_registry(source_document, 'div', scoped_registry_html_namespace, none, none, false, voidptr(0))!
	mut source_child := dom.create_element_with_registry(source_document, 'span', scoped_registry_html_namespace, none, none, false, voidptr(0))!
	mut source_root_node := source_root.as_node()
	source_root_node.append_child(source_child.as_node())!

	imported := document.import_node_with_options(source_root.as_node(), dom.ImportNodeOptions{
		custom_element_registry: voidptr(scoped_registry)
	})!
	assert imported.as_element()?.custom_element_registry() == voidptr(scoped_registry)
	assert imported.first_child()?.as_element()?.custom_element_registry() == voidptr(scoped_registry)

	self_only := document.import_node_with_options(source_root.as_node(), dom.ImportNodeOptions{
		custom_element_registry: voidptr(scoped_registry)
		self_only: true
	})!
	assert self_only.first_child() == none
}

fn test_declarative_shadow_root_can_keep_its_registry_null_and_serializes_the_marker() {
	document := parse_document('<div id="null"><template shadowrootmode="open" shadowrootserializable shadowrootcustomelementregistry><x-widget></x-widget></template></div><section id="global"><template shadowrootmode="open" shadowrootserializable></template></section>')
	null_host := document.get_element_by_id('null') or { panic('missing null-registry host') }
	null_shadow := null_host.shadow_root() or { panic('missing null-registry shadow root') }
	assert null_shadow.custom_element_registry() == voidptr(0)
	assert null_shadow.keep_custom_element_registry_null()
	null_serialization := null_host.get_html(dom.GetHTMLOptions{ serializable_shadow_roots: true })!
	assert null_serialization.contains('shadowrootcustomelementregistry=""')

	global_host := document.get_element_by_id('global') or { panic('missing global-registry host') }
	global_shadow := global_host.shadow_root() or { panic('missing global-registry shadow root') }
	assert global_shadow.custom_element_registry() == document.custom_element_registry()
	assert !global_host.get_html(dom.GetHTMLOptions{ serializable_shadow_roots: true })!.contains('shadowrootcustomelementregistry')
}
