// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import encoding.hex
import webidl

fn test_ed25519_native_source_rfc8032_vectors_and_typed_seed_handles() {
	subtle := SubtleCrypto.create()
	for vector in ed25519_source_vectors {
		seed := hex.decode(vector.private_hex)!
		private_key := subtle.import_key(.pkcs8, export_okp_der('Ed25519', seed, true), 'Ed25519', true, [.sign], '')!
		public_key := subtle.import_key(.raw_public, hex.decode(vector.public_hex)!, 'Ed25519', true, [.verify], '')!
		message := hex.decode(vector.message_hex)!
		signature := subtle.sign('Ed25519', private_key, message)!
		assert signature.hex() == vector.signature_hex
		assert subtle.verify('Ed25519', public_key, signature, message)!
		assert !subtle.verify('Ed25519', public_key, signature[..63], message)!
		assert private_key.internal_handle() is OkpPrivateKeyHandle && private_key.handle() == seed
		assert public_key.internal_handle() is OkpPublicKeyHandle
		restored := CryptoKey.deserialize(private_key.serialize())!
		assert restored.internal_handle() == private_key.internal_handle()
		assert ed25519_sign(restored, message)! == signature
	}
	generated := generate_ed25519_key(false, [.verify, .sign, .sign])!
	assert generated.public_key.extractable && !generated.private_key.extractable
	assert generated.public_key.usages == [KeyUsage.verify]
	assert generated.private_key.usages == [KeyUsage.sign]
	assert generated.private_key.handle().len == 32 && generated.public_key.handle().len == 32
	assert generated.public_key.handle() == native_edwards_public('Ed25519', generated.private_key.handle())!
	assert ed25519_verify(generated.public_key, ed25519_sign(generated.private_key, [])!, [])!
	if _ := subtle.generate_key(AlgorithmParams{ name: 'Ed25519' }, false, [.verify, .encrypt]) {
		assert false
	} else {
		assert err.msg() == "SyntaxError: Invalid key usage 'encrypt'"
	}
	if _ := subtle.generate_key(AlgorithmParams{ name: 'Ed25519' }, false, [.verify]) {
		assert false
	} else {
		assert err.msg() == 'SyntaxError: usages must not be empty'
	}
	pair := subtle.generate_key(AlgorithmParams{ name: 'Ed25519' }, true, [.sign, .verify])!.pair or { panic('pair') }
	assert pair.public_key.internal_handle() is OkpPublicKeyHandle && pair.private_key.internal_handle() is OkpPrivateKeyHandle
}

fn test_ed25519_source_small_order_blacklist_and_wpt_mixed_order_cases() {
	for point in ed25519_small_order_points {
		key := exchange_key('Ed25519', false, point, false, [])
		assert is_small_order_ed25519_point(point)
		assert !ed25519_verify(key, [], 'hello'.bytes())!
		// The source checks R before asking EVP to validate the public key.
		invalid_key := exchange_key('Ed25519', false, [], false, [])
		assert !ed25519_verify(invalid_key, point, [])!
	}
	assert !is_small_order_ed25519_point([])
	assert !is_small_order_ed25519_point([]u8{len: 32, init: 7})
	for vector in ed25519_wpt_verify_vectors {
		key := SubtleCrypto.create().import_key(.raw, hex.decode(vector.public_hex)!, 'Ed25519', false, [.verify], '')!
		assert ed25519_verify(key, hex.decode(vector.signature_hex)!, hex.decode(vector.message_hex)!)! == vector.verified
	}
}

