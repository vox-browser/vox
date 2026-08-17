module encryptedmediaextensions

fn access_test_capability(content_type string) MediaKeySystemMediaCapability {
	return MediaKeySystemMediaCapability{
		content_type:      content_type
		encryption_scheme: 'cenc'
	}
}

fn test_media_key_system_access_exposes_idl_attributes_and_copies_configuration() {
	configuration := MediaKeySystemConfiguration{
		label:              'clear-key'
		init_data_types:    ['keyids']
		video_capabilities: [access_test_capability('video/webm; codecs="vp9"')]
		session_types:      ['temporary']
	}
	access := MediaKeySystemAccess.create('org.w3.clearkey', configuration,
		KeySystem(ClearKeySystem{}))
	assert access.key_system() == 'org.w3.clearkey'
	first := access.get_configuration()
	second := access.get_configuration()
	assert first.label == 'clear-key'
	assert first.init_data_types == ['keyids']
	assert first.session_types or { []string{} } == ['temporary']
	assert first.init_data_types.data != second.init_data_types.data
	assert access.cdm_implementation().supports_init_data_type('keyids')
}

fn test_media_key_system_access_create_media_keys_preserves_upstream_fixme() {
	access := MediaKeySystemAccess.create('org.w3.clearkey', MediaKeySystemConfiguration{},
		KeySystem(ClearKeySystem{}))
	promise := access.create_media_keys()
	assert promise.state() == .rejected
	assert promise.value() == none
	assert promise.reason() == 'NotSupportedError: createMediaKeys is not implemented'
}
