module webcrypto

import encoding.hex
import webidl

const x25519_alice_private = '77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a'
const x25519_alice_public = '8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a'
const x25519_bob_private = '5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb'
const x25519_bob_public = 'de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f'
const x25519_shared = '4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742'

fn x25519_private_jwk(private_hex string, public_hex string) JsonWebKey {
	return JsonWebKey{ kty: 'OKP', crv: 'X25519', x: base64url_encode(hex.decode(public_hex) or { panic(err) }), d: base64url_encode(hex.decode(private_hex) or { panic(err) }) }
}

fn test_x25519_rfc7748_vectors_and_bit_length_rules_through_subtle_dispatch() {
	// The vectors are also upstream Tests/LibCrypto/TestCurves.cpp fixtures.
	subtle := SubtleCrypto.create()
	alice := subtle.import_jwk(x25519_private_jwk(x25519_alice_private, x25519_alice_public), 'x25519', true, [
		.derive_bits,
		.derive_key,
	], '')!
	bob := subtle.import_jwk(x25519_private_jwk(x25519_bob_private, x25519_bob_public), 'X25519', true, [.derive_bits], '')!
	alice_public := subtle.import_key(.raw_public, hex.decode(x25519_alice_public)!, 'X25519', true, [], '')!
	bob_public := subtle.import_key(.raw, hex.decode(x25519_bob_public)!, 'X25519', true, [], '')!
	params := EcdhKeyDeriveParams{ name: 'x25519', public_key: bob_public }
	assert subtle.derive_bits(params, alice, none)!.hex() == x25519_shared
	assert subtle.derive_bits(EcdhKeyDeriveParams{ name: 'X25519', public_key: alice_public }, bob, 256)!.hex() == x25519_shared
	assert subtle.derive_bits(params, alice, 0)!.len == 0
	assert subtle.derive_bits(params, alice, 9)!.hex() == '4a00'
	assert subtle.derive_bits(params, alice, 255)!.hex() == x25519_shared
	if _ := subtle.derive_bits(params, alice, 257) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Length is too large'
	}
	derived := subtle.derive_key(params, alice, 'AES-GCM', 128, true, [.encrypt])!
	assert derived.handle().hex() == x25519_shared[..32]
	assert alice.internal_handle() is OkpPrivateKeyHandle
	assert bob_public.internal_handle() is OkpPublicKeyHandle
}

fn test_x25519_generation_key_ownership_formats_and_native_roundtrip() {
	subtle := SubtleCrypto.create()
	a := subtle.generate_key(AlgorithmParams{ name: 'X25519' }, false, [.derive_bits, .derive_key])!.pair or { panic('no pair') }
	b := subtle.generate_key(AlgorithmParams{ name: 'x25519' }, true, [.derive_bits])!.pair or { panic('no pair') }
	assert a.public_key.extractable
	assert a.public_key.usages.len == 0
	assert !a.private_key.extractable
	assert a.private_key.usages == [.derive_key, .derive_bits]
	left := subtle.derive_bits(EcdhKeyDeriveParams{ name: 'X25519', public_key: b.public_key }, a.private_key, none)!
	right := subtle.derive_bits(EcdhKeyDeriveParams{ name: 'X25519', public_key: a.public_key }, b.private_key, none)!
	assert left == right
	assert left.len == 32 && left.any(it != 0)
	spki := subtle.export_key(.spki, b.public_key)!
	pkcs8 := subtle.export_key(.pkcs8, b.private_key)!
	assert spki[..12].hex() == '302a300506032b656e032100'
	assert pkcs8[..16].hex() == '302e020100300506032b656e04220420'
	assert subtle.import_key(.spki, spki, 'X25519', true, [], '')!.handle() == b.public_key.handle()
	assert subtle.import_key(.pkcs8, pkcs8, 'X25519', true, [.derive_bits], '')!.handle() == b.private_key.handle()
	jwk := subtle.export_jwk(b.private_key)!
	assert jwk.alg == none
	assert (jwk.x or { '' }) == base64url_encode(b.public_key.handle())
	assert (jwk.d or { '' }) == base64url_encode(b.private_key.handle())
	assert (jwk.key_ops or { [] }) == ['deriveBits']
	assert subtle.import_jwk(jwk, 'X25519', true, [.derive_bits], '')!.handle() == b.private_key.handle()
	if _ := subtle.export_key(.pkcs8, a.private_key) {
		assert false
	} else {
		assert err.msg() == 'InvalidAccessError: Key is not extractable'
	}
}

