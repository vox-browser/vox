module webcrypto

import encoding.hex
import webidl

struct Ed448SourceVector {
	private_hex   string
	public_hex    string
	message_hex   string
	context_hex   string
	signature_hex string
}

// Exact RFC8032 fixtures from upstream Tests/LibCrypto/TestEd448.cpp.
const ed448_source_vectors = [
	Ed448SourceVector{
		private_hex:   '6c82a562cb808d10d632be89c8513ebf6c929f34ddfa8c9f63c9960ef6e348a3528c8a3fcc2f044e39a3fc5b94492f8f032e7549a20098f95b'
		public_hex:    '5fd7449b59b461fd2ce787ec616ad46a1da1342485a70e1f8a0ea75d80e96778edf124769b46c7061bd6783df1e50f6cd1fa1abeafe8256180'
		message_hex:   ''
		context_hex:   ''
		signature_hex: '533a37f6bbe457251f023c0d88f976ae2dfb504a843e34d2074fd823d41a591f2b233f034f628281f2fd7a22ddd47d7828c59bd0a21bfd3980ff0d2028d4b18a9df63e006c5d1c2d345b925d8dc00b4104852db99ac5c7cdda8530a113a0f4dbb61149f05a7363268c71d95808ff2e652600'
	},
	Ed448SourceVector{
		private_hex:   'c4eab05d357007c632f3dbb48489924d552b08fe0c353a0d4a1f00acda2c463afbea67c5e8d2877c5e3bc397a659949ef8021e954e0a12274e'
		public_hex:    '43ba28f430cdff456ae531545f7ecd0ac834a55d9358c0372bfa0c6c6798c0866aea01eb00742802b8438ea4cb82169c235160627b4c3a9480'
		message_hex:   '03'
		context_hex:   ''
		signature_hex: '26b8f91727bd62897af15e41eb43c377efb9c610d48f2335cb0bd0087810f4352541b143c4b981b7e18f62de8ccdf633fc1bf037ab7cd779805e0dbcc0aae1cbcee1afb2e027df36bc04dcecbf154336c19f0af7e0a6472905e799f1953d2a0ff3348ab21aa4adafd1d234441cf807c03a00'
	},
	Ed448SourceVector{
		private_hex:   'c4eab05d357007c632f3dbb48489924d552b08fe0c353a0d4a1f00acda2c463afbea67c5e8d2877c5e3bc397a659949ef8021e954e0a12274e'
		public_hex:    '43ba28f430cdff456ae531545f7ecd0ac834a55d9358c0372bfa0c6c6798c0866aea01eb00742802b8438ea4cb82169c235160627b4c3a9480'
		message_hex:   '03'
		context_hex:   '666f6f'
		signature_hex: 'd4f8f6131770dd46f40867d6fd5d5055de43541f8c5e35abbcd001b32a89f7d2151f7647f11d8ca2ae279fb842d607217fce6e042f6815ea000c85741de5c8da1144a6a1aba7f96de42505d7a7298524fda538fccbbb754f578c1cad10d54d0d5428407e85dcbc98a49155c13764e66c3c00'
	},
	Ed448SourceVector{
		private_hex:   'cd23d24f714274e744343237b93290f511f6425f98e64459ff203e8985083ffdf60500553abc0e05cd02184bdb89c4ccd67e187951267eb328'
		public_hex:    'dcea9e78f35a1bf3499a831b10b86c90aac01cd84b67a0109b55a36e9328b1e365fce161d71ce7131a543ea4cb5f7e9f1d8b00696447001400'
		message_hex:   '0c3e544074ec63b0265e0c'
		context_hex:   ''
		signature_hex: '1f0a8888ce25e8d458a21130879b840a9089d999aaba039eaf3e3afa090a09d389dba82c4ff2ae8ac5cdfb7c55e94d5d961a29fe0109941e00b8dbdeea6d3b051068df7254c0cdc129cbe62db2dc957dbb47b51fd3f213fb8698f064774250a5028961c9bf8ffd973fe5d5c206492b140e00'
	},
	Ed448SourceVector{
		private_hex:   '258cdd4ada32ed9c9ff54e63756ae582fb8fab2ac721f2c8e676a72768513d939f63dddb55609133f29adf86ec9929dccb52c1c5fd2ff7e21b'
		public_hex:    '3ba16da0c6f2cc1f30187740756f5e798d6bc5fc015d7c63cc9510ee3fd44adc24d8e968b6e46e6f94d19b945361726bd75e149ef09817f580'
		message_hex:   '64a65f3cdedcdd66811e2915'
		context_hex:   ''
		signature_hex: '7eeeab7c4e50fb799b418ee5e3197ff6bf15d43a14c34389b59dd1a7b1b85b4ae90438aca634bea45e3a2695f1270f07fdcdf7c62b8efeaf00b45c2c96ba457eb1a8bf075a3db28e5c24f6b923ed4ad747c3c9e03c7079efb87cb110d3a99861e72003cbae6d6b8b827e4e6c143064ff3c00'
	},
	Ed448SourceVector{
		private_hex:   '7ef4e84544236752fbb56b8f31a23a10e42814f5f55ca037cdcc11c64c9a3b2949c1bb60700314611732a6c2fea98eebc0266a11a93970100e'
		public_hex:    'b3da079b0aa493a5772029f0467baebee5a8112d9d3a22532361da294f7bb3815c5dc59e176b4d9f381ca0938e13c6c07b174be65dfa578e80'
		message_hex:   '64a65f3cdedcdd66811e2915e7'
		context_hex:   ''
		signature_hex: '6a12066f55331b6c22acd5d5bfc5d71228fbda80ae8dec26bdd306743c5027cb4890810c162c027468675ecf645a83176c0d7323a2ccde2d80efe5a1268e8aca1d6fbc194d3f77c44986eb4ab4177919ad8bec33eb47bbb5fc6e28196fd1caf56b4e7e0ba5519234d047155ac727a1053100'
	},
	Ed448SourceVector{
		private_hex:   'd65df341ad13e008567688baedda8e9dcdc17dc024974ea5b4227b6530e339bff21f99e68ca6968f3cca6dfe0fb9f4fab4fa135d5542ea3f01'
		public_hex:    'df9705f58edbab802c7f8363cfe5560ab1c6132c20a9f1dd163483a26f8ac53a39d6808bf4a1dfbd261b099bb03b3fb50906cb28bd8a081f00'
		message_hex:   'bd0f6a3747cd561bdddf4640a332461a4a30a12a434cd0bf40d766d9c6d458e5512204a30c17d1f50b5079631f64eb3112182da3005835461113718d1a5ef944'
		context_hex:   ''
		signature_hex: '554bc2480860b49eab8532d2a533b7d578ef473eeb58c98bb2d0e1ce488a98b18dfde9b9b90775e67f47d4a1c3482058efc9f40d2ca033a0801b63d45b3b722ef552bad3b4ccb667da350192b61c508cf7b6b5adadc2c8d9a446ef003fb05cba5f30e88e36ec2703b349ca229c2670833900'
	},
	Ed448SourceVector{
		private_hex:   '2ec5fe3c17045abdb136a5e6a913e32ab75ae68b53d2fc149b77e504132d37569b7e766ba74a19bd6162343a21c8590aa9cebca9014c636df5'
		public_hex:    '79756f014dcfe2079f5dd9e718be4171e2ef2486a08f25186f6bff43a9936b9bfe12402b08ae65798a3d81e22e9ec80e7690862ef3d4ed3a00'
		message_hex:   '15777532b0bdd0d1389f636c5f6b9ba734c90af572877e2d272dd078aa1e567cfa80e12928bb542330e8409f3174504107ecd5efac61ae7504dabe2a602ede89e5cca6257a7c77e27a702b3ae39fc769fc54f2395ae6a1178cab4738e543072fc1c177fe71e92e25bf03e4ecb72f47b64d0465aaea4c7fad372536c8ba516a6039c3c2a39f0e4d832be432dfa9a706a6e5c7e19f397964ca4258002f7c0541b590316dbc5622b6b2a6fe7a4abffd96105eca76ea7b98816af0748c10df048ce012d901015a51f189f3888145c03650aa23ce894c3bd889e030d565071c59f409a9981b51878fd6fc110624dcbcde0bf7a69ccce38fabdf86f3bef6044819de11'
		context_hex:   ''
		signature_hex: 'c650ddbb0601c19ca11439e1640dd931f43c518ea5bea70d3dcde5f4191fe53f00cf966546b72bcc7d58be2b9badef28743954e3a44a23f880e8d4f1cfce2d7a61452d26da05896f0a50da66a239a8a188b6d825b3305ad77b73fbac0836ecc60987fd08527c1a8e80d5823e65cafe2a3d00'
	},
	Ed448SourceVector{
		private_hex:   '872d093780f5d3730df7c212664b37b8a0f24f56810daa8382cd4fa3f77634ec44dc54f1c2ed9bea86fafb7632d8be199ea165f5ad55dd9ce8'
		public_hex:    'a81b2e8a70a5ac94ffdbcc9badfc3feb0801f258578bb114ad44ece1ec0e799da08effb81c5d685c0c56f64eecaef8cdf11cc38737838cf400'
		message_hex:   '6ddf802e1aae4986935f7f981ba3f0351d6273c0a0c22c9c0e8339168e675412a3debfaf435ed651558007db4384b650fcc07e3b586a27a4f7a00ac8a6fec2cd86ae4bf1570c41e6a40c931db27b2faa15a8cedd52cff7362c4e6e23daec0fbc3a79b6806e316efcc7b68119bf46bc76a26067a53f296dafdbdc11c77f7777e972660cf4b6a9b369a6665f02e0cc9b6edfad136b4fabe723d2813db3136cfde9b6d044322fee2947952e031b73ab5c603349b307bdc27bc6cb8b8bbd7bd323219b8033a581b59eadebb09b3c4f3d2277d4f0343624acc817804728b25ab797172b4c5c21a22f9c7839d64300232eb66e53f31c723fa37fe387c7d3e50bdf9813a30e5bb12cf4cd930c40cfb4e1fc622592a49588794494d56d24ea4b40c89fc0596cc9ebb961c8cb10adde976a5d602b1c3f85b9b9a001ed3c6a4d3b1437f52096cd1956d042a597d561a596ecd3d1735a8d570ea0ec27225a2c4aaff26306d1526c1af3ca6d9cf5a2c98f47e1c46db9a33234cfd4d81f2c98538a09ebe76998d0d8fd25997c7d255c6d66ece6fa56f11144950f027795e653008f4bd7ca2dee85d8e90f3dc315130ce2a00375a318c7c3d97be2c8ce5b6db41a6254ff264fa6155baee3b0773c0f497c573f19bb4f4240281f0b1f4f7be857a4e59d416c06b4c50fa09e1810ddc6b1467baeac5a3668d11b6ecaa901440016f389f80acc4db977025e7f5924388c7e340a732e554440e76570f8dd71b7d640b3450d1fd5f0410a18f9a3494f707c717b79b4bf75c98400b096b21653b5d217cf3565c9597456f70703497a078763829bc01bb1cbc8fa04eadc9a6e3f6699587a9e75c94e5bab0036e0b2e711392cff0047d0d6b05bd2a588bc109718954259f1d86678a579a3120f19cfb2963f177aeb70f2d4844826262e51b80271272068ef5b3856fa8535aa2a88b2d41f2a0e2fda7624c2850272ac4a2f561f8f2f7a318bfd5caf9696149e4ac824ad3460538fdc25421beec2cc6818162d06bbed0c40a387192349db67a118bada6cd5ab0140ee273204f628aad1c135f770279a651e24d8c14d75a6059d76b96a6fd857def5e0b354b27ab937a5815d16b5fae407ff18222c6d1ed263be68c95f32d908bd895cd76207ae726487567f9a67dad79abec316f683b17f2d02bf07e0ac8b5bc6162cf94697b3c27cd1fea49b27f23ba2901871962506520c392da8b6ad0d99f7013fbc06c2c17a569500c8a7696481c1cd33e9b14e40b82e79a5f5db82571ba97bae3ad3e0479515bb0e2b0f3bfcd1fd33034efc6245eddd7ee2086ddae2600d8ca73e214e8c2b0bdb2b047c6a464a562ed77b73d2d841c4b34973551257713b753632efba348169abc90a68f42611a40126d7cb21b58695568186f7e569d2ff0f9e745d0487dd2eb997cafc5abf9dd102e62ff66cba87'
		context_hex:   ''
		signature_hex: 'e301345a41a39a4d72fff8df69c98075a0cc082b802fc9b2b6bc503f926b65bddf7f4c8f1cb49f6396afc8a70abe6d8aef0db478d4c6b2970076c6a0484fe76d76b3a97625d79f1ce240e7c576750d295528286f719b413de9ada3e8eb78ed573603ce30d8bb761785dc30dbc320869e1a00'
	},
]

