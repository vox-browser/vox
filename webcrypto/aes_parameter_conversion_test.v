// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import math
import webidl
import x.json2

fn test_aes_source_primitive_numeric_modulo_and_truncation() {
	for value in [json2.Any(i64(384)), json2.Any(f64(384.9)), json2.Any(f64(-128.9)), json2.Any('0x180'),
		json2.Any('0b110000000'), json2.Any('0o600'), json2.Any('\u2000384\ufeff')] {
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
	for value in [json2.Any(i64(65664)), json2.Any(f64(65664.9)), json2.Any(f64(-65408.9)),
		json2.Any('0x10080')] {
		assert AesKeyGenParams.from_value(json2.Any({
			'length': value
		}))!.length == u16(128)
		assert AesDerivedKeyParams.from_value(json2.Any({
			'length': value
		}))!.length == u16(128)
	}
	for value in [json2.Any(json2.Null{}), json2.Any(false), json2.Any(math.nan()), json2.Any(math.inf(1)),
		json2.Any('invalid'), json2.Any(''), json2.Any('Infinity')] {
		assert AesKeyGenParams.from_value(json2.Any({
			'length': value
		}))!.length == u16(0)
	}
	assert AesKeyGenParams.from_value(json2.Any(map[string]json2.Any{}))!.length == u16(0)
	assert AesCtrParams.from_value(json2.Any({
		'counter': json2.Any([]json2.Any{})
		'length':  json2.Any(true)
	}))!.length == u8(1)
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
		'length': webidl.string_value('0x10080')
	}), true, [.encrypt])
	assert generated.state == .pending
	host.work[0]()
	assert generated.state == .fulfilled
	key := crypto_key_from_value(generated.result)!
	assert (key.algorithm as AesKeyAlgorithm).length == u16(128)
	params := {
		'name':      webidl.string_value('AES-GCM')
		'iv':        webidl.buffer_source_value(webidl.BufferSource.array_buffer([]u8{len: 12}))
		'tagLength': webidl.number_value(384.9)
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
	assert undefined_tag.state == .pending
	host.work[2]()
	host.settle[1]()
	assert undefined_tag.state == .rejected
	assert undefined_tag.result.object_value['message'].string_value == 'Invalid tag length'
	mut undefined_aad_params := params.clone()
	undefined_aad_params['additionalData'] = webidl.undefined_value()
	undefined_aad := binding.encrypt(webidl.object_value(undefined_aad_params), key,
		webidl.BufferSource.array_buffer([]))
	assert undefined_aad.state == .rejected
	assert host.work.len == 3
	omitted_length := binding.generate_key(webidl.object_value({
		'name': webidl.string_value('AES-GCM')
	}), false, [.encrypt])
	assert omitted_length.state == .pending
	host.work[3]()
	assert omitted_length.state == .rejected
	assert omitted_length.result.object_value['message'].string_value == 'Cannot create AES-GCM key with unusual amount of 0 bits'
}
