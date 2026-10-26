module fetch

import dom

fn test_native_credentials_flag_follows_mode_tainting_and_embedder_policy() {
	mut request := Request.create()
	request.url_list = [dom.URL{value: 'https://target.example/'}]
	assert request.includes_credentials()
	request.response_tainting = .cors
	assert !request.includes_credentials()
	request.credentials_mode = .include
	assert request.includes_credentials()
	request.credentials_mode = .omit
	assert !request.includes_credentials()
	request.credentials_mode = .include
	request.client_present = true
	request.embedder_policy_credentialless = true
	request.mode = .no_cors
	request.origin = RequestOrigin{is_client: false, origin: dom.Origin{value: 'https://source.example'}}
	assert !request.includes_credentials()
	request.mode = .cors
	assert request.includes_credentials()
}
