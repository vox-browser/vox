module html

import dom
import url

fn test_source_csp_policy_projection_preserves_real_opaque_nonce_and_file_origin_type() {
	for prefix in ['opaque:', 'opaque-file:'] {
		original := dom.origin_from_ipc(prefix + '0102030405060708090a0b0c0d0e0f10')
		other := dom.origin_from_ipc(prefix + '100f0e0d0c0b0a090807060504030201')
		first := parse_response_csp_policy("img-src 'self'", .enforce, original)
		second := parse_response_csp_policy("script-src 'none'", .report, other)
		projected := fetch_csp_policy_list([first, second])
		assert projected.policies.len == 2
		for index, expected in [original, other] {
			actual := projected.policies[index].self_origin?
			data := actual.opaque_data()?
			mut nonce := [16]u8{}
			for i in 0 .. 16 { nonce[i] = u8(if index == 0 { i + 1 } else { 16 - i }) }
			assert data.nonce == nonce
			assert actual.is_opaque_file_origin() == (prefix == 'opaque-file:')
			assert expected.serialize_for_ipc().starts_with(prefix)
		}
		assert !projected.policies[0].self_origin?.is_same_origin(projected.policies[1].self_origin?)
		assert projected.policies[0].source() == .header
		assert projected.policies[1].disposition() == .report
		assert first.self_origin.serialize_for_ipc() == original.serialize_for_ipc()
		assert projected.policies[0].pre_parsed_policy_string() == "img-src 'self'"
	}
}

fn test_source_csp_projection_copies_tuple_fields_without_url_reparse_normalization() {
	original := dom.origin_from_tuple('https', 'tuple-origin.test', u16(443))
	policy := parse_response_csp_policy("base-uri 'self'", .enforce, original)
	projected := fetch_csp_policy_list([policy])
	actual := projected.policies[0].self_origin?
	expected := url.Origin.tuple('https', url.Host.from_string('tuple-origin.test'), u16(443), none)
	assert actual.is_same_origin(expected)
	assert actual.serialize() == 'https://tuple-origin.test:443'
	assert policy.self_origin.serialize() == 'https://tuple-origin.test:443'
}

fn test_legacy_csp_origin_adapter_retains_its_explicit_unowned_opaque_fallback() {
	projected := fetch_csp_policy_list([SerializedCSPPolicy{ self_origin: dom.Origin{ value: 'opaque' } }])
	actual := projected.policies[0].self_origin?
	assert actual.opaque_data()?.nonce == [16]u8{}
	assert !actual.is_opaque_file_origin()
}
