// Copyright (c) 2025, Altomani Gianluca <altomanigianluca@gmail.com>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the autofill processing model in Libraries/LibWeb/HTML/AutocompleteElement.cpp.
module html

pub enum AutofillMantle {
	anchor
	expectation
}

pub struct AutocompleteAttributeDetails {
pub mut:
	hint_set        []string
	scope           []string
	field_name      string
	credential_type ?string
	value           string
}

enum AutofillCategory {
	off
	automatic
	normal
	contact
	credential
}

struct CategoryAndMaximumTokens {
	category       ?AutofillCategory
	maximum_tokens ?usize
}

const normal_autofill_fields = ['name', 'honorific-prefix', 'given-name', 'additional-name',
	'family-name', 'honorific-suffix', 'nickname', 'organization-title', 'username', 'new-password',
	'current-password', 'one-time-code', 'organization', 'street-address', 'address-line1',
	'address-line2', 'address-line3', 'address-level4', 'address-level3', 'address-level2',
	'address-level1', 'country', 'country-name', 'postal-code', 'cc-name', 'cc-given-name',
	'cc-additional-name', 'cc-family-name', 'cc-number', 'cc-exp', 'cc-exp-month', 'cc-exp-year',
	'cc-csc', 'cc-type', 'transaction-currency', 'transaction-amount', 'language', 'bday', 'bday-day',
	'bday-month', 'bday-year', 'sex', 'url', 'photo']

const contact_autofill_fields = ['tel', 'tel-country-code', 'tel-national', 'tel-area-code',
	'tel-local', 'tel-local-prefix', 'tel-local-suffix', 'tel-extension', 'email', 'impp']

fn determine_a_field_category(field string) CategoryAndMaximumTokens {
	lowercase_field := ascii_lowercase_string(field)
	if lowercase_field == 'off' {
		return CategoryAndMaximumTokens{.off, usize(1)}
	}
	if lowercase_field == 'on' {
		return CategoryAndMaximumTokens{.automatic, usize(1)}
	}
	if lowercase_field in normal_autofill_fields {
		return CategoryAndMaximumTokens{.normal, usize(3)}
	}
	if lowercase_field in contact_autofill_fields {
		return CategoryAndMaximumTokens{.contact, usize(4)}
	}
	if lowercase_field == 'webauthn' {
		return CategoryAndMaximumTokens{.credential, usize(5)}
	}
	return CategoryAndMaximumTokens{}
}

pub fn autocomplete_tokens(value string) []string {
	mut tokens := []string{}
	mut position := 0
	for position < value.len {
		for position < value.len && is_number_ascii_whitespace(value[position]) {
			position++
		}
		start := position
		for position < value.len && !is_number_ascii_whitespace(value[position]) {
			position++
		}
		if start < position {
			tokens << value[start..position]
		}
	}
	return tokens
}

fn default_autocomplete_details(mantle AutofillMantle, form_autocomplete ?string) AutocompleteAttributeDetails {
	mut details := AutocompleteAttributeDetails{}
	if mantle == .anchor {
		return details
	}
	if form_value := form_autocomplete {
		if form_value == 'off' {
			details.field_name = 'off'
			return details
		}
	}
	details.field_name = 'on'
	return details
}

fn prepend_string(mut values []string, value string) {
	values.insert(0, value)
}

fn add_autofill_hint(mut hints []string, hint string) {
	if hint !in hints {
		hints << hint
	}
}

fn completed_autocomplete_details(hints []string, scope []string, field string, credential ?string, value string) AutocompleteAttributeDetails {
	mut details := AutocompleteAttributeDetails{
		hint_set:   hints
		scope:      scope
		field_name: field
		value:      value
	}
	details.credential_type = credential
	return details
}

