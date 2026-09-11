module credentialmanagement

import dom

fn test_conditional_mediation_is_resolved_false() {
	promise := Credential.is_conditional_mediation_available()
	assert promise.state() == .fulfilled
	assert promise.result().kind == .boolean
	assert !promise.result().boolean_data
	assert Credential.is_conditional_mediation_available_impl().state() == .fulfilled
}

fn test_federated_credential_copies_all_idl_members_and_origin() {
	credential := FederatedCredential.construct_impl(FederatedCredentialInit{
		id: 'alice@example.test'
		name: 'Alice'
		icon_url: 'https://idp.example.test/alice.png'
		provider: 'https://idp.example.test/login?client=browser'
		protocol: 'openidconnect'
	})!
	assert credential.id() == 'alice@example.test'
	assert credential.type_() == 'federated'
	assert credential.name() == 'Alice'
	assert credential.icon_url() == 'https://idp.example.test/alice.png'
	assert credential.provider() == 'https://idp.example.test/login?client=browser'
	assert credential.protocol()? == 'openidconnect'
	assert credential.origin().serialize() == 'https://idp.example.test'
	assert credential.as_credential().id() == credential.id()
	assert credential.as_credential().type_() == 'federated'
}

fn test_federated_optional_user_data_defaults_to_empty() {
	credential := create_federated_credential(FederatedCredentialInit{
		id: 'account'
		provider: 'https://accounts.example/'
	})!
	assert credential.name() == ''
	assert credential.icon_url() == ''
	assert credential.protocol() == none
	assert credential.origin().serialize() == 'https://accounts.example'
}

fn test_federated_constructor_rejects_empty_required_members() {
	if _ := create_federated_credential(FederatedCredentialInit{
		provider: 'https://accounts.example/'
	}) {
		assert false, 'empty id must fail'
	} else {
		assert err.msg() == "TypeError: 'id' must not be empty."
	}

	if _ := create_federated_credential(FederatedCredentialInit{
		id: 'account'
	}) {
		assert false, 'empty provider must fail'
	} else {
		assert err.msg() == "TypeError: 'provider' must not be empty."
	}
}

fn test_federated_constructor_rejects_non_url_provider() {
	for provider in ['relative/path', 'not a URL'] {
		if _ := create_federated_credential(FederatedCredentialInit{
			id: 'account'
			provider: provider
		}) {
			assert false, 'relative provider must fail'
		} else {
			assert err.msg().starts_with('SyntaxError:')
		}
	}
}

fn test_federated_request_options_preserve_lists() {
	options := FederatedCredentialRequestOptions{
		providers: ['https://one.test', 'https://two.test']
		protocols: ['openidconnect', 'saml']
	}
	assert options.providers? == ['https://one.test', 'https://two.test']
	assert options.protocols? == ['openidconnect', 'saml']

	credential_data := CredentialData{
		id: 'typed-record'
	}
	assert credential_data.id == 'typed-record'
	assert dom.PromiseState.fulfilled == Credential.is_conditional_mediation_available().state()
}
