// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import math
import webidl
import x.json2

fn test_aes_source_primitive_numeric_range_and_truncation() {
	for value in [json2.Any(i64(128)), json2.Any(f64(128.9)), json2.Any('0x80'),
		json2.Any('0b10000000'), json2.Any('0o200'), json2.Any('\u2000128\ufeff')] {
		assert AesCtrParams.from_value(json2.Any({
			'counter': json2.Any([]json2.Any{})
			'length':  value
		}))!.length == u8(128)
		assert AesGcmParams.from_value(json2.Any({
			'iv':        json2.Any([]json2.Any{})
			'tagLength': value
		}))!.tag_length? == u8(128)
		assert AeadParams.from_value(json2.Any({
			'iv':        json2.Any([]json2.Any{})
			'tagLength': value
		}))!.tag_length? == u8(128)
	}
	for value in [json2.Any(i64(128)), json2.Any(f64(128.9)), json2.Any('0x80')] {
		assert AesKeyGenParams.from_value(json2.Any({
			'length': value
		}))!.length == u16(128)
		assert AesDerivedKeyParams.from_value(json2.Any({
			'length': value
		}))!.length == u16(128)
	}
	for value in [json2.Any(json2.Null{}), json2.Any(false), json2.Any(''), json2.Any(f64(-0.9))] {
		assert AesKeyGenParams.from_value(json2.Any({
			'length': value
		}))!.length == u16(0)
	}
	if _ := AesKeyGenParams.from_value(json2.Any(map[string]json2.Any{})) {
		assert false
	} else {
		assert err.msg().contains('TypeError')
	}
	assert AesCtrParams.from_value(json2.Any({
		'counter': json2.Any([]json2.Any{})
		'length':  json2.Any(true)
	}))!.length == u8(1)
}

fn test_crypto_numeric_parameters_reject_nonfinite_and_out_of_range_without_wrapping() {
	for width in [8, 16, 32] {
		upper := math.pow(2, width)
		for value in [f64(-1), -128.9, upper, upper + 128, math.nan(), math.inf(1), math.inf(-1)] {
			if _ := algorithm_enforce_uint({'value': json2.Any(value)}, 'value', width) {
				assert false, 'accepted ${value} for ${width} bits'
			} else {
				assert err.msg().starts_with('TypeError:')
			}
		}
		assert algorithm_enforce_uint({'value': json2.Any(upper - 0.1)}, 'value', width)! == u32(upper - 1)
	}
}

fn test_aes_source_buffer_reads_precede_numeric_fields() {
	if _ := AesCtrParams.from_value(json2.Any({
		'length': json2.Any(map[string]json2.Any{})
	}))
	{
		assert false
	} else {
		assert err.msg() == 'TypeError: Not an object of type BufferSource'
	}
	if _ := AesGcmParams.from_value(json2.Any({
		'tagLength': json2.Any(map[string]json2.Any{})
	}))
	{
		assert false
	} else {
		assert err.msg() == 'TypeError: Not an object of type BufferSource'
	}
	if _ := AeadParams.from_value(json2.Any({
		'tagLength': json2.Any(map[string]json2.Any{})
	}))
	{
		assert false
	} else {
		assert err.msg() == 'TypeError: Not an object of type BufferSource'
	}
	if _ := AesGcmParams.from_value(json2.Any({
		'iv':             json2.Any([]json2.Any{})
		'additionalData': json2.Any(json2.Null{})
		'tagLength':      json2.Any(map[string]json2.Any{})
	}))
	{
		assert false
	} else {
		assert err.msg() == 'TypeError: Not an object of type BufferSource'
	}
}

@[heap]
struct AesParameterBindingHost {
mut:
	work   []fn ()
	settle []fn ()
}

fn test_aes_binding_source_numeric_conversion_and_undefined_presence() {
	mut host := &AesParameterBindingHost{}
	subtle := SubtleCrypto.create()
	binding := SubtleCryptoBinding.create(subtle, webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn [mut host] (task fn ()) {
		host.settle << task
	})
	generated := binding.generate_key(webidl.object_value({
		'name':   webidl.string_value('AES-GCM')
		'length': webidl.string_value('0x80')
	}), true, [.encrypt])
	assert generated.state == .pending
	host.work[0]()
	assert generated.state == .fulfilled
	key := crypto_key_from_value(generated.result)!
	assert (key.algorithm as AesKeyAlgorithm).length == u16(128)
	params := {
		'name':      webidl.string_value('AES-GCM')
		'iv':        webidl.buffer_source_value(webidl.BufferSource.array_buffer([]u8{len: 12}))
		'tagLength': webidl.number_value(128.9)
	}
	encrypted := binding.encrypt(webidl.object_value(params), key,
		webidl.BufferSource.array_buffer([]))
	host.work[1]()
	assert encrypted.state == .pending
	host.settle[0]()
	assert encrypted.state == .fulfilled
	assert webidl.get_buffer_source_copy(encrypted.result.buffer_value or { panic('bytes') }).len == 16
	mut undefined_tag_params := params.clone()
	undefined_tag_params['tagLength'] = webidl.undefined_value()
	undefined_tag := binding.encrypt(webidl.object_value(undefined_tag_params), key,
		webidl.BufferSource.array_buffer([]))
	assert undefined_tag.state == .rejected
	assert undefined_tag.result.object_value['name'].string_value == 'TypeError'
	mut undefined_aad_params := params.clone()
	undefined_aad_params['additionalData'] = webidl.undefined_value()
	undefined_aad := binding.encrypt(webidl.object_value(undefined_aad_params), key,
		webidl.BufferSource.array_buffer([]))
	assert undefined_aad.state == .rejected
	assert host.work.len == 2
	omitted_length := binding.generate_key(webidl.object_value({
		'name': webidl.string_value('AES-GCM')
	}), false, [.encrypt])
	assert omitted_length.state == .rejected
	assert omitted_length.result.object_value['name'].string_value == 'TypeError'
}
