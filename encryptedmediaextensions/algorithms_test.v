module encryptedmediaextensions

import dom

fn clear_key_capability(content_type string) MediaKeySystemMediaCapability {
	return MediaKeySystemMediaCapability{
		content_type:      content_type
		encryption_scheme: 'cenc'
	}
}

fn test_clear_key_system_support_is_exact_and_case_sensitive() {
	implementation := ClearKeySystem{}
	assert is_supported_key_system('org.w3.clearkey')
	assert !is_supported_key_system('org.w3.ClearKey')
	assert key_system_from_string('org.w3.clearkey').supports_init_data_type('keyids')
	assert implementation.supports_init_data_type('keyids')
	assert !implementation.supports_init_data_type('cenc')
	assert !implementation.supports_init_data_type('KEYIDS')
	assert implementation.supports_encryption_scheme('cenc')
	assert !implementation.supports_encryption_scheme('cbcs')
	assert implementation.supports_robustness('')
	assert !implementation.supports_robustness('software-secure')
}

fn test_webidl_enum_names_and_conversion_are_exact() {
	assert MediaKeysRequirement.required.webidl_name() == 'required'
	assert MediaKeysRequirement.optional.webidl_name() == 'optional'
	assert MediaKeysRequirement.not_allowed.webidl_name() == 'not-allowed'
	assert media_keys_requirement_from_webidl('not-allowed')! == .not_allowed
	assert media_key_session_type_from_webidl('persistent-license')! == .persistent_license
	if _ := media_keys_requirement_from_webidl('NOT-ALLOWED') {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
}

fn test_persistent_session_type_mapping() {
	assert !is_persistent_session_type(MediaKeySessionType.temporary.webidl_name())
	assert is_persistent_session_type(MediaKeySessionType.persistent_license.webidl_name())
}

fn test_supported_capabilities_reject_empty_content_type_for_whole_sequence() {
	implementation := KeySystem(ClearKeySystem{})
	requested := [
		clear_key_capability('video/webm; codecs="vp9"'),
		MediaKeySystemMediaCapability{},
	]
	assert get_supported_capabilities_for_audio_video_type(implementation, .video, requested, MediaKeySystemConfiguration{}, MediaKeyRestrictions{}) == none
}

fn test_supported_capabilities_parse_and_filter_mime_and_cdm_constraints() {
	implementation := KeySystem(ClearKeySystem{})
	requested := [
		clear_key_capability('not-a-mime'),
		clear_key_capability('text/plain; codecs="vp9"'),
		clear_key_capability('video/webm'),
		MediaKeySystemMediaCapability{
			content_type:      'video/mp4; codecs="avc1.4d401e"'
			encryption_scheme: 'cbcs'
		},
		MediaKeySystemMediaCapability{
			content_type:      'video/mp4; codecs="avc1.4d401e"'
			encryption_scheme: 'cenc'
			robustness:        'unsupported'
		},
		clear_key_capability('VIDEO/MP4; CODECS="avc1.4d401e"'),
	]
	supported := get_supported_capabilities_for_audio_video_type(implementation, .video, requested, MediaKeySystemConfiguration{}, MediaKeyRestrictions{}) or {
		panic('expected one supported capability')
	}
	assert supported.len == 1
	assert supported[0].content_type == 'VIDEO/MP4; CODECS="avc1.4d401e"'
}

fn test_configuration_filters_init_data_and_applies_defaults() {
	implementation := KeySystem(ClearKeySystem{})
	candidate := MediaKeySystemConfiguration{
		label:              'preferred'
		init_data_types:    ['unsupported', 'keyids']
		audio_capabilities: [clear_key_capability('audio/mp4; codecs="mp4a.40.2"')]
	}
	result := get_supported_configuration(implementation, candidate, dom.Origin{
		value: 'https://example.test'
	}) or { panic('configuration should be supported') }
	assert result.status == .allowed
	configuration := result.configuration or { panic('configuration must be present') }
	assert configuration.label == 'preferred'
	assert configuration.init_data_types == ['keyids']
	assert configuration.distinctive_identifier == .not_allowed
	assert configuration.persistent_state == .not_allowed
	assert configuration.session_types or { []string{} } == ['temporary']
	assert configuration.audio_capabilities.len == 1
	assert configuration.video_capabilities.len == 0
}

fn test_configuration_rejects_unsupported_init_data_and_missing_capabilities() {
	implementation := KeySystem(ClearKeySystem{})
	origin := dom.Origin{
		value: 'https://example.test'
	}
	assert get_supported_configuration(implementation, MediaKeySystemConfiguration{
		init_data_types:    ['webm']
		audio_capabilities: [clear_key_capability('audio/webm; codecs="opus"')]
	}, origin) == none
	assert get_supported_configuration(implementation, MediaKeySystemConfiguration{
		init_data_types: ['keyids']
	}, origin) == none
}

fn test_persistent_license_upgrades_optional_persistent_state() {
	implementation := KeySystem(ClearKeySystem{})
	candidate := MediaKeySystemConfiguration{
		video_capabilities: [clear_key_capability('video/webm; codecs="vp9"')]
		session_types:      ['persistent-license']
	}
	result := get_supported_configuration(implementation, candidate, dom.Origin{
		value: 'https://example.test'
	}) or { panic('persistent configuration should be supported') }
	configuration := result.configuration or { panic('configuration must be present') }
	assert configuration.persistent_state == .required
	assert configuration.session_types or { []string{} } == ['persistent-license']
}

fn test_restrictions_downgrade_optional_requirements_and_reject_persistence() {
	implementation := KeySystem(ClearKeySystem{})
	mut restrictions := MediaKeyRestrictions{
		distinctive_identifiers: false
		persist_state:           false
	}
	origin := dom.Origin{
		value: 'https://example.test'
	}
	nonpersistent := get_supported_configuration_and_consent(implementation, MediaKeySystemConfiguration{
		audio_capabilities: [clear_key_capability('audio/webm; codecs="opus"')]
	}, mut restrictions, origin) or { panic('temporary configuration should be supported') }
	configuration := nonpersistent.configuration or { panic('configuration must be present') }
	assert configuration.distinctive_identifier == .not_allowed
	assert configuration.persistent_state == .not_allowed

	assert get_supported_configuration_and_consent(implementation, MediaKeySystemConfiguration{
		video_capabilities: [clear_key_capability('video/webm; codecs="vp9"')]
		session_types:      ['persistent-license']
	}, mut restrictions, origin) == none
}
