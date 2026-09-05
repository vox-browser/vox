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
	mut registry := CustomElementRegistry.create(document)
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
