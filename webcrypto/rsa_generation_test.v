// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import math.big
import webidl

fn test_rsa_native_generation_preserves_modulus_exponents_crt_and_key_metadata() {
	subtle := SubtleCrypto.create()
	for name in ['RSA-OAEP', 'RSA-PSS', 'RSASSA-PKCS1-v1_5'] {
		usages := if name == 'RSA-OAEP' {
			[KeyUsage.encrypt, .decrypt, .wrap_key, .unwrap_key]
		} else {
			[KeyUsage.verify, .sign, .sign]
		}
		generated := subtle.generate_key(RsaHashedKeyGenParams{
			name:            name
			modulus_length:  1024
			public_exponent: [
				u8(0),
				1,
				0,
				1,
			]
			hash:            'sha-256'
		}, false, usages)!
		pair := generated.pair or { panic('pair') }
		assert pair.public_key.type_ == .public_key && pair.public_key.extractable
		assert pair.private_key.type_ == .private_key && !pair.private_key.extractable
		public_key := pair.public_key.internal_handle() as RsaPublicKeyHandle
		private_key := pair.private_key.internal_handle() as RsaPrivateKeyHandle
		assert private_key.modulus.len == 128 && private_key.modulus[0] & 0x80 != 0
		assert public_key.modulus == private_key.modulus && public_key.public_exponent == [
			u8(1),
			0,
			1,
		]
		p := big.integer_from_radix(private_key.prime1.hex(), 16)!
		q := big.integer_from_radix(private_key.prime2.hex(), 16)!
		n := big.integer_from_radix(private_key.modulus.hex(), 16)!
		assert p * q == n
		assert private_key.private_exponent.len != 0 && private_key.exponent1.len != 0 && private_key.exponent2.len != 0 && private_key.coefficient.len != 0
		algorithm := pair.public_key.algorithm as RsaHashedKeyAlgorithm
		assert algorithm.name == name && algorithm.hash == 'SHA-256' && algorithm.modulus_length == 1024
		assert algorithm.public_exponent == public_key.public_exponent
		assert pair.public_key.usages == normalize_key_usages_for_operation(usages.filter(it in rsa_allowed_usages(name, false)))
		assert pair.private_key.usages == normalize_key_usages_for_operation(usages.filter(it in rsa_allowed_usages(name, true)))
		restored := deserialize_handle(serialize_handle(private_key))! as RsaPrivateKeyHandle
		assert restored == private_key
	}
}

fn test_rsa_generation_rejects_source_usages_before_native_parameters() {
	params := RsaHashedKeyGenParams{ name: 'RSA-OAEP', modulus_length: 64, public_exponent: [u8(1)], hash: 'SHA-256' }
	if _ := RSAOAEP.create().generate_key(params, true, [.sign]) {
		assert false
	} else {
		assert err.msg() == "SyntaxError: Invalid key usage 'sign'"
	}
	if _ := RSAOAEP.create().generate_key(params, true, [.decrypt]) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Invalid RSA key generation parameters'
	}
	if _ := RSAPSS.create().generate_key(params, true, [.sign]) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Invalid RSA key generation parameters'
	}
	if _ := RSASSAPKCS1.create().generate_key(params, true, [.decrypt]) {
		assert false
	} else {
		assert err.msg() == "SyntaxError: Invalid key usage 'decrypt'"
	}
	if _ := SubtleCrypto.create().generate_key(RsaHashedKeyGenParams{ ...params, modulus_length: 512, public_exponent: [u8(3)] }, true, [.encrypt]) {
		assert false
	} else {
		assert err.msg() == 'SyntaxError: usages must not be empty'
	}
}

@[heap]
struct RsaGenerationBindingHost {
mut:
	work   []fn ()
	settle []fn ()
}

fn test_rsa_promise_generation_copies_exponent_and_settles_in_deferred_work() {
	mut host := &RsaGenerationBindingHost{}
	binding := SubtleCryptoBinding.create(SubtleCrypto.create(), webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn [mut host] (task fn ()) { host.settle << task })
	mut exponent := webidl.BufferSource.view(.uint8_array, [u8(0xff), 1, 0, 1, 0xff], 1, 3)!
	algorithm := webidl.object_value({
		'name':           webidl.string_value('RSA-PSS')
		'modulusLength':  webidl.number_value(1024)
		'publicExponent': webidl.buffer_source_value(exponent)
		'hash':           webidl.string_value('SHA-256')
	})
	promise := binding.generate_key(algorithm, true, [.sign, .verify])
	exponent.write([u8(0), 0, 0], 0)!
	assert promise.state == .pending
	host.work[0]()
	assert promise.state == .fulfilled && host.settle.len == 0
	public_key := crypto_key_from_value(promise.result.object_value['publicKey'])!
	private_key := crypto_key_from_value(promise.result.object_value['privateKey'])!
	assert (public_key.algorithm as RsaHashedKeyAlgorithm).public_exponent == [u8(1), 0, 1]
	assert (public_key.internal_handle() as RsaPublicKeyHandle).modulus == (private_key.internal_handle() as RsaPrivateKeyHandle).modulus
}