fn ed448_vector_jwk(vector Ed448SourceVector) JsonWebKey {
	return JsonWebKey{ kty: 'OKP', crv: 'Ed448', x: base64url_encode(hex.decode(vector.public_hex) or { panic(err) }), d: base64url_encode(hex.decode(vector.private_hex) or { panic(err) }) }
}

fn test_ed448_all_upstream_rfc8032_signatures_and_contexts_through_subtle() {
	subtle := SubtleCrypto.create()
	assert ed448_source_vectors.len == 9
	for vector in ed448_source_vectors {
		private_key := subtle.import_jwk(ed448_vector_jwk(vector), 'ed448', true, [.sign], '')!
		public_key := subtle.import_key(.raw, hex.decode(vector.public_hex)!, 'Ed448', true, [.verify], '')!
		message := hex.decode(vector.message_hex)!
		params := Ed448Params{ context: hex.decode(vector.context_hex)! }
		signature := subtle.sign(params, private_key, message)!
		assert signature.hex() == vector.signature_hex
		assert subtle.verify(params, public_key, signature, message)!
		assert !subtle.verify(Ed448Params{ context: 'different'.bytes() }, public_key, signature, message)!
		mut invalid := signature.clone()
		invalid[5] ^= 0x40
		assert !subtle.verify(params, public_key, invalid, message)!
		assert !subtle.verify(params, public_key, signature[..113], message)!
	}
}

