module html

import dom

fn test_autocomplete_processing_model() {
	missing := parse_autocomplete_attribute(none, .expectation, none)
	assert missing.field_name == 'on'
	assert missing.value == ''

	off := parse_autocomplete_attribute('OFF', .expectation, none)
	assert off.field_name == 'off'
	assert off.value == 'off'

	anchor_off := parse_autocomplete_attribute('off', .anchor, none)
	assert anchor_off.field_name == ''
	assert anchor_off.value == ''

	contact := parse_autocomplete_attribute('section-blue shipping home TEL', .expectation, none)
	assert contact.field_name == 'TEL'
	assert contact.scope == ['section-blue', 'shipping', 'home']
	assert contact.hint_set == ['home', 'shipping']
	assert contact.value == 'section-blue shipping home tel'

	credential := parse_autocomplete_attribute('section-login username webauthn', .expectation, none)
	assert credential.field_name == 'webauthn'
	assert credential.credential_type? == 'webauthn'
	assert credential.scope == ['section-login']
	assert credential.value == 'section-login username webauthn'
}

fn test_invalid_autocomplete_uses_form_default() {
	details := parse_autocomplete_attribute('shipping impossible', .expectation, 'off')
	assert details.field_name == 'off'
	assert details.value == ''
}

fn test_autocomplete_element_getter_setter_and_mantle() {
	document := parse_document('<form autocomplete="off"><input id="visible"><input id="hidden" type="hidden" autocomplete="section-token"></form>')
	visible_element := document.get_element_by_id('visible') or { panic('missing visible input') }
	hidden_element := document.get_element_by_id('hidden') or { panic('missing hidden input') }
	visible := AutocompleteElement.create(unsafe { &dom.HTMLElement(visible_element) })
	hidden := AutocompleteElement.create(unsafe { &dom.HTMLElement(hidden_element) })
	assert visible.get_autofill_mantle() == .expectation
	assert visible.autocomplete() == ''
	assert hidden.get_autofill_mantle() == .anchor
	assert hidden.autocomplete() == ''
	visible.set_autocomplete('shipping email')
	assert visible_element.get_attribute_value('autocomplete') == 'shipping email'
	assert visible.autocomplete() == 'shipping email'
	assert visible.autocomplete_tokens() == ['shipping', 'email']
	details := visible.parse_autocomplete_attribute()
	assert details.scope == ['shipping']
	assert details.field_name == 'email'
	assert details.value == 'shipping email'
}
