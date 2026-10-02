// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import encoding.hex
import webidl

fn test_ec_public_generation_matches_upstream_libcrypto_curve_vectors() {
	d256 := hex.decode('0000000000000000000000000000000000000000000000000000000000000001')!
	point256 := native_ec_public('P-256', d256)!
	expected256 := hex.decode('046b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c2964fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5')!
	assert point256.x == expected256[1..33]
	assert point256.y == expected256[33..]
	assert native_ec_valid('P-256', point256, d256)!
	d384 := hex.decode('000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001')!
	point384 := native_ec_public('P-384', d384)!
	expected384 := hex.decode('04aa87ca22be8b05378eb1c71ef320ad746e1d3b628ba79b9859f741e082542a385502f25dbf55296c3a545e3872760ab73617de4a96262c6f5d9e98bf9292dc29f8f41dbd289a147ce9da3113b5f0b8c00a60b1ce1d7e819d7a431d7c90ea0e5f')!
	assert point384.x == expected384[1..49]
	assert point384.y == expected384[49..]
	assert native_ec_valid('P-384', point384, d384)!
	d521 := hex.decode('000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001')!
	point521 := native_ec_public('P-521', d521)!
	expected521 := hex.decode('0400c6858e06b70404e9cd9e3ecb662395b4429c648139053fb521f828af606b4d3dbaa14b5e77efe75928fe1dc127a2ffa8de3348b3c1856a429bf97e7e31c2e5bd66011839296a789a3bc0045c8a5fb42c7d1bd998f54449579b446817afbd17273e662c97ee72995ef42640c550b9013fad0761353c7086a272c24088be94769fd16650')!
	assert point521.x == expected521[1..67]
	assert point521.y == expected521[67..]
	assert native_ec_valid('P-521', point521, d521)!
}

fn test_ec_generation_native_points_key_metadata_and_serialization() {
	for curve in ['P-256', 'P-384', 'P-521'] {
		for name in ['ECDSA', 'ECDH'] {
			usages := if name == 'ECDSA' {
				[KeyUsage.verify, .sign, .sign]
			} else {
				[KeyUsage.derive_bits, .derive_key, .derive_bits]
			}
			pair := SubtleCrypto.create().generate_key(EcKeyGenParams{ name: name.to_lower(), named_curve: curve }, false, usages)!.pair or { panic('pair') }
			assert pair.public_key.type_ == .public_key && pair.public_key.extractable
			assert pair.private_key.type_ == .private_key && !pair.private_key.extractable
			algorithm := pair.private_key.algorithm as EcKeyAlgorithm
			assert algorithm.name == name && algorithm.named_curve == curve
			point := pair.public_key.internal_handle() as EcPublicKeyHandle
			private_key := pair.private_key.internal_handle() as EcPrivateKeyHandle
			assert point.x.len == ec_scalar_size(curve) && point.y.len == point.x.len && private_key.d.len == point.x.len
			assert native_ec_valid(curve, point, private_key.d)!
			assert private_key.public_key or { panic('point') } == point
			assert pair.public_key.usages == if name == 'ECDSA' {
				[KeyUsage.verify]
			} else {
				[]KeyUsage{}
			}
			assert pair.private_key.usages == normalize_key_usages_for_operation(usages.filter(it != .verify))
			assert deserialize_handle(serialize_handle(private_key))! as EcPrivateKeyHandle == private_key
			mut invalid := EcPublicKeyHandle{ x: []u8{len: point.x.len}, y: []u8{len: point.y.len} }
			assert !native_ec_valid(curve, invalid, none)!
			other := native_ec_generate(curve)!
			assert !native_ec_valid(curve, point, other.d)!
		}
	}
}

fn test_ec_generation_validates_source_usage_before_curve() {
	if _ := ECDSA.create().generate_key(EcKeyGenParams{ name: 'ECDSA', named_curve: 'bad' }, true, [.decrypt]) {
		assert false
	} else {
		assert err.msg() == "SyntaxError: Invalid key usage 'decrypt'"
	}
	if _ := ECDH.create().generate_key(EcKeyGenParams{ name: 'ECDH', named_curve: 'bad' }, true, [.derive_bits]) {
		assert false
	} else {
		assert err.msg() == "NotSupportedError: Only 'P-256', 'P-384' and 'P-521' is supported"
	}
	if _ := SubtleCrypto.create().generate_key(EcKeyGenParams{ name: 'ECDSA', named_curve: 'P-256' }, true, [.verify]) {
		assert false
	} else {
		assert err.msg() == 'SyntaxError: usages must not be empty'
	}
}

@[heap]
struct EcGenerationBindingHost {
mut:
	work   []fn ()
	settle []fn ()
}

fn test_ec_binding_generation_copies_curve_before_deferred_work() {
	mut host := &EcGenerationBindingHost{}
	binding := SubtleCryptoBinding.create(SubtleCrypto.create(), webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn [mut host] (task fn ()) { host.settle << task })
	mut members := {
		'name':       webidl.string_value('ECDH')
		'namedCurve': webidl.string_value('P-384')
	}
	promise := binding.generate_key(webidl.object_value(members), false, [.derive_bits])
	members['namedCurve'] = webidl.string_value('bad')
	assert promise.state == .pending
	host.work[0]()
	assert promise.state == .fulfilled
	private_key := crypto_key_from_value(promise.result.object_value['privateKey'])!
	assert (private_key.algorithm as EcKeyAlgorithm).named_curve == 'P-384'
	assert native_ec_valid('P-384', (private_key.internal_handle() as EcPrivateKeyHandle).public_key or { panic('point') }, (private_key.internal_handle() as EcPrivateKeyHandle).d)!
}