fn test_ed25519_source_wpt_formats_der_scope_and_jwk_validation() {
	subtle := SubtleCrypto.create()
	private_der := hex.decode(ed25519_wpt_pkcs8)!
	public_der := hex.decode(ed25519_wpt_spki)!
	private_key := subtle.import_key(.pkcs8, private_der, 'Ed25519', true, [.sign], '')!
	public_key := subtle.import_key(.spki, public_der, 'Ed25519', true, [.verify], '')!
	assert subtle.sign('Ed25519', private_key, hex.decode(ed25519_wpt_message)!)!.hex() == ed25519_wpt_signatures
	assert subtle.export_key(.pkcs8, private_key)! == private_der
	assert subtle.export_key(.spki, public_key)! == public_der
	assert subtle.export_key(.raw_public, public_key)! == public_key.handle()
	jwk := subtle.export_jwk(private_key)!
	assert (jwk.alg or { '' }) == 'Ed25519' && (jwk.crv or { '' }) == 'Ed25519'
	assert base64url_decode(jwk.d or { panic('d') })! == private_key.handle()
	assert base64url_decode(jwk.x or { panic('x') })! == public_key.handle()
	assert subtle.import_jwk(JsonWebKey{ ...jwk, alg: 'EdDSA' }, 'Ed25519', true, [.sign], '')!.handle() == private_key.handle()
	class_key := ED25519.create().import_key(AlgorithmParams{}, .jwk, jwk.to_json().bytes(), true, [.sign])!
	assert !class_key.extractable && class_key.usages.len == 0
	if _ := subtle.import_jwk(JsonWebKey{ ...jwk, kty: 'bad', ext: false }, 'Ed25519', true, [.verify], '') {
		assert false
	} else {
		assert err.msg() == "SyntaxError: Invalid key usage 'verify'"
	}
	if _ := subtle.import_jwk(JsonWebKey{ ...jwk, alg: 'bad', ext: false }, 'Ed25519', true, [.sign], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid algorithm'
	}
	if _ := subtle.import_jwk(JsonWebKey{ ...jwk, use: 'sign', ext: false }, 'Ed25519', true, [.sign], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid key usage'
	}
	if _ := subtle.import_jwk(JsonWebKey{ ...jwk, ext: false }, 'Ed25519', true, [.sign], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid extractable'
	}
	if _ := subtle.export_key(.raw, private_key) {
		assert false
	} else {
		assert err.msg() == 'InvalidAccessError: Key is not a public key'
	}
	if _ := ED25519.create().import_key(AlgorithmParams{}, .raw_seed, private_key.handle(), false, [.sign]) {
		assert false
	} else {
		assert err.msg() == 'NotSupportedError: Invalid key format'
	}
	if _ := ED25519.create().import_key(AlgorithmParams{}, .raw, [], false, [.sign]) {
		assert false
	} else {
		assert err.msg() == "SyntaxError: Invalid key usage 'sign'"
	}
	// Certificate parsing discards unread no-parameter algorithm scope octets.
	with_parameters := hex.decode('302c300706032b65700500032100' + public_key.handle().hex())!
	assert subtle.import_key(.spki, with_parameters, 'Ed25519', false, [], '')!.handle() == public_key.handle()
	short_key := subtle.import_key(.pkcs8, export_okp_der('Ed25519', [u8(1)], true), 'Ed25519', false, [.sign], '')!
	if _ := ed25519_sign(short_key, []) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Failed to generate public key'
	}
	short_public := subtle.import_key(.spki, export_okp_der('Ed25519', [u8(1)], false), 'Ed25519', false, [], '')!
	if _ := ed25519_verify(short_public, [], []) {
		assert false
	} else {
		assert err.msg() == 'OperationError: ptr failed'
	}
	mut trailing := public_der.clone()
	trailing << u8(0)
	if _ := subtle.import_key(.spki, trailing, 'Ed25519', false, [], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Not all bytes were consumed during the parsing phase'
	}
	if _ := subtle.import_key(.spki, export_okp_der('Ed448', public_key.handle(), false), 'Ed25519', false, [], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid algorithm identifier'
	}
}

@[heap]
struct Ed25519BindingHost {
mut:
	work   []fn ()
	settle []fn ()
}

