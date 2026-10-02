// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of CredentialManagement/PasswordCredentialOperations.{h,cpp}.
module credentialmanagement

import dom
import html

fn string_form_data_value(entries []html.FormDataEntry, name string) ?string {
	for entry in entries {
		if entry.name != name {
			continue
		}
		if entry.value is string {
			return entry.value
		}
		return none
	}
	return none
}

fn form_data_has(entries []html.FormDataEntry, name string) bool {
	for entry in entries {
		if entry.name == name {
			return true
		}
	}
	return false
}

// https://www.w3.org/TR/credential-management-1/#abstract-opdef-create-a-passwordcredential-from-an-htmlformelement
pub fn create_password_credential_from_form(form &html.HTMLFormElementModel, origin dom.Origin) !&PasswordCredential {
	// The translated HTMLFormElement's entry-list construction is the same
	// observable data source as invoking FormData(form) upstream.
	form_data := form.construct_entry_list_with_encoding(none, none) or {
		return error('InvalidStateError: form entry list construction is already in progress')
	}
	mut data := PasswordCredentialData{}
	mut new_password_observed := false

	for field in form.controls() {
		autocomplete := field.element.get_attribute('autocomplete') or { continue }
		if autocomplete == '' {
			continue
		}
		name := field.element.get_attribute('name') or { continue }
		if !form_data_has(form_data, name) {
			continue
		}

		for raw_token in autocomplete.split(' ') {
			token := raw_token.to_lower()
			match token {
				'new-password' {
					if value := string_form_data_value(form_data, name) {
						data.password = value
						new_password_observed = true
					}
				}
				'current-password' {
					if !new_password_observed {
						if value := string_form_data_value(form_data, name) {
							data.password = value
						}
					}
				}
				'photo' {
					if value := string_form_data_value(form_data, name) {
						data.icon_url = value
					}
				}
				'name', 'nickname' {
					if value := string_form_data_value(form_data, name) {
						data.name = value
					}
				}
				'username' {
					if value := string_form_data_value(form_data, name) {
						data.id = value
					}
				}
				else {}
			}
		}
	}

	return create_password_credential(data, origin)
}

// https://www.w3.org/TR/credential-management-1/#abstract-opdef-create-a-passwordcredential-from-passwordcredentialdata
pub fn create_password_credential(data PasswordCredentialData, origin dom.Origin) !&PasswordCredential {
	if data.id == '' {
		return error("TypeError: 'id' must not be empty.")
	}
	if data.password == '' {
		return error("TypeError: 'password' must not be empty.")
	}
	return PasswordCredential.create(data, origin)
}
