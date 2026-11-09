// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

// Original WPT hkdf_vectors.js at 57bbaa12ff3515848cc0b3d3791791086a563047.
fn test_empty_hkdf_key_material_matches_official_vectors_with_empty_salt_and_info() {
	subtle := SubtleCrypto.create()
	key := subtle.import_key(.raw, [], 'HKDF', false, [.derive_bits], '')!
	vectors := {
		'SHA-1':   ['ab679e67bcb4305fee42ef940e509cddd406e3498f857418a979ab39cf315f51',
			'fe422187188c8636d36daad58ef28431a433bf0fef72d1cae735a04bdbbeb9d3',
			'a1bdd8c332c6464a4bb6a2f231aec9a444237eabe04d2f55f2ab25d40c54ebee',
			'885fc029b3224b896e09e0bbe5eb347ec59e6827c8e857b394f54ff49b88a8f6']
		'SHA-256': ['df92b9a9fa9c01b898ceeaa13134832e31cb1c081d16a5235c69d85651e317ac',
			'e60d432b06ee889dfab7299a20ec23697531d119fcf766d0988d0acb0c00c7f7',
			'b7b86e422ad1c8a571fda528da16a066f42486dd4056792fd93362088e5dd4c2',
			'eb70f01dede9afafa449eee1b1286504e1f62388b3f7dd4f956697b0e828fe18']
		'SHA-384': ['6a8632e486899dc264f1a1f920593f2880804e0e1adacf94eb4ed5e5f83d0d12',
			'ea5012feb58751d5bc8eb64e0deacd597ed710c9f35258ae6b9a087aed0725ae',
			'eacb9d6670ff3b1904779a419101b1ffaabd6d6510bd50856801746a871f7b31',
			'470cc65387ca4a10c7a68a3b5148c8e513daa63101000739c4c6659b86118884']
		'SHA-512': ['c797e1d1f2cab7f28a5f43455c10597f943385edfb428cfe2b98bed4a955d7a1',
			'e08cdcc4c5a6aa799d86bc03a95475276ebb801d9ade016e14a8fa5b64051651',
			'57039174f16f5418a86856daeb77f69d4b4d5000334b6dd1f4f4b3e7b3dcb9d3',
			'9d73c98e791e80ebe5b4cb45693aa32fdd44b5fa3edab3ec82f9d0f4d66905e2']
	}
	for hash, expected in vectors {
		for index, bytes in expected {
			salt := if index < 2 { 'Sodium Chloride compound'.bytes() } else { []u8{} }
			info := if index % 2 == 0 { 'HKDF extra info'.bytes() } else { []u8{} }
			result := subtle.derive_bits(HkdfParams{ hash: hash, salt: salt, info: info }, key, 256)!
			assert result.hex() == bytes, hash + ' case ' + index.str()
		}
	}
}

fn test_empty_pbkdf2_password_and_salt_have_present_provider_parameters() {
	subtle := SubtleCrypto.create()
	key := subtle.import_key(.raw, [], 'PBKDF2', false, [.derive_bits], '')!
	vectors := {
		'SHA-1':   ['133a4ce837b4d2521ee2bf03e11c71ca794e079713b87cd23f360bdda2e87872',
			'620c000a06fed9c10bca11516b3ac0228d6717007c47bf78da893067bf0e258c']
		'SHA-256': ['62384466264daadc4144018c6bd864648272b34da8980d31521ffcce92ae003b',
			'97398411d6aea43a77acef92226ab8278d4db0668bd1d7a76a725f7680ac45c5']
		'SHA-384': ['a34ba6857eee44bd41b06d30e2521564ec2116a3010aad3080f35d0dde7b5c86',
			'4e2b9109c23c305fc5c1d1e167741a52e9ebfd0805ff8662b323fd1169034a8c']
		'SHA-512': ['cc5eacbb057f2a5982fce67bf70f79fccf4adf285f5cbae1a5a1c5df012a630a',
			'a422663fda8609a1e2fd53541260edf886ec636605814c2e17b4c78d8f9e2332']
	}
	for hash, expected in vectors {
		for index, bytes in expected {
			salt := if index == 0 { 'salt'.bytes() } else { []u8{} }
			result := subtle.derive_bits(Pbkdf2Params{ hash: hash, salt: salt, iterations: 2 }, key, 256)!
			assert result.hex() == bytes, hash + ' case ' + index.str()
		}
	}
}
