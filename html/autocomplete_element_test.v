module html

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

	credential :=
		parse_autocomplete_attribute('section-login username webauthn', .expectation, none)
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