fn test_ed25519_source_deferred_der_copies_export_and_wrapping() {
	mut host := &Ed25519BindingHost{}
	subtle := SubtleCrypto.create()
	binding := SubtleCryptoBinding.create(subtle, webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn [mut host] (task fn ()) { host.settle << task })
	mut bytes := webidl.BufferSource.array_buffer(hex.decode(ed25519_wpt_pkcs8)!)
	imported := binding.import_key(.pkcs8, webidl.buffer_source_value(bytes), webidl.string_value('Ed25519'), true, [.sign])
	bytes.write([]u8{len: int(bytes.byte_length())}, 0)!
	assert imported.state == .pending
	host.work[0]()
	private_key := crypto_key_from_value(imported.result)!
	assert private_key.handle().hex() == ed25519_wpt_pkcs8[32..]
	mut message := webidl.BufferSource.array_buffer(hex.decode(ed25519_wpt_message)!)
	signed := binding.sign(webidl.string_value('Ed25519'), private_key, message)
	message.write([]u8{len: int(message.byte_length())}, 0)!
	host.work[1]()
	assert signed.state == .pending
	host.settle[0]()
	assert webidl.get_buffer_source_copy(signed.result.buffer_value or { panic('signature') }).hex() == ed25519_wpt_signatures
	exported := binding.export_key(.pkcs8, private_key)
	host.work[2]()
	assert webidl.get_buffer_source_copy(exported.result.buffer_value or { panic('DER') }).hex() == ed25519_wpt_pkcs8
	invalid := binding.export_key(.raw_seed, private_key)
	host.work[3]()
	assert invalid.state == .rejected && invalid.result.object_value['message'].string_value == 'Invalid key format'
	wrapping_key := subtle.import_key(.raw, []u8{len: 16, init: 7}, 'AES-KW', true, [
		.wrap_key,
		.unwrap_key,
	], '')!
	wrapped := subtle.wrap_key(.pkcs8, private_key, wrapping_key, 'AES-KW')!
	unwrapped := subtle.unwrap_key(.pkcs8, wrapped, wrapping_key, 'AES-KW', 'Ed25519', true, [.sign], '')!
	assert unwrapped.internal_handle() == private_key.internal_handle()
	// Retained typed-only compatibility API routes native operations on seeds.
	assert subtle.import_key(.raw_seed, private_key.handle(), 'Ed25519', true, [.sign], '')!.handle() == private_key.handle()
	expanded := subtle.export_key(.raw_private, private_key)!
	assert expanded.len == 64
	assert subtle.import_key(.raw_private, expanded, 'Ed25519', true, [.sign], '')!.handle() == private_key.handle()
	invalid_wrap := binding.wrap_key(.raw_seed, private_key, wrapping_key, webidl.string_value('AES-KW'))
	host.work[4]()
	assert invalid_wrap.state == .rejected && invalid_wrap.result.object_value['message'].string_value == 'Invalid key format'
	wrapped_promise := binding.wrap_key(.pkcs8, private_key, wrapping_key, webidl.string_value('AES-KW'))
	host.work[5]()
	unwrapped_promise := binding.unwrap_key(.pkcs8, wrapped_promise.result.buffer_value or { panic('wrapped') }, wrapping_key, webidl.string_value('AES-KW'), webidl.string_value('Ed25519'), true, [.sign])
	host.work[6]()
	assert crypto_key_from_value(unwrapped_promise.result)!.internal_handle() == private_key.internal_handle()
}

struct Ed25519SourceVector {
	private_hex   string
	public_hex    string
	message_hex   string
	signature_hex string
}

