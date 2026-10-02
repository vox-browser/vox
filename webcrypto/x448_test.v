module webcrypto

import encoding.hex
import webidl

const x448_alice_private_key = '9a8f4925d1519f5775cf46b04b5800d4ee9ee8bae8bc5565d498c28dd9c9baf574a9419744897391006382a6f127ab1d9ac2d8c0a598726b'
const x448_alice_public_key = '9b08f7cc31b7e3e67d22d5aea121074a273bd2b83de09c63faa73d2c22c5d9bbc836647241d953d40c5b12da88120d53177f80e532c41fa0'
const x448_bob_private_key = '1c306a7ac2a0e2e0990b294470cba339e6453772b075811d8fad0d1d6927c120bb5ee8972b0d3e21374c9c921b09d1b0366f10b65173992d'
const x448_bob_public_key = '3eb7a829b0cd20f5bcfc0b599b6feccf6da4627107bdb0d4f345b43027d8b972fc3e34fb4232a13ca706dcb57aec3dae07bdc1c67bf33609'
const x448_shared_secret = '07fff4181ac6cc95ec1c16a94a0f74d12da232ce40a77552281d282bb60c0b56fd2464c335543936521c24403085d59a449a5037514a879d'

fn x448_jwk(private_hex string, public_hex string) JsonWebKey {
	return JsonWebKey{ kty: 'OKP', crv: 'X448', x: base64url_encode(hex.decode(public_hex) or { panic(err) }), d: base64url_encode(hex.decode(private_hex) or { panic(err) }) }
}

fn test_x448_upstream_rfc7748_vector_and_truncation() {
	subtle := SubtleCrypto.create()
	alice := subtle.import_jwk(x448_jwk(x448_alice_private_key, x448_alice_public_key), 'x448', true, [
		.derive_bits,
		.derive_key,
	], '')!
	bob := subtle.import_jwk(x448_jwk(x448_bob_private_key, x448_bob_public_key), 'X448', true, [.derive_bits], '')!
	alice_public := subtle.import_key(.raw, hex.decode(x448_alice_public_key)!, 'X448', true, [], '')!
	bob_public := subtle.import_key(.raw, hex.decode(x448_bob_public_key)!, 'X448', true, [], '')!
	params := EcdhKeyDeriveParams{ name: 'X448', public_key: bob_public }
	assert subtle.derive_bits(params, alice, none)!.hex() == x448_shared_secret
	assert subtle.derive_bits(EcdhKeyDeriveParams{ name: 'x448', public_key: alice_public }, bob, 448)!.hex() == x448_shared_secret
	assert subtle.derive_bits(params, alice, 0)!.len == 0
	assert subtle.derive_bits(params, alice, 9)!.hex() == '0780'
	assert subtle.derive_bits(params, alice, 447)!.last() == 0x9c
	if _ := subtle.derive_bits(params, alice, 449) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Secret is too short'
	}
	assert subtle.derive_key(params, alice, 'AES-CTR', 256, true, [.encrypt])!.handle().hex() == x448_shared_secret[..64]
}

fn test_x448_source_formats_generation_and_errors() {
	subtle := SubtleCrypto.create()
	pair := subtle.generate_key(AlgorithmParams{ name: 'x448' }, false, [.derive_key, .derive_bits])!.pair or { panic('pair') }
	assert pair.private_key.handle().len == 56
	assert pair.public_key.handle() == native_edwards_public('X448', pair.private_key.handle())!
	assert pair.public_key.extractable && pair.public_key.usages.len == 0
	assert !pair.private_key.extractable
	assert pair.private_key.internal_handle() is OkpPrivateKeyHandle
	private_key := subtle.import_jwk(x448_jwk(x448_alice_private_key, x448_alice_public_key), 'X448', true, [.derive_bits], '')!
	public_key := subtle.import_key(.raw, hex.decode(x448_alice_public_key)!, 'X448', true, [], '')!
	assert subtle.export_key(.spki, public_key)!.hex() == '3042300506032b656f033900' + x448_alice_public_key
	assert subtle.export_key(.pkcs8, private_key)!.hex() == '3046020100300506032b656f043a0438' + x448_alice_private_key
	assert subtle.import_key(.spki, subtle.export_key(.spki, public_key)!, 'X448', true, [], '')!.handle() == public_key.handle()
	assert subtle.import_key(.pkcs8, subtle.export_key(.pkcs8, private_key)!, 'X448', true, [.derive_bits], '')!.handle() == private_key.handle()
	jwk := subtle.export_jwk(private_key)!
	assert jwk.alg == none
	assert (jwk.x or { '' }) == base64url_encode(public_key.handle())
	assert (jwk.d or { '' }) == base64url_encode(private_key.handle())
	if _ := subtle.import_key(.raw_public, hex.decode(x448_alice_public_key)!, 'X448', true, [], '') {
		assert false
	} else {
		assert err.msg() == 'NotSupportedError: Invalid key format'
	}
	if _ := subtle.export_key(.raw_public, public_key) {
		assert false
	} else {
		assert err.msg() == 'NotSupportedError: Invalid key format'
	}
	if _ := subtle.import_jwk(JsonWebKey{ ...jwk, x: base64url_encode([]u8{len: 56}) }, 'X448', true, [.derive_bits], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid key pair'
	}
	if _ := subtle.import_key(.raw, []u8{len: 55}, 'X448', true, [], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid key length'
	}
	if _ := subtle.import_key(.pkcs8, [], 'X448', true, [.verify], '') {
		assert false
	} else {
		assert err.msg() == "SyntaxError: Invalid key usage 'verify'"
	}
	zero := subtle.import_key(.raw, []u8{len: 56}, 'X448', true, [], '')!
	if _ := subtle.derive_bits(EcdhKeyDeriveParams{ name: 'X448', public_key: zero }, private_key, none) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Failed to compute secret'
	}
}

@[heap]
struct X448BindingHost {
mut:
	work []fn ()
}

fn test_x448_promise_import_copies_bytes_and_derivation_executes_in_deferred_work() {
	mut host := &X448BindingHost{}
	binding := SubtleCryptoBinding.create(SubtleCrypto.create(), webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn (task fn ()) { task() })
	mut buffer := webidl.BufferSource.array_buffer(hex.decode(x448_bob_public_key)!)
	imported := binding.import_key(.raw, webidl.buffer_source_value(buffer), webidl.string_value('X448'), true, [])
	buffer.write([]u8{len: 56}, 0)!
	assert imported.state == .pending
	host.work[0]()
	assert imported.state == .fulfilled
	public_key := crypto_key_from_value(imported.result)!
	assert public_key.handle().hex() == x448_bob_public_key
	private_key := SubtleCrypto.create().import_jwk(x448_jwk(x448_alice_private_key, x448_alice_public_key), 'X448', true, [.derive_bits], '')!
	bits := binding.derive_bits(webidl.object_value({
		'name':   webidl.string_value('X448')
		'public': crypto_key('', public_key)
	}), private_key, none)
	assert bits.state == .pending
	host.work[1]()
	assert bits.state == .fulfilled
	assert webidl.get_buffer_source_copy(bits.result.buffer_value or { panic('bits') }).hex() == x448_shared_secret
}