// https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#autofill-processing-model
pub fn parse_autocomplete_attribute(attribute ?string, mantle AutofillMantle, form_autocomplete ?string) AutocompleteAttributeDetails {
	value := attribute or { return default_autocomplete_details(mantle, form_autocomplete) }
	tokens := autocomplete_tokens(value)
	if tokens.len == 0 {
		return default_autocomplete_details(mantle, form_autocomplete)
	}

	mut index := tokens.len - 1
	field := tokens[index]
	mut category_and_maximum := determine_a_field_category(field)
	mut category := category_and_maximum.category or {
		return default_autocomplete_details(mantle, form_autocomplete)
	}

	mut maximum_tokens := category_and_maximum.maximum_tokens or {
		return default_autocomplete_details(mantle, form_autocomplete)
	}

	if usize(tokens.len) > maximum_tokens {
		return default_autocomplete_details(mantle, form_autocomplete)
	}
	if category in [.off, .automatic] && mantle == .anchor {
		return default_autocomplete_details(mantle, form_autocomplete)
	}
	if category == .off {
		return AutocompleteAttributeDetails{
			field_name: 'off'
			value:      'off'
		}
	}
	if category == .automatic {
		return AutocompleteAttributeDetails{
			field_name: 'on'
			value:      'on'
		}
	}

	mut scope_tokens := []string{}
	mut hint_tokens := []string{}
	mut credential_type := ?string(none)
	mut idl_value := ascii_lowercase_string(field)

	if category == .credential && ascii_lowercase_string(tokens[index]) == 'webauthn' {
		credential_type = 'webauthn'
		if index == 0 {
			return completed_autocomplete_details(hint_tokens, scope_tokens, field,
				credential_type, idl_value)
		}
		index--
		category_and_maximum = determine_a_field_category(tokens[index])
		category = category_and_maximum.category or {
			return default_autocomplete_details(mantle, form_autocomplete)
		}

		maximum_tokens = category_and_maximum.maximum_tokens or {
			return default_autocomplete_details(mantle, form_autocomplete)
		}

		if category != .normal && category != .contact {
			return default_autocomplete_details(mantle, form_autocomplete)
		}
		if usize(index) > maximum_tokens - 1 {
			return default_autocomplete_details(mantle, form_autocomplete)
		}
		idl_value = '${tokens[index]} ${idl_value}'
	}

	if index > 0 {
		index--
		if category == .contact
			&& ascii_lowercase_string(tokens[index]) in ['home', 'work', 'mobile', 'fax', 'pager'] {
			contact := ascii_lowercase_string(tokens[index])
			prepend_string(mut scope_tokens, contact)
			add_autofill_hint(mut hint_tokens, contact)
			idl_value = '${contact} ${idl_value}'
			if index > 0 {
				index--
				if ascii_lowercase_string(tokens[index]) in ['shipping', 'billing'] {
					mode := ascii_lowercase_string(tokens[index])
					prepend_string(mut scope_tokens, mode)
					add_autofill_hint(mut hint_tokens, mode)
					idl_value = '${mode} ${idl_value}'
					if index > 0 {
						index--
					} else {
						return completed_autocomplete_details(hint_tokens, scope_tokens, field,
							credential_type, idl_value)
					}
				}
			} else {
				return completed_autocomplete_details(hint_tokens, scope_tokens, field,
					credential_type, idl_value)
			}
		} else if ascii_lowercase_string(tokens[index]) in ['shipping', 'billing'] {
			mode := ascii_lowercase_string(tokens[index])
			prepend_string(mut scope_tokens, mode)
			add_autofill_hint(mut hint_tokens, mode)
			idl_value = '${mode} ${idl_value}'
			if index > 0 {
				index--
			} else {
				return completed_autocomplete_details(hint_tokens, scope_tokens, field,
					credential_type, idl_value)
			}
		}
	} else {
		return completed_autocomplete_details(hint_tokens, scope_tokens, field, credential_type,
			idl_value)
	}

	if index != 0 || !ascii_lowercase_string(tokens[index]).starts_with('section-') {
		return default_autocomplete_details(mantle, form_autocomplete)
	}
	section := ascii_lowercase_string(tokens[index])
	prepend_string(mut scope_tokens, section)
	idl_value = '${section} ${idl_value}'
	return completed_autocomplete_details(hint_tokens, scope_tokens, field, credential_type,
		idl_value)
}
