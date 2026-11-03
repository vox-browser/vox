module html

import dom

__global custom_element_reported_exceptions = []string{}

fn custom_element_exception_reporter(message string) {
	custom_element_reported_exceptions << message
}

fn custom_registry_find(node &dom.Node, name string) ?&dom.Element {
	if element := node.as_element() {
		if element.local_name() == name {
			return element
		}
	}
	for child in node.children_as_vector() {
		if element := custom_registry_find(child, name) {
			return element
		}
	}
	return none
}

fn test_custom_element_registry_define_get_when_defined_and_upgrade() {
	mut document :=
		parse_document('<x-widget observed="yes"></x-widget><button is="x-button"></button>')
	mut registry := unsafe { &CustomElementRegistry(document.custom_element_registry()) }
	pending := registry.when_defined('x-widget')
	assert pending.state() == .pending
	registry.define('x-widget', CustomElementConstructor{
		id:                  42
		observed_attributes: ['observed']
		lifecycle_callbacks: ['connectedCallback', 'attributeChangedCallback']
		disabled_features:   ['shadow']
		form_associated:     true
		exception_reporter:  custom_element_exception_reporter
	}, ElementDefinitionOptions{})!
	assert registry.get('x-widget')? == 42
	assert registry.get_name(42)? == 'x-widget'
	assert registry.get_definition_from_new_target(42)?.name() == 'x-widget'
	assert registry.get_definition_from_new_target(999) == none
	assert pending.state() == .fulfilled
	definition := registry.get_definition_with_name_and_local_name('x-widget', 'x-widget')?
	assert definition.form_associated()
	assert definition.disable_shadow()
	assert definition.observed_attributes == ['observed']
	assert definition.constructor() == 42
	assert definition.lifecycle_callbacks() == ['connectedCallback', 'attributeChangedCallback']
	custom_element_reported_exceptions.clear()
	definition.report_constructor_exception('constructor failed')
	assert custom_element_reported_exceptions == ['constructor failed']
	widget := custom_registry_find(unsafe { &dom.Node(document) }, 'x-widget')?
	assert widget.ensure_custom_element_reaction_queue().len == 1

	registry.define('x-button', CustomElementConstructor{ id: 84 }, ElementDefinitionOptions{
		extends: 'button'
	})!
	button := custom_registry_find(unsafe { &dom.Node(document) }, 'button')?
	assert button.ensure_custom_element_reaction_queue().len == 1
	assert registry.definition_count() == 2
}

fn test_custom_element_registry_canonicalizes_lifecycle_callback_order() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	mut registry := CustomElementRegistry.create(document)
	registry.define('x-ordered', CustomElementConstructor{
		id: 91
		lifecycle_callbacks: ['adoptedCallback', 'attributeChangedCallback', 'connectedMoveCallback',
			'connectedCallback']
	}, ElementDefinitionOptions{})!
	definition := registry.get_definition_with_name_and_local_name('x-ordered', 'x-ordered')?
	assert definition.lifecycle_callbacks() == [
		'connectedCallback',
		'connectedMoveCallback',
		'adoptedCallback',
		'attributeChangedCallback',
	]
}

fn test_custom_element_registry_rejects_invalid_duplicates_and_unknown_extensions() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	mut registry := CustomElementRegistry.create(document)
	assert registry.when_defined('invalid').state() == .rejected
	if _ := registry.define('invalid', CustomElementConstructor{ id: 1 }, ElementDefinitionOptions{}) {
		assert false
	} else {
		assert err.msg().starts_with('SyntaxError:')
	}
	registry.define('x-one', CustomElementConstructor{ id: 1 }, ElementDefinitionOptions{})!
	if _ := registry.define('x-two', CustomElementConstructor{ id: 1 }, ElementDefinitionOptions{}) {
		assert false
	} else {
		assert err.msg().starts_with('NotSupportedError:')
	}
	if _ := registry.define('x-three', CustomElementConstructor{ id: 3 }, ElementDefinitionOptions{
		extends: 'not-a-real-tag'
	})
	{
		assert false
	} else {
		assert err.msg().starts_with('NotSupportedError:')
	}
}

fn test_custom_element_definition_lookup_uses_explicit_registry() {
	document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	mut first := CustomElementRegistry.create(document)
	second := CustomElementRegistry.create(document)
	first.define('x-widget', CustomElementConstructor{ id: 7 }, ElementDefinitionOptions{})!

	assert dom.look_up_custom_element_definition(voidptr(first), 'http://www.w3.org/1999/xhtml', 'x-widget', none)?.constructor() == 7
	assert dom.look_up_custom_element_definition(voidptr(second), 'http://www.w3.org/1999/xhtml', 'x-widget', none) == none
	assert dom.look_up_custom_element_definition(voidptr(first), 'http://www.w3.org/2000/svg', 'x-widget', none) == none
	assert dom.look_up_custom_element_definition(voidptr(0), 'http://www.w3.org/1999/xhtml', 'x-widget', none) == none
}

fn test_create_element_retains_and_uses_documents_registry() {
	document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	mut registry := CustomElementRegistry.create(document)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_custom_element_registry(voidptr(registry))
	registry.define('x-widget', CustomElementConstructor{ id: 11 }, ElementDefinitionOptions{})!

	element := dom.create_element(document, 'x-widget', 'http://www.w3.org/1999/xhtml', none, none, false)!
	assert element.custom_element_registry() == voidptr(registry)
	assert !element.is_defined()
	assert element.ensure_custom_element_reaction_queue().len == 1

	svg_element := dom.create_element(document, 'circle', 'http://www.w3.org/2000/svg', none, none, false)!
	assert svg_element.custom_element_registry() == voidptr(registry)
}

fn test_custom_element_registry_metadata_runs_under_guard_and_recovers_after_throw() {
	mut document := parse_document('<!doctype html><x-outer></x-outer>')
	defer { document.finalize() }
	mut registry := CustomElementRegistry.create(document)
	mut observed := &CustomElementDefinitionGuardObservation{}
	registry.define_with_metadata('x-outer', CustomElementConstructor{ id: 700 }, ElementDefinitionOptions{}, fn [mut registry, mut observed] (_ CustomElementConstructor) !CustomElementConstructor {
		registry.define('x-inner', CustomElementConstructor{ id: 701 }, ElementDefinitionOptions{}) or {
			observed.rejected = err.msg().starts_with('NotSupportedError:')
		}
		return error('author getter exception')
	}) or { assert err.msg() == 'author getter exception' }
	assert observed.rejected
	assert registry.definition_count() == 0
	registry.define('x-inner', CustomElementConstructor{ id: 701 }, ElementDefinitionOptions{})!
	assert registry.get('x-inner')? == 701
	mut read := &CustomElementDefinitionGuardObservation{}
	registry.define_with_metadata('x-inner', CustomElementConstructor{ id: 702 }, ElementDefinitionOptions{}, fn [mut read] (_ CustomElementConstructor) !CustomElementConstructor {
		read.rejected = true
		return CustomElementConstructor{ id: 702 }
	}) or { assert err.msg().starts_with('NotSupportedError:') }
	assert !read.rejected
}

@[heap]
struct CustomElementDefinitionGuardObservation {
mut:
	rejected bool
}