fn test_x25519_validation_order_and_low_order_native_failures() {
	subtle := SubtleCrypto.create()
	if _ := subtle.import_key(.raw, [], 'X25519', true, [.derive_bits], '') {
		assert false
	} else {
		assert err.msg() == 'SyntaxError: Usages must be empty'
	}
	if _ := subtle.import_key(.raw, [], 'X25519', true, [], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid key length'
	}
	if _ := subtle.import_key(.raw_private, [], 'X25519', true, [.derive_bits], '') {
		assert false
	} else {
		assert err.msg() == 'NotSupportedError: Invalid key format'
	}
	if _ := subtle.generate_key(AlgorithmParams{ name: 'X25519' }, true, [.sign]) {
		assert false
	} else {
		assert err.msg() == "SyntaxError: Invalid key usage 'sign'"
	}
	valid := x25519_private_jwk(x25519_alice_private, x25519_alice_public)
	if _ := subtle.import_jwk(JsonWebKey{ ...valid, x: base64url_encode([]u8{len: 32}) }, 'X25519', true, [.derive_bits], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid key pair'
	}
	if _ := subtle.import_jwk(JsonWebKey{ ...valid, use: 'sig' }, 'X25519', true, [.derive_bits], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid use'
	}
	if _ := subtle.import_jwk(JsonWebKey{ ...valid, ext: false }, 'X25519', true, [.derive_bits], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid extractable'
	}
	if _ := subtle.import_jwk(JsonWebKey{ ...valid, key_ops: ['deriveBits', 'deriveBits'] }, 'X25519', true, [.derive_bits], '') {
		assert false
	} else {
		assert err.msg().starts_with('DataError: Duplicate key operation')
	}
	private_key := subtle.import_jwk(valid, 'X25519', true, [.derive_bits], '')!
	zero := subtle.import_key(.raw, []u8{len: 32}, 'X25519', true, [], '')!
	if _ := subtle.derive_bits(EcdhKeyDeriveParams{ name: 'X25519', public_key: zero }, private_key, 0) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Failed to compute secret'
	}
	if _ := X25519.create().derive_bits(EcdhKeyDeriveParams{ name: 'X25519', public_key: zero }, zero, none) {
		assert false
	} else {
		assert err.msg() == 'InvalidAccessError: Key is not a private key'
	}
	if _ := subtle.derive_bits(EcdhKeyDeriveParams{ name: 'X25519', public_key: private_key }, private_key, none) {
		assert false
	} else {
		assert err.msg() == 'InvalidAccessError: Public key is not a public key'
	}
	wrong_curve := CryptoKey.create(.public_key, true, KeyAlgorithm{ name: 'X448' }, [], []u8{len: 56})
	if _ := subtle.derive_bits(EcdhKeyDeriveParams{ name: 'X25519', public_key: wrong_curve }, private_key, none) {
		assert false
	} else {
		assert err.msg() == 'InvalidAccessError: Algorithm mismatch'
	}
}

