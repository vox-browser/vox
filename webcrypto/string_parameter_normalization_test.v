// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import math
import webidl
import x.json2

fn test_source_ec_parameter_curve_primitive_to_string_and_omission() {
	expected_values := ['null', 'true', 'false', '4294967296', '1e+21', '0', 'P-256']
	for index, value in [json2.Any(json2.Null{}), json2.Any(true), json2.Any(false),
		json2.Any(f64(4294967296)), json2.Any(f64(1e21)), json2.Any(f64(-0.0)), json2.Any('P-256')] {
		expected := expected_values[index]
		assert EcKeyGenParams.from_value(json2.Any({
			'namedCurve': value
		}))!.named_curve == expected
		assert EcKeyImportParams.from_value(json2.Any({
			'namedCurve': value
		}))!.named_curve == expected
	}
	assert EcKeyGenParams.from_value(json2.Any(map[string]json2.Any{}))!.named_curve == 'undefined'
	assert EcKeyImportParams.from_value(json2.Any(map[string]json2.Any{}))!.named_curve == 'undefined'
	assert EcKeyGenParams.from_value(json2.Any({
		'namedCurve': json2.Any(math.nan())
	}))!.named_curve == 'NaN'
	if _ := EcKeyGenParams.from_value(json2.Any({
		'namedCurve': json2.Any(map[string]json2.Any{})
	})) {
		assert false
	} else {
		assert err.msg() == 'TypeError: namedCurve cannot be converted to a string by this value boundary'
	}
}

fn test_source_hash_algorithm_object_names_and_nested_parameter_validation() {
	if _ := hash_algorithm_identifier_from_value(json2.Any({
		'name': json2.Any(f64(4294967296))
	})) {
		assert false
	} else {
		assert err.msg() == "NotSupportedError: Algorithm '4294967296' is not supported for operation 'digest'"
	}
	if _ := hash_algorithm_identifier_from_value(json2.Any(map[string]json2.Any{})) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Not an object of type Algorithm'
	}
	if _ := hash_algorithm_identifier_from_value(json2.Any('cSHAKE128')) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Required property outputLength is missing or undefined'
	}
	assert hash_algorithm_identifier_from_value(json2.Any({
		'name':         json2.Any('cSHAKE128')
		'outputLength': json2.Any(256)
	}))!.name()! == 'cSHAKE128'
}

fn test_source_binding_nested_digest_read_order_precedes_later_fields() {
	for name, operation in {
		'HMAC': 'generateKey'
		'HKDF': 'deriveBits'
	} {
		if _ := normalize_binding_algorithm(webidl.object_value({
			'name':   webidl.string_value(name)
			'hash':   webidl.string_value('unknown')
			'length': webidl.object_value(map[string]webidl.Value{})
			'salt':   webidl.number_value(1)
		}), operation) {
			assert false
		} else {
			assert err.msg() == "NotSupportedError: Algorithm 'unknown' is not supported for operation 'digest'"
		}
	}
	if _ := normalize_binding_algorithm(webidl.object_value({
		'name':   webidl.string_value('HMAC')
		'hash':   webidl.string_value('cSHAKE128')
		'length': webidl.number_value(0)
	}), 'generateKey') {
		assert false
	} else {
		assert err.msg() == 'TypeError: Required property outputLength is missing or undefined'
	}
	normalized := normalize_binding_algorithm(webidl.object_value({
		'name': webidl.string_value('HMAC')
		'hash': webidl.object_value({
			'name':         webidl.string_value('cSHAKE128')
			'outputLength': webidl.number_value(256)
		})
	}), 'generateKey')!
	assert (normalized.params as HmacKeyGenParams).hash == 'cSHAKE128'
	if _ := normalize_binding_algorithm(webidl.object_value(map[string]webidl.Value{}), 'digest') {
		assert false
	} else {
		assert err.msg() == 'TypeError: Not an object of type Algorithm'
	}
}

@[heap]
struct StringParameterHost {
mut:
	tasks []fn ()
}

fn test_source_curve_name_conversion_defers_unsupported_curve_operation() {
	mut host := &StringParameterHost{}
	binding := SubtleCryptoBinding.create(SubtleCrypto.create(), webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.tasks << task
	}, fn (_ fn ()) {})
	for index, curve in [webidl.undefined_value(), webidl.null_value(), webidl.boolean_value(true),
		webidl.bigint_value(256)] {
		generated := binding.generate_key(webidl.object_value({
			'name':       webidl.string_value('ECDSA')
			'namedCurve': curve
		}), false, [.sign])
		assert generated.state == .pending
		host.tasks[index]()
		assert generated.state == .rejected
		assert generated.result.object_value['name'].string_value == 'NotSupportedError'
		assert generated.result.object_value['message'].string_value == "Only 'P-256', 'P-384' and 'P-521' is supported"
	}
	omitted := binding.generate_key(webidl.string_value('ECDSA'), false, [.sign])
	assert omitted.state == .pending
	host.tasks[4]()
	assert omitted.state == .rejected && omitted.result.object_value['name'].string_value == 'NotSupportedError'
	normalized := normalize_binding_algorithm(webidl.object_value({
		'name':       webidl.string_value('ECDH')
		'namedCurve': webidl.bigint_value(256)
	}), 'importKey')!
	assert (normalized.params as EcKeyImportParams).named_curve == '256'
}
