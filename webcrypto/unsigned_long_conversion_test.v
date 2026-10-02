// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import math
import webidl
import x.json2

fn test_source_unsigned_long_primitive_conversion_for_rsa_kdf_mac() {
	for value in [json2.Any(f64(4294967305.9)), json2.Any(f64(-4294967287.9)),
		json2.Any('0x100000009'), json2.Any('\u20004294967305\ufeff')] {
		assert RsaKeyGenParams.from_value(json2.Any({
			'modulusLength':  value
			'publicExponent': json2.Any([]json2.Any{})
		}))!.modulus_length == 9
		assert RsaHashedKeyGenParams.from_value(json2.Any({
			'modulusLength':  value
			'publicExponent': json2.Any([]json2.Any{})
			'hash':           json2.Any('SHA-256')
		}))!.modulus_length == 9
		assert RsaPssParams.from_value(json2.Any({
			'saltLength': value
		}))!.salt_length == 9
		assert PBKDF2Params.from_value(json2.Any({
			'salt':       json2.Any([]json2.Any{})
			'iterations': value
			'hash':       json2.Any('SHA-256')
		}))!.iterations == 9
		assert HmacKeyGenParams.from_value(json2.Any({
			'length': value
			'hash':   json2.Any('SHA-256')
		}))!.length? == 9
		assert HmacImportParams.from_value(json2.Any({
			'length': value
			'hash':   json2.Any('SHA-256')
		}))!.length? == 9
		assert KmacKeyGenParams.from_value(json2.Any({
			'length': value
		}))!.length? == 9
		assert KmacImportParams.from_value(json2.Any({
			'length': value
		}))!.length? == 9
	}
	for value in [json2.Any(json2.Null{}), json2.Any(false), json2.Any(math.nan()),
		json2.Any(math.inf(1)), json2.Any('not a number'), json2.Any('')] {
		assert RsaPssParams.from_value(json2.Any({
			'saltLength': value
		}))!.salt_length == 0
		assert KmacKeyGenParams.from_value(json2.Any({
			'length': value
		}))!.length? == 0
		assert HmacImportParams.from_value(json2.Any({
			'length': value
			'hash':   json2.Any('SHA-256')
		}))!.length? == 0
	}
	for value in [json2.Any(int(9)), json2.Any(i8(9)), json2.Any(i16(9)), json2.Any(i32(9)),
		json2.Any(u8(9)), json2.Any(u16(9)), json2.Any(u32(9)), json2.Any(u64(9)), json2.Any(f32(9))] {
		assert RsaPssParams.from_value(json2.Any({
			'saltLength': value
		}))!.salt_length == 9
	}
	assert KmacKeyGenParams.from_value(json2.Any(map[string]json2.Any{}))!.length == none
	assert HmacImportParams.from_value(json2.Any({
		'hash': json2.Any('SHA-256')
	}))!.length == none
	assert RsaPssParams.from_value(json2.Any(map[string]json2.Any{}))!.salt_length == 0
	assert RsaKeyGenParams.from_value(json2.Any({
		'publicExponent': json2.Any([]json2.Any{})
	}))!.modulus_length == 0
	assert PBKDF2Params.from_value(json2.Any({
		'salt': json2.Any([]json2.Any{})
		'hash': json2.Any('SHA-256')
	}))!.iterations == 0
}

fn test_source_unsigned_long_parameters_retain_read_order() {
	if _ := PBKDF2Params.from_value(json2.Any({
		'iterations': json2.Any(map[string]json2.Any{})
		'hash':       json2.Any('unknown')
	})) {
		assert false
	} else {
		assert err.msg() == 'TypeError: salt must be a buffer source'
	}
	if _ := PBKDF2Params.from_value(json2.Any({
		'salt':       json2.Any([]json2.Any{})
		'iterations': json2.Any(map[string]json2.Any{})
		'hash':       json2.Any('unknown')
	})) {
		assert false
	} else {
		assert err.msg() == 'TypeError: iterations cannot be converted to a number by this value boundary'
	}
	if _ := RsaHashedKeyGenParams.from_value(json2.Any({
		'modulusLength': json2.Any(map[string]json2.Any{})
		'hash':          json2.Any('unknown')
	})) {
		assert false
	} else {
		assert err.msg() == 'TypeError: modulusLength cannot be converted to a number by this value boundary'
	}
	if _ := RsaHashedKeyGenParams.from_value(json2.Any({
		'modulusLength': json2.Any(1024)
		'hash':          json2.Any('unknown')
	})) {
		assert false
	} else {
		assert err.msg() == 'TypeError: publicExponent must be a buffer source'
	}
}

@[heap]
struct UnsignedLongHost {
mut:
	work   []fn ()
	settle []fn ()
}

fn test_source_unsigned_long_binding_deferral_and_explicit_undefined_length() {
	mut host := &UnsignedLongHost{}
	subtle := SubtleCrypto.create()
	binding := SubtleCryptoBinding.create(subtle, webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn [mut host] (task fn ()) { host.settle << task })
	key := subtle.import_key(.raw, 'password'.bytes(), 'PBKDF2', false, [.derive_bits], '')!
	mut salt := webidl.BufferSource.array_buffer('salt'.bytes())
	derived := binding.derive_bits(webidl.object_value({
		'name':       webidl.string_value('PBKDF2')
		'hash':       webidl.string_value('SHA-256')
		'salt':       webidl.buffer_source_value(salt)
		'iterations': webidl.number_value(4294967297.9)
	}), key, 160)
	salt.write('xxxx'.bytes(), 0)!
	assert derived.state == .pending
	host.work[0]()
	assert derived.state == .fulfilled
	assert webidl.get_buffer_source_copy(derived.result.buffer_value or { panic('bits') }).hex() == '120fb6cffcf8b32c43e7225256c4f837a86548c9'
	for index, name in ['HMAC', 'KMAC128'] {
		mut members := {
			'name':   webidl.string_value(name)
			'length': webidl.undefined_value()
		}
		if name == 'HMAC' { members['hash'] = webidl.string_value('SHA-256') }
		generated := binding.generate_key(webidl.object_value(members), false, [.sign])
		assert generated.state == .pending
		host.work[index + 1]()
		assert generated.state == .rejected
		assert generated.result.object_value['message'].string_value == if name == 'HMAC' {
			'Invalid length'
		} else {
			'Invalid key length'
		}
	}
	invalid := binding.generate_key(webidl.object_value({
		'name':           webidl.string_value('RSA-PSS')
		'modulusLength':  webidl.object_value(map[string]webidl.Value{})
		'publicExponent': webidl.number_value(1)
		'hash':           webidl.string_value('unknown')
	}), false, [.sign])
	assert invalid.state == .rejected
	assert invalid.result.object_value['message'].string_value == 'modulusLength cannot be converted to a number by this value boundary'
	failed_bigint := binding.generate_key(webidl.object_value({
		'name':   webidl.string_value('KMAC128')
		'length': webidl.bigint_value(128)
	}), false, [.sign])
	assert failed_bigint.state == .rejected && failed_bigint.result.object_value['message'].string_value == 'Cannot convert BigInt to number'
	assert host.work.len == 3
}