// Exact five RFC8032 fixtures from upstream Tests/LibCrypto/TestEd25519.cpp.
const ed25519_source_vectors = [
	Ed25519SourceVector{
		private_hex:   '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60'
		public_hex:    'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a'
		message_hex:   ''
		signature_hex: 'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b'
	},
	Ed25519SourceVector{
		private_hex:   '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb'
		public_hex:    '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c'
		message_hex:   '72'
		signature_hex: '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00'
	},
	Ed25519SourceVector{
		private_hex:   'c5aa8df43f9f837bedb7442f31dcb7b166d38535076f094b85ce3a2e0b4458f7'
		public_hex:    'fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025'
		message_hex:   'af82'
		signature_hex: '6291d657deec24024827e69c3abe01a30ce548a284743a445e3680d7db5ac3ac18ff9b538d16f290ae67f760984dc6594a7c15e9716ed28dc027beceea1ec40a'
	},
	Ed25519SourceVector{
		private_hex:   'f5e5767cf153319517630f226876b86c8160cc583bc013744c6bf255f5cc0ee5'
		public_hex:    '278117fc144c72340f67d0f2316e8386ceffbf2b2428c9c51fef7c597f1d426e'
		message_hex:   '08b8b2b733424243760fe426a4b54908632110a66c2f6591eabd3345e3e4eb98fa6e264bf09efe12ee50f8f54e9f77b1e355f6c50544e23fb1433ddf73be84d879de7c0046dc4996d9e773f4bc9efe5738829adb26c81b37c93a1b270b20329d658675fc6ea534e0810a4432826bf58c941efb65d57a338bbd2e26640f89ffbc1a858efcb8550ee3a5e1998bd177e93a7363c344fe6b199ee5d02e82d522c4feba15452f80288a821a579116ec6dad2b3b310da903401aa62100ab5d1a36553e06203b33890cc9b832f79ef80560ccb9a39ce767967ed628c6ad573cb116dbefefd75499da96bd68a8a97b928a8bbc103b6621fcde2beca1231d206be6cd9ec7aff6f6c94fcd7204ed3455c68c83f4a41da4af2b74ef5c53f1d8ac70bdcb7ed185ce81bd84359d44254d95629e9855a94a7c1958d1f8ada5d0532ed8a5aa3fb2d17ba70eb6248e594e1a2297acbbb39d502f1a8c6eb6f1ce22b3de1a1f40cc24554119a831a9aad6079cad88425de6bde1a9187ebb6092cf67bf2b13fd65f27088d78b7e883c8759d2c4f5c65adb7553878ad575f9fad878e80a0c9ba63bcbcc2732e69485bbc9c90bfbd62481d9089beccf80cfe2df16a2cf65bd92dd597b0707e0917af48bbb75fed413d238f5555a7a569d80c3414a8d0859dc65a46128bab27af87a71314f318c782b23ebfe808b82b0ce26401d2e22f04d83d1255dc51addd3b75a2b1ae0784504df543af8969be3ea7082ff7fc9888c144da2af58429ec96031dbcad3dad9af0dcbaaaf268cb8fcffead94f3c7ca495e056a9b47acdb751fb73e666c6c655ade8297297d07ad1ba5e43f1bca32301651339e22904cc8c42f58c30c04aafdb038dda0847dd988dcda6f3bfd15c4b4c4525004aa06eeff8ca61783aacec57fb3d1f92b0fe2fd1a85f6724517b65e614ad6808d6f6ee34dff7310fdc82aebfd904b01e1dc54b2927094b2db68d6f903b68401adebf5a7e08d78ff4ef5d63653a65040cf9bfd4aca7984a74d37145986780fc0b16ac451649de6188a7dbdf191f64b5fc5e2ab47b57f7f7276cd419c17a3ca8e1b939ae49e488acba6b965610b5480109c8b17b80e1b7b750dfc7598d5d5011fd2dcc5600a32ef5b52a1ecc820e308aa342721aac0943bf6686b64b2579376504ccc493d97e6aed3fb0f9cd71a43dd497f01f17c0e2cb3797aa2a2f256656168e6c496afc5fb93246f6b1116398a346f1a641f3b041e989f7914f90cc2c7fff357876e506b50d334ba77c225bc307ba537152f3f1610e4eafe595f6d9d90d11faa933a15ef1369546868a7f3a45a96768d40fd9d03412c091c6315cf4fde7cb68606937380db2eaaa707b4c4185c32eddcdd306705e4dc1ffc872eeee475a64dfac86aba41c0618983f8741c5ef68d3a101e8a3b8cac60c905c15fc910840b94c00a0b9d0'
		signature_hex: '0aab4c900501b3e24d7cdf4663326a3a87df5e4843b2cbdb67cbf6e460fec350aa5371b1508f9f4528ecea23c436d94b5e8fcd4f681e30a6ac00a9704a188a03'
	},
	Ed25519SourceVector{
		private_hex:   '833fe62409237b9d62ec77587520911e9a759cec1d19755b7da901b96dca3d42'
		public_hex:    'ec172b93ad5e563bf4932c70e1245034c35467ef2efd4d64ebf819683467e2bf'
		message_hex:   'ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f'
		signature_hex: 'dc2a4459e7369633a52b1bf277839a00201009a3efbf3ecb69bea2186c26b58909351fc9ac90b3ecfdfbc7c66431e0303dca179c138ac17ad9bef1177331a704'
	},
]

