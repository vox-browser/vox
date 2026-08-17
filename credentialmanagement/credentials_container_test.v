module credentialmanagement

import dom

fn assert_not_implemented_promise(promise &dom.Promise, operation string) {
	assert promise.state() == .rejected
	assert promise.result().kind == .string
	assert promise.result().string_data == 'InternalError: Not implemented: ${operation}'
}

fn test_credential_request_and_creation_option_defaults() {
	request := CredentialRequestOptions{}
	assert request.mediation == .optional
	assert request.signal == none
	assert request.password == none
	assert request.federated == none

	creation := CredentialCreationOptions{}
	assert creation.mediation == .optional
	assert creation.signal == none
	assert creation.password == none
	assert creation.federated == none
}

fn test_credential_options_retain_partial_dictionary_members() {
	signal := dom.AbortSignal.new()
	password_data := PasswordCredentialData{
		id:       'alice'
		password: 'secret'
	}
	request := CredentialRequestOptions{
		mediation: .required
		signal:    signal
		password:  true
		federated: FederatedCredentialRequestOptions{
			providers: ['https://accounts.example']
		}
	}
	assert request.mediation == .required
	assert request.signal? == signal
	assert request.password? == true
	assert request.federated?.providers? == ['https://accounts.example']

	creation := CredentialCreationOptions{
		mediation: .conditional
		signal:    signal
		password:  PasswordCredentialInit(password_data)
		federated: FederatedCredentialInit{
			id:       'bob'
			provider: 'https://idp.example'
		}
	}
	assert creation.mediation == .conditional
	assert creation.signal? == signal
	assert creation.password? is PasswordCredentialData
	assert creation.federated?.id == 'bob'
}

fn test_credentials_container_methods_match_upstream_rejections() {
	container := CredentialsContainer.construct_impl()
	credential := create_password_credential(PasswordCredentialData{
		id:       'alice'
		password: 'secret'
	}, dom.Origin{
		value: 'https://example.test'
	})!

	assert_not_implemented_promise(container.get(CredentialRequestOptions{}), 'get')
	assert_not_implemented_promise(container.store(credential.as_credential()), 'store')
	assert_not_implemented_promise(container.create(CredentialCreationOptions{}), 'create')
	assert_not_implemented_promise(container.prevent_silent_access(), 'prevent silent access')
}
