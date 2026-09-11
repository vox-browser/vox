module credentialmanagement

import dom
import html

fn credential_test_find_by_id(node &dom.Node, id string) ?&dom.Element {
	if element := node.as_element() {
		if element.id() or { '' } == id {
			return element
		}
	}
	for child in node.children_as_vector() {
		if element := credential_test_find_by_id(child, id) {
			return element
		}
	}
	return none
}

fn credential_test_add_control(mut form html.HTMLFormElementModel, document &dom.Document, id string) &html.FormAssociatedElement {
	element := credential_test_find_by_id(unsafe { &dom.Node(document) }, id) or {
		panic('missing form control ${id}')
	}
	mut control := html.FormAssociatedElement.create(element)
	control.value_ = element.get_attribute_value('value')
	form.add_control(mut control)
	return control
}

fn test_password_credential_from_dictionary() {
	origin := dom.Origin{
		value: 'https://shop.example'
	}
	credential := PasswordCredential.construct_impl(PasswordCredentialData{
		id: 'alice'
		name: 'Alice Example'
		icon_url: 'https://shop.example/avatar.png'
		password: 'correct horse battery staple'
	}, origin)!
	assert credential.id() == 'alice'
	assert credential.type_() == 'password'
	assert credential.password() == 'correct horse battery staple'
	assert credential.name() == 'Alice Example'
	assert credential.icon_url() == 'https://shop.example/avatar.png'
	assert credential.origin() == origin
	assert credential.as_credential().type_() == 'password'
}

fn test_password_credential_constructor_adapter_uses_relevant_origin() {
	origin := dom.Origin{
		value: 'https://constructor.example'
	}
	credential := PasswordCredential.create_for_constructor(PasswordCredentialData{
		id: 'constructor-user'
		password: 'secret'
	}, origin)!
	assert credential.id() == 'constructor-user'
	assert credential.origin() == origin
}

fn test_password_dictionary_defaults_and_required_validation() {
	origin := dom.Origin{
		value: 'https://example.test'
	}
	credential := create_password_credential(PasswordCredentialData{
		id: 'alice'
		password: 'secret'
	}, origin)!
	assert credential.name() == ''
	assert credential.icon_url() == ''

	if _ := create_password_credential(PasswordCredentialData{
		password: 'secret'
	}, origin) {
		assert false, 'empty id must fail'
	} else {
		assert err.msg() == "TypeError: 'id' must not be empty."
	}
	if _ := create_password_credential(PasswordCredentialData{
		id: 'alice'
	}, origin) {
		assert false, 'empty password must fail'
	} else {
		assert err.msg() == "TypeError: 'password' must not be empty."
	}
}

fn test_password_credential_form_algorithm_and_new_password_precedence() {
	document :=
		html.parse_document('<form id="login"><input id="user" name="account" value="alice" autocomplete="USERNAME"><input id="old" name="oldpass" value="old-secret" autocomplete="current-password"><input id="new" name="newpass" value="new-secret" autocomplete="NEW-PASSWORD"><input id="later" name="laterpass" value="must-not-win" autocomplete="current-password"><input id="display" name="display" value="Alice Example" autocomplete="name"><input id="nick" name="nick" value="Ali" autocomplete="nickname"><input id="avatar" name="avatar" value="https://example.test/alice.png" autocomplete="photo"><input id="disabled" disabled name="ignored" value="mallory" autocomplete="username"><input id="unannotated" name="ignored2" value="also-mallory"></form>')
	form_element := credential_test_find_by_id(unsafe { &dom.Node(document) }, 'login') or {
		panic('missing form')
	}
	mut form := html.HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(form_element) })
	for id in ['user', 'old', 'new', 'later', 'display', 'nick', 'avatar', 'disabled', 'unannotated'] {
		credential_test_add_control(mut form, document, id)
	}

	origin := dom.Origin{
		value: 'https://example.test'
	}
	credential := PasswordCredential.construct_impl_from_form(form, origin)!
	assert credential.id() == 'alice'
	assert credential.password() == 'new-secret'
	assert credential.name() == 'Ali'
	assert credential.icon_url() == 'https://example.test/alice.png'
	assert credential.origin() == origin
}

fn test_password_form_uses_first_form_data_value_for_duplicate_names() {
	document :=
		html.parse_document('<form id="login"><input id="first-user" name="user" value="first" autocomplete="username"><input id="second-user" name="user" value="second" autocomplete="username"><input id="password" name="password" value="secret" autocomplete="current-password"></form>')
	form_element := credential_test_find_by_id(unsafe { &dom.Node(document) }, 'login') or {
		panic('missing form')
	}
	mut form := html.HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(form_element) })
	for id in ['first-user', 'second-user', 'password'] {
		credential_test_add_control(mut form, document, id)
	}
	credential := create_password_credential_from_form(form, dom.Origin{
		value: 'https://example.test'
	})!
	// FormData.get(name) returns the first entry for the name, even while the
	// algorithm visits the later field.
	assert credential.id() == 'first'
	assert credential.password() == 'secret'
}

fn test_password_form_without_username_or_password_rethrows_validation() {
	document :=
		html.parse_document('<form id="login"><input id="plain" name="plain" value="x"></form>')
	form_element := credential_test_find_by_id(unsafe { &dom.Node(document) }, 'login') or {
		panic('missing form')
	}
	mut form := html.HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(form_element) })
	credential_test_add_control(mut form, document, 'plain')
	if _ := create_password_credential_from_form(form, dom.Origin{ value: 'https://example.test' }) {
		assert false, 'missing credential tokens must fail'
	} else {
		assert err.msg() == "TypeError: 'id' must not be empty."
	}
}
