module storageapi

import url as liburl

fn test_source_storage_key_keeps_typed_opaque_nonce_and_exact_same_origin_equality() {
	origin := liburl.Origin.create_opaque(.standard)
	actual := obtain_a_storage_key_for_origin(origin)
	assert actual.origin.opaque_data()?.nonce == origin.opaque_data()?.nonce
	assert actual.equals(StorageKey{ origin: origin })
	assert !actual.equals(obtain_a_storage_key_for_origin(liburl.Origin.create_opaque(.standard)))
	assert actual.to_string() == 'null'
	assert obtain_a_storage_key(StorageEnvironment{ origin: origin }) == none
}

fn test_source_storage_key_file_override_does_not_mutate_non_storage_origin_owner() {
	origin := liburl.Origin.create_opaque(.file)
	non_storage := obtain_a_storage_key_for_non_storage_purposes(StorageEnvironment{ origin: origin })
	assert non_storage.origin.is_same_origin(origin)
	assert non_storage.origin.is_opaque_file_origin()
	assert non_storage.equals(obtain_a_storage_key_for_origin(origin))
	actual := obtain_a_storage_key(StorageEnvironment{ origin: origin })?
	assert actual.to_string() == 'file://'
	assert !actual.origin.is_opaque()
	assert actual.equals(obtain_a_storage_key_for_origin(liburl.parse('file:///tmp/key-owner')?.origin())) == false
	tuple := actual.origin
	if tuple is liburl.OriginTuple {
		assert tuple.scheme? == 'file' && tuple.host.serialize() == ''
		assert tuple.port == none && tuple.domain == none
	} else {
		assert false
	}
	assert non_storage.origin.is_opaque_file_origin()
	assert non_storage.origin.opaque_data()?.nonce == origin.opaque_data()?.nonce
}

fn test_source_environment_overload_uses_settings_origin_or_actual_creation_url_each_time() {
	settings_origin := liburl.Origin.create_opaque(.standard)
	creation := liburl.parse('https://different-creation-owner.test:8443/page')?
	settings := obtain_a_storage_key_for_non_storage_purposes(StorageEnvironment{
		origin:       settings_origin
		creation_url: creation
	})
	assert settings.origin.is_same_origin(settings_origin)
	assert !settings.origin.is_same_origin(creation.origin())
	snapshot := StorageEnvironment{
		origin:             settings_origin
		creation_url:       creation
		is_settings_object: false
	}
	assert obtain_a_storage_key_for_non_storage_purposes(snapshot).origin.is_same_origin(creation.origin())
	opaque_creation := StorageEnvironment{
		origin:             settings_origin
		creation_url:       liburl.parse('data:text/plain,actual-creation-owner')?
		is_settings_object: false
	}
	first := obtain_a_storage_key_for_non_storage_purposes(opaque_creation)
	second := obtain_a_storage_key_for_non_storage_purposes(opaque_creation)
	assert first.origin.is_opaque() && second.origin.is_opaque()
	assert !first.equals(second)
	assert obtain_a_storage_key(opaque_creation) == none
}

fn test_source_tuple_storage_key_preserves_port_domain_and_disabled_storage_fixme() {
	origin := liburl.Origin.tuple('https', liburl.Host.from_string('key-owner.test'), u16(8443),
		'actual-key-domain.test')
	actual := obtain_a_storage_key(StorageEnvironment{ origin: origin, storage_disabled: true })?
	assert actual.to_string() == 'https://key-owner.test:8443'
	assert actual.equals(obtain_a_storage_key_for_origin(origin))
	assert !actual.equals(obtain_a_storage_key_for_origin(liburl.parse('https://key-owner.test:9443/page')?.origin()))
	assert !actual.equals(obtain_a_storage_key_for_origin(liburl.parse('https://other-key-owner.test:8443/page')?.origin()))
	value := actual.origin
	if value is liburl.OriginTuple {
		assert value.port? == 8443 && value.domain? == 'actual-key-domain.test'
	} else {
		assert false
	}
}
