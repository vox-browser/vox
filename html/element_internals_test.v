module html

import dom

const element_internals_html_namespace = 'http://www.w3.org/1999/xhtml'

fn create_form_associated_custom_element(mut document dom.Document) !(&dom.Element, &dom.HTMLElement) {
	mut element := document.create_element_ns(element_internals_html_namespace, 'x-control')!
	definition := &dom.CustomElementDefinition{
		name_:            'x-control'
		form_associated_: true
	}
	element.setup_custom_element_from_constructor(definition, none)
	return element, unsafe { &dom.HTMLElement(element) }
}

fn test_element_internals_requires_a_form_associated_custom_element() {
	mut document := dom.Document.create(dom.url_about_blank())
	element := document.create_element_ns(element_internals_html_namespace, 'div') or { panic(err) }
	internals := ElementInternals.create(unsafe { &dom.HTMLElement(element) })
	if _ := internals.form() {
		assert false
	} else {
		assert err.msg().starts_with('NotSupportedError:')
	}
}

fn test_element_internals_form_value_validity_labels_and_states() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut root := document.create_element_ns(element_internals_html_namespace, 'div') or {
		panic(err)
	}
	mut form := document.create_element_ns(element_internals_html_namespace, 'form') or {
		panic(err)
	}
	mut label := document.create_element_ns(element_internals_html_namespace, 'label') or {
		panic(err)
	}
	mut element, html_element := create_form_associated_custom_element(mut document) or {
		panic(err)
	}
	element.set_attribute_value('id', 'custom-control')
	label.set_attribute_value('for', 'custom-control')
	mut root_node := root.as_node()
	root_node.append_child(form.as_node()) or { panic(err) }
	mut form_node := form.as_node()
	form_node.append_child(label.as_node()) or { panic(err) }
	form_node.append_child(element.as_node()) or { panic(err) }

	mut internals := ElementInternals.create(html_element)
	internals.control.reset_form_owner()
	actual_form := internals.form() or { panic(err) }
	assert actual_form != unsafe { nil }
	assert voidptr(actual_form) == voidptr(form)
	internals.set_form_value(ElementInternalsValue('submitted'), none) or { panic(err) }
	submission_value := internals.submission_value or { panic('missing submission value') }
	assert submission_value is string

	internals.set_validity(ValidityStateFlags{ custom_error: true }, 'broken', none) or {
		panic(err)
	}
	assert !(internals.check_validity() or { panic(err) })
	assert internals.validation_message() or { panic(err) } == 'broken'
	assert (internals.validity() or { panic(err) }).custom_error()
	assert (internals.labels() or { panic(err) }).len == 1

	mut states := internals.states()
	states.add('checked') or { panic(err) }
	assert states.has_state('checked')
	assert states.modification_count() == 1
	assert states.delete('checked')
}

fn test_element_internals_shadow_root_and_validation_anchor() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut element, html_element := create_form_associated_custom_element(mut document) or {
		panic(err)
	}
	mut shadow := element.attach_shadow(dom.ShadowRootInit{ mode: .closed }) or { panic(err) }
	assert ElementInternals.create(html_element).shadow_root() == none
	shadow.set_available_to_element_internals(true)
	mut internals := ElementInternals.create(html_element)
	assert internals.shadow_root() != none

	child := document.create_element_ns(element_internals_html_namespace, 'span') or { panic(err) }
	mut shadow_node := shadow.as_node()
	shadow_node.append_child(child.as_node()) or { panic(err) }
	internals.set_validity(ValidityStateFlags{}, none, unsafe { &dom.HTMLElement(child) }) or {
		panic(err)
	}
}
