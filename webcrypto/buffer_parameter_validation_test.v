// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import webidl
import x.json2

fn test_source_optional_context_and_nullish_oaep_label_validation() {
	assert RsaOaepParams.from_value(json2.Any(map[string]json2.Any{}))!.label.len == 0
	assert RsaOaepParams.from_value(json2.Any({
		'label': json2.Any(json2.Null{})
	}))!.label.len == 0
	assert Ed448Params.from_value(json2.Any(map[string]json2.Any{}))!.context == none
	for value in [json2.Any(true), json2.Any(i64(0)), json2.Any(map[string]json2.Any{})] {
		if _ := RsaOaepParams.from_value(json2.Any({
			'label': value
		})) {
			assert false
		} else {
			assert err.msg() == 'TypeError: Not an object of type BufferSource'
		}
	}
	if _ := Ed448Params.from_value(json2.Any({
		'context': json2.Any(json2.Null{})
	})) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Not an object of type BufferSource'
	}
}

fn test_source_binding_buffer_presence_precedes_later_numeric_fields() {
	for algorithm, operation in {
		'AES-CTR': 'encrypt'
		'AES-GCM': 'encrypt'
		'PBKDF2':  'deriveBits'
	} {
		numeric := if algorithm == 'AES-CTR' {
			'length'
		} else if algorithm == 'AES-GCM' {
			'tagLength'
		} else {
			'iterations'
		}
		if _ := normalize_binding_algorithm(webidl.object_value({
			'name':  webidl.string_value(algorithm)
			numeric: webidl.object_value(map[string]webidl.Value{})
		}), operation) {
			assert false
		} else {
			assert err.msg() == 'TypeError: Not an object of type BufferSource'
		}
	}
	for name in ['Ed448', 'ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87'] {
		for value in [webidl.undefined_value(), webidl.null_value(), webidl.platform_object_value()] {
			if _ := normalize_binding_algorithm(webidl.object_value({
				'name':    webidl.string_value(name)
				'context': value
			}), 'sign') {
				assert false
			} else {
				assert err.msg() == 'TypeError: Not an object of type BufferSource'
			}
		}
	}
	for value in [webidl.undefined_value(), webidl.null_value()] {
		normalized := normalize_binding_algorithm(webidl.object_value({
			'name':  webidl.string_value('RSA-OAEP')
			'label': value
		}), 'encrypt')!
		assert (normalized.params as RsaOaepParams).label.len == 0
	}
	if _ := normalize_binding_algorithm(webidl.object_value({
		'name':  webidl.string_value('RSA-OAEP')
		'label': webidl.number_value(1)
	}), 'encrypt') {
		assert false
	} else {
		assert err.msg() == 'TypeError: Not an object of type BufferSource'
	}
}

fn test_source_rsa_exponent_requires_uint8_array_brand_and_copies_view_bytes() {
	for kind in [webidl.BufferSourceKind.array_buffer, .data_view, .int8_array, .uint8_clamped_array,
		.uint16_array, .float32_array] {
		source := if kind == .array_buffer {
			webidl.BufferSource.array_buffer([])
		} else {
			webidl.BufferSource.view(kind, [], 0, 0)!
		}
		if _ := normalize_binding_algorithm(webidl.object_value({
			'name':           webidl.string_value('RSA-PSS')
			'modulusLength':  webidl.number_value(1024)
			'publicExponent': webidl.buffer_source_value(source)
			'hash':           webidl.string_value('SHA-256')
		}), 'generateKey') {
			assert false
		} else {
			assert err.msg() == 'TypeError: Not an object of type Uint8Array'
		}
	}
	source := webidl.BufferSource.view(.uint8_array, [u8(0xff), 1, 0, 1, 0xff], 1, 3)!
	normalized := normalize_binding_algorithm(webidl.object_value({
		'name':           webidl.string_value('RSA-PSS')
		'modulusLength':  webidl.number_value(1024)
		'publicExponent': webidl.buffer_source_value(source)
		'hash':           webidl.string_value('SHA-256')
	}), 'generateKey')!
	assert (normalized.params as RsaHashedKeyGenParams).public_exponent == [u8(1), 0, 1]
}