fn test_ed448_formats_generation_and_source_validation_order() {
	subtle := SubtleCrypto.create()
	vector := ed448_source_vectors[0]
	private_key := subtle.import_jwk(ed448_vector_jwk(vector), 'Ed448', true, [.sign], '')!
	public_key := subtle.import_key(.raw, hex.decode(vector.public_hex)!, 'Ed448', true, [.verify], '')!
	assert private_key.internal_handle() is OkpPrivateKeyHandle
	assert public_key.internal_handle() is OkpPublicKeyHandle
	assert subtle.export_key(.spki, public_key)!.hex() == '3043300506032b6571033a00' + vector.public_hex
	assert subtle.export_key(.pkcs8, private_key)!.hex() == '3047020100300506032b6571043b0439' + vector.private_hex
	assert subtle.import_key(.spki, subtle.export_key(.spki, public_key)!, 'Ed448', true, [.verify], '')!.handle() == public_key.handle()
	assert subtle.import_key(.pkcs8, subtle.export_key(.pkcs8, private_key)!, 'Ed448', true, [.sign], '')!.handle() == private_key.handle()
	jwk := subtle.export_jwk(private_key)!
	assert (jwk.alg or { '' }) == 'Ed448'
	assert (jwk.x or { '' }) == base64url_encode(public_key.handle())
	assert subtle.import_jwk(JsonWebKey{ ...jwk, alg: 'EdDSA' }, 'Ed448', true, [.sign], '')!.handle() == private_key.handle()
	pair := subtle.generate_key(AlgorithmParams{ name: 'Ed448' }, false, [.sign, .verify])!.pair or { panic('pair') }
	assert pair.public_key.extractable && pair.public_key.usages == [.verify]
	assert !pair.private_key.extractable && pair.private_key.usages == [.sign]
	assert pair.private_key.handle().len == 57
	signature := subtle.sign('Ed448', pair.private_key, 'native generated key'.bytes())!
	assert signature.len == 114
	assert subtle.verify('Ed448', pair.public_key, signature, 'native generated key'.bytes())!
	if _ := subtle.generate_key(AlgorithmParams{ name: 'Ed448' }, true, [.verify]) {
		assert false
	} else {
		assert err.msg() == 'SyntaxError: usages must not be empty'
	}
	if _ := subtle.import_key(.raw, [], 'Ed448', true, [.sign], '') {
		assert false
	} else {
		assert err.msg() == "SyntaxError: Invalid key usage 'sign'"
	}
	if _ := subtle.import_key(.raw_public, hex.decode(vector.public_hex)!, 'Ed448', true, [.verify], '') {
		assert false
	} else {
		assert err.msg() == 'NotSupportedError: Invalid key format'
	}
	if _ := subtle.export_key(.raw, private_key) {
		assert false
	} else {
		assert err.msg() == 'InvalidAccessError: Key is not a public key'
	}
	if _ := subtle.import_jwk(JsonWebKey{ ...jwk, x: base64url_encode([]u8{len: 57}) }, 'Ed448', true, [.sign], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid key pair'
	}
	if _ := subtle.import_jwk(JsonWebKey{ ...jwk, alg: 'Ed25519' }, 'Ed448', true, [.sign], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid algorithm'
	}
	if _ := subtle.sign(Ed448Params{ context: []u8{len: 256} }, private_key, []) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Context is too long'
	}
	if _ := subtle.verify(Ed448Params{ context: []u8{len: 256} }, public_key, [], []) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Context is too long'
	}
	if _ := ED448.create().sign(Ed448Params{ context: []u8{len: 256} }, public_key, []) {
		assert false
	} else {
		assert err.msg() == 'InvalidAccessError: Key is not a private key'
	}
}