const ed25519_wpt_pkcs8 = '302e020100300506032b657004220420f3c8f4c48df878146e8cd3bf6df4e50e389ba7074e15c2352dcd5d308d4ca81f'
const ed25519_wpt_spki = '302a300506032b6570032100d8e18963d809d487d9549accaec6742e7eeba24d8a0d3b14b7e3caea06893dcc'
const ed25519_wpt_signatures = '3d90de5e5743dfc28225bfadb341b116cbf8a3f1ceedbf4adc350ef5d3471843a418614dcb6e614862614cf7af1496f9340b3c844ea4dceab1d3d155eb7ecc00'
const ed25519_wpt_message = '2b7ed0bc7795694ab4acd35903fe8cd7d80f6a1c8688a6c3414409457514a1457855bbb219e30a1beea8fe869082d99fc8282f9050d024e59eaf0730ba9db70a'

struct Ed25519WptVerifyVector {
	public_hex    string
	message_hex   string
	signature_hex string
	verified      bool
}

const ed25519_wpt_verify_vectors = [
	Ed25519WptVerifyVector{ public_hex: 'c7176a703d4dd84fba3c0b760d10670f2a2053fa2c39ccc64ec7fd7792ac03fa', message_hex: '8c93255d71dcab10e8f379c26200f3c7bd5f09d9bc3068d3ef4edeb4853022b6', signature_hex: 'c7176a703d4dd84fba3c0b760d10670f2a2053fa2c39ccc64ec7fd7792ac037a0000000000000000000000000000000000000000000000000000000000000000', verified: false },
	Ed25519WptVerifyVector{ public_hex: 'c7176a703d4dd84fba3c0b760d10670f2a2053fa2c39ccc64ec7fd7792ac03fa', message_hex: '9bd9f44f4dcc75bd531b56b2cd280b0bb38fc1cd6d1230e14861d861de092e79', signature_hex: 'f7badec5b8abeaf699583992219b7b223f1df3fbbea919844e3f7c554a43dd43a5bb704786be79fc476f91d3f3f89b03984d8068dcf1bb7dfc6637b45450ac04', verified: false },
	Ed25519WptVerifyVector{ public_hex: 'f7badec5b8abeaf699583992219b7b223f1df3fbbea919844e3f7c554a43dd43', message_hex: 'aebf3f2601a0c8c5d39cc7d8911642f740b78168218da8471772b35f9d35b9ab', signature_hex: 'c7176a703d4dd84fba3c0b760d10670f2a2053fa2c39ccc64ec7fd7792ac03fa8c4bd45aecaca5b24fb97bc10ac27ac8751a7dfe1baff8b953ec9f5833ca260e', verified: false },
	Ed25519WptVerifyVector{ public_hex: 'cdb267ce40c5cd45306fa5d2f29731459387dbf9eb933b7bd5aed9a765b88d4d', message_hex: '9bd9f44f4dcc75bd531b56b2cd280b0bb38fc1cd6d1230e14861d861de092e79', signature_hex: '9046a64750444938de19f227bb80485e92b83fdb4b6506c160484c016cc1852f87909e14428a7a1d62e9f22f3d3ad7802db02eb2e688b6c52fcd6648a98bd009', verified: true },
	Ed25519WptVerifyVector{ public_hex: 'cdb267ce40c5cd45306fa5d2f29731459387dbf9eb933b7bd5aed9a765b88d4d', message_hex: 'e47d62c63f830dc7a6851a0b1f33ae4bb2f507fb6cffec4011eaccd55b53f56c', signature_hex: '160a1cb0dc9c0258cd0a7d23e94d8fa878bcb1925f2c64246b2dee1796bed5125ec6bc982a269b723e0668e540911a9a6a58921d6925e434ab10aa7940551a09', verified: false },
	Ed25519WptVerifyVector{ public_hex: 'cdb267ce40c5cd45306fa5d2f29731459387dbf9eb933b7bd5aed9a765b88d4d', message_hex: 'e47d62c63f830dc7a6851a0b1f33ae4bb2f507fb6cffec4011eaccd55b53f56c', signature_hex: '21122a84e0b5fca4052f5b1235c80a537878b38f3142356b2c2384ebad4668b7e40bc836dac0f71076f9abe3a53f9c03c1ceeeddb658d0030494ace586687405', verified: false },
	Ed25519WptVerifyVector{ public_hex: '442aad9f089ad9e14647b1ef9099a1ff4798d78589e66f28eca69c11f582a623', message_hex: '85e241a07d148b41e47d62c63f830dc7a6851a0b1f33ae4bb2f507fb6cffec40', signature_hex: 'e96f66be976d82e60150baecff9906684aebb1ef181f67a7189ac78ea23b6c0e547f7690a0e2ddcd04d87dbc3490dc19b3b3052f7ff0538cb68afb369ba3a514', verified: false },
	Ed25519WptVerifyVector{ public_hex: '442aad9f089ad9e14647b1ef9099a1ff4798d78589e66f28eca69c11f582a623', message_hex: '85e241a07d148b41e47d62c63f830dc7a6851a0b1f33ae4bb2f507fb6cffec40', signature_hex: '8ce5b96c8f26d0ab6c47958c9e68b937104cd36e13c33566acd2fe8d38aa19427e71f98a4734e74f2f13f06f97c20d58cc3f54b8bd0d272f42b695dd7e89a8c202', verified: false },
	Ed25519WptVerifyVector{ public_hex: 'f7badec5b8abeaf699583992219b7b223f1df3fbbea919844e3f7c554a43dd43', message_hex: '9bedc267423725d473888631ebf45988bad3db83851ee85c85e241a07d148b41', signature_hex: 'ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff03be9678ac102edcd92b0210bb34d7428d12ffc5df5f37e359941266a4e35f0f', verified: false },
	Ed25519WptVerifyVector{ public_hex: 'f7badec5b8abeaf699583992219b7b223f1df3fbbea919844e3f7c554a43dd43', message_hex: '9bedc267423725d473888631ebf45988bad3db83851ee85c85e241a07d148b41', signature_hex: 'ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffca8c5b64cd208982aa38d4936621a4775aa233aa0505711d8fdcfdaa943d4908', verified: false },
	Ed25519WptVerifyVector{ public_hex: 'ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', message_hex: 'e96b7021eb39c1a163b6da4e3093dcd3f21387da4cc4572be588fafae23c155b', signature_hex: 'a9d55260f765261eb9b84e106f665e00b867287a761990d7135963ee0a7d59dca5bb704786be79fc476f91d3f3f89b03984d8068dcf1bb7dfc6637b45450ac04', verified: false },
	Ed25519WptVerifyVector{ public_hex: 'ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', message_hex: '39a591f5321bbe07fd5a23dc2f39d025d74526615746727ceefd6e82ae65c06f', signature_hex: 'a9d55260f765261eb9b84e106f665e00b867287a761990d7135963ee0a7d59dca5bb704786be79fc476f91d3f3f89b03984d8068dcf1bb7dfc6637b45450ac04', verified: false },
	Ed25519WptVerifyVector{ public_hex: 'ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f', message_hex: '53656e64203130302055534420746f20416c696365', signature_hex: 'a9d55260f765261eb9b84e106f665e00b867287a761990d7135963ee0a7d59dca5bb704786be79fc476f91d3f3f89b03984d8068dcf1bb7dfc6637b45450ac04', verified: false },
	Ed25519WptVerifyVector{ public_hex: 'ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f', message_hex: '53656e64203130303030302055534420746f20416c696365', signature_hex: 'a9d55260f765261eb9b84e106f665e00b867287a761990d7135963ee0a7d59dca5bb704786be79fc476f91d3f3f89b03984d8068dcf1bb7dfc6637b45450ac04', verified: false },
]
