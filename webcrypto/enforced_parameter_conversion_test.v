// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import math
import webidl
import x.json2

fn enforced_argon_parameters() map[string]json2.Any {
	return {
		'nonce':       json2.Any('salt1234')
		'parallelism': json2.Any(f64(4.9))
		'memory':      json2.Any('0x20')
		'passes':      json2.Any(f64(3.9))
		'version':     json2.Any(f64(19.9))
	}
}

fn test_source_enforced_parameter_primitive_numbers_fractional_truncation_and_boundaries() {
	argon := Argon2Params.from_value(json2.Any(enforced_argon_parameters()))!
	assert argon.parallelism == 4 && argon.memory == 32 && argon.passes == 3 && argon.version? == u8(19)
	for value in [json2.Any('0x100'), json2.Any(f64(256.9)), json2.Any('\u2000256\ufeff')] {
		assert CShakeParams.from_value(json2.Any({
			'outputLength': value
		}))!.output_length == 256
		assert KmacParams.from_value(json2.Any({
			'outputLength': value
		}))!.output_length == 256
	}
	for value in [json2.Any(f64(-0.9)), json2.Any(json2.Null{}), json2.Any(false)] {
		assert KmacParams.from_value(json2.Any({
			'outputLength': value
		}))!.output_length == 0
	}
	assert CShakeParams.from_value(json2.Any({
		'outputLength': json2.Any(f64(4294967295.9))
	}))!.output_length == 4294967295
	for field in ['parallelism', 'memory', 'passes'] {
		mut fields := enforced_argon_parameters()
		fields[field] = f64(4294967296.9)
		if _ := Argon2Params.from_value(json2.Any(fields)) {
			assert false
		} else {
			assert err.msg() == "TypeError: Number '4294967296' is outside of allowed range of 0 to 4294967295"
		}
	}
	mut fields := enforced_argon_parameters()
	fields['version'] = f64(256.9)
	if _ := Argon2Params.from_value(json2.Any(fields)) {
		assert false
	} else {
		assert err.msg() == "TypeError: Number '256' is outside of allowed range of 0 to 255"
	}
	for value in [json2.Any(math.nan()), json2.Any(math.inf(-1)), json2.Any('not a number')] {
		if _ := CShakeParams.from_value(json2.Any({
			'outputLength': value
		})) {
			assert false
		} else {
			assert err.msg() == 'TypeError: Number must not be NaN or Infinity'
		}
	}
}

fn test_source_enforced_parameters_required_members_and_validation_order() {
	if _ := Argon2Params.from_value(json2.Any({
		'version': json2.Any(f64(256))
	})) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Required property nonce is missing or undefined'
	}
	if _ := Argon2Params.from_value(json2.Any({
		'nonce':  json2.Any('salt1234')
		'memory': json2.Any(math.inf(1))
	})) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Required property parallelism is missing or undefined'
	}
	if _ := Argon2Params.from_value(json2.Any({
		'nonce':       json2.Any('salt1234')
		'parallelism': json2.Any(math.inf(1))
		'version':     json2.Any(f64(256))
	})) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Number must not be NaN or Infinity'
	}
	if _ := CShakeParams.from_value(json2.Any({
		'customization': json2.Any(true)
	})) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Required property outputLength is missing or undefined'
	}
	if _ := KmacParams.from_value(json2.Any({
		'outputLength':  json2.Any(f64(4294967296))
		'customization': json2.Any(true)
	})) {
		assert false
	} else {
		assert err.msg() == "TypeError: Number '4294967296' is outside of allowed range of 0 to 4294967295"
	}
	if _ := CShakeParams.from_value(json2.Any({
		'outputLength':  json2.Any(256)
		'functionName':  json2.Any(json2.Null{})
		'customization': json2.Any(true)
	})) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Not an object of type BufferSource'
	}
	if _ := KmacParams.from_value(json2.Any({
		'outputLength':  json2.Any(256)
		'customization': json2.Any(json2.Null{})
	})) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Not an object of type BufferSource'
	}
}

@[heap]
struct EnforcedParameterHost {
mut:
	work   []fn ()
	settle []fn ()
}

fn test_source_enforced_binding_real_argon2_output_and_explicit_undefined_members() {
	mut host := &EnforcedParameterHost{}
	subtle := SubtleCrypto.create()
	binding := SubtleCryptoBinding.create(subtle, webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn [mut host] (task fn ()) { host.settle << task })
	key := subtle.import_key(.raw_secret, []u8{len: 32, init: 1}, 'Argon2id', false, [.derive_bits], '')!
	mut fields := {
		'name':           webidl.string_value('Argon2id')
		'nonce':          webidl.buffer_source_value(webidl.BufferSource.array_buffer([]u8{len: 16, init: 2}))
		'parallelism':    webidl.number_value(4.9)
		'memory':         webidl.string_value('0x20')
		'passes':         webidl.number_value(3.9)
		'version':        webidl.number_value(19.9)
		'secretValue':    webidl.buffer_source_value(webidl.BufferSource.array_buffer([]u8{len: 8, init: 3}))
		'associatedData': webidl.buffer_source_value(webidl.BufferSource.array_buffer([]u8{len: 12, init: 4}))
	}
	derived := binding.derive_bits(webidl.object_value(fields), key, 256)
	assert derived.state == .pending
	host.work[0]()
	assert derived.state == .fulfilled
	assert webidl.get_buffer_source_copy(derived.result.buffer_value or { panic('bits') }).hex() == '0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659'
	for field in ['parallelism', 'memory', 'passes', 'version'] {
		mut changed := fields.clone()
		changed[field] = webidl.undefined_value()
		failed := binding.derive_bits(webidl.object_value(changed), key, 256)
		assert failed.state == .rejected
		assert failed.result.object_value['message'].string_value == 'Number must not be NaN or Infinity'
	}
	for field in ['secretValue', 'associatedData'] {
		mut changed := fields.clone()
		changed[field] = webidl.undefined_value()
		failed := binding.derive_bits(webidl.object_value(changed), key, 256)
		assert failed.state == .rejected
		assert failed.result.object_value['message'].string_value == 'Not an object of type BufferSource'
	}
	for field in ['outputLength', 'functionName', 'customization'] {
		mut changed := {
			'name':         webidl.string_value('cSHAKE128')
			'outputLength': webidl.number_value(256)
		}
		changed[field] = webidl.undefined_value()
		failed := binding.digest(webidl.object_value(changed), webidl.BufferSource.array_buffer([]))
		assert failed.state == .rejected
		assert failed.result.object_value['message'].string_value == if field == 'outputLength' {
			'Number must not be NaN or Infinity'
		} else {
			'Not an object of type BufferSource'
		}
	}
	assert host.work.len == 1
	digest := binding.digest(webidl.object_value({
		'name':         webidl.string_value('cSHAKE128')
		'outputLength': webidl.null_value()
	}), webidl.BufferSource.array_buffer([]))
	host.work[1]()
	assert digest.state == .pending && host.settle.len == 1
	host.settle[0]()
	assert digest.state == .fulfilled && webidl.get_buffer_source_copy(digest.result.buffer_value or { panic('digest') }).len == 0
}