@[heap]
struct Ed448BindingHost {
mut:
	work   []fn ()
	settle []fn ()
}

fn test_ed448_async_sign_copies_context_and_message_then_queues_crypto_result() {
	mut host := &Ed448BindingHost{}
	binding := SubtleCryptoBinding.create(SubtleCrypto.create(), webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn [mut host] (task fn ()) { host.settle << task })
	vector := ed448_source_vectors[2]
	private_key := SubtleCrypto.create().import_jwk(ed448_vector_jwk(vector), 'Ed448', true, [.sign], '')!
	mut context := webidl.BufferSource.array_buffer(hex.decode(vector.context_hex)!)
	mut message := webidl.BufferSource.array_buffer(hex.decode(vector.message_hex)!)
	promise := binding.sign(webidl.object_value({
		'name':    webidl.string_value('Ed448')
		'context': webidl.buffer_source_value(context)
	}), private_key, message)
	context.write('bar'.bytes(), 0)!
	message.write([u8(0xff)], 0)!
	assert promise.state == .pending
	host.work[0]()
	assert promise.state == .pending && host.settle.len == 1
	host.settle[0]()
	assert promise.state == .fulfilled
	assert webidl.get_buffer_source_copy(promise.result.buffer_value or { panic('signature') }).hex() == vector.signature_hex
}