fn test_x25519_der_exact_data_and_source_inner_scope_behavior() {
	subtle := SubtleCrypto.create()
	public_bytes := hex.decode(x25519_alice_public)!
	mut spki := hex.decode('302a300506032b656e032100' + x25519_alice_public)!
	assert subtle.import_key(.spki, spki, 'X25519', true, [], '')!.handle() == public_bytes
	spki << u8(0)
	if _ := subtle.import_key(.spki, spki, 'X25519', true, [], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Not all bytes were consumed during the parsing phase'
	}
	wrong_oid := hex.decode('302a300506032b656f032100' + x25519_alice_public)!
	if _ := subtle.import_key(.spki, wrong_oid, 'X25519', true, [], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid algorithm'
	}
	bits := hex.decode('302a300506032b656e032101' + x25519_alice_public)!
	if _ := subtle.import_key(.spki, bits, 'X25519', true, [], '') {
		assert false
	} else {
		assert err.msg().starts_with('DataError:')
	}
	// Upstream Certificate::parse_algorithm_identifier leaves the no-parameter
	// scope without reading remaining bytes. Keep this behavior source-exact.
	with_null := hex.decode('302c300706032b656e0500032100' + x25519_alice_public)!
	assert subtle.import_key(.spki, with_null, 'X25519', true, [], '')!.handle() == public_bytes
	// The source DER branches do not add the raw/JWK key-length validation.
	short := hex.decode('300b300506032b656e03020001')!
	assert subtle.import_key(.spki, short, 'X25519', true, [], '')!.handle() == [u8(1)]
	bad_version := hex.decode('302e020101300506032b656e04220420' + x25519_alice_private)!
	if _ := subtle.import_key(.pkcs8, bad_version, 'X25519', true, [.derive_bits], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid version value'
	}
	inner_trailing := hex.decode('302f020100300506032b656e04230420' + x25519_alice_private + '00')!
	if _ := subtle.import_key(.pkcs8, inner_trailing, 'X25519', true, [.derive_bits], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Not all bytes were consumed during the parsing phase'
	}
}

@[heap]
struct X25519PromiseHost {
mut:
	work   []fn ()
	settle []fn ()
	jobs   []fn ()
}

fn test_x25519_async_binding_captures_public_key_and_queues_promise_reactions() {
	mut host := &X25519PromiseHost{}
	binding := SubtleCryptoBinding.create(SubtleCrypto.create(), webidl.PromiseContext{
		job_scheduler: fn [mut host] (job fn ()) { host.jobs << job }
	}, fn [mut host] (task fn ()) { host.work << task }, fn [mut host] (task fn ()) {
		host.settle << task
	})
	subtle := SubtleCrypto.create()
	private_key := subtle.import_jwk(x25519_private_jwk(x25519_alice_private, x25519_alice_public), 'X25519', true, [.derive_bits], '')!
	public_key := subtle.import_key(.raw, hex.decode(x25519_bob_public)!, 'X25519', true, [], '')!
	mut properties := {
		'name':   webidl.string_value('x25519')
		'public': crypto_key('', public_key)
	}
	algorithm := webidl.object_value(properties)
	mut promise := binding.derive_bits(algorithm, private_key, none)
	properties['public'] = crypto_key('', private_key)
	child := promise.upon_fulfillment(fn (value webidl.Value) !webidl.Value { return value })
	assert promise.state == .pending
	host.work[0]()
	// Source deriveBits resolves in deferred work, without an additional crypto task.
	assert promise.state == .fulfilled && host.settle.len == 0
	assert webidl.get_buffer_source_copy(promise.result.buffer_value or { panic('buffer') }).hex() == x25519_shared
	assert child.state == .pending && host.jobs.len == 1
	host.jobs[0]()
	assert child.state == .fulfilled
	bad := binding.derive_bits(webidl.string_value('X25519'), private_key, none)
	assert bad.state == .rejected
	assert bad.result.object_value['name'].string_value == 'TypeError'
	generated := binding.generate_key(webidl.string_value('X25519'), true, [.derive_bits])
	host.work[1]()
	assert generated.state == .fulfilled
	assert crypto_key_from_value(generated.result.object_value['publicKey'])!.algorithm_name() == 'X25519'
}
