module cpuraster

// Native Linux Skia captures for RGBA fixtures. macOS uses native RGBA
// blitters; Linux uses its raster pipeline. See native_fixture_hashes.py.
$if test {
	const linux_fixture_hashes = {
		'0495a4388ca940c9': '4ec241afc49390c5'
		'0dd8702f735886e1': '835f98fef31463db'
		'0fa8edf3e8f321c6': '7ce736fc324ce042'
		'1227ca0598e190be': 'd62ff7111f54aeec'
		'2472657d501d84e9': '917a37d4d0cfabbe'
		'24d847ccb95ac95d': '2d96be719ac02399'
		'2b8fc31a519a1424': 'adb78cca8b033a26'
		'31420421a7850a76': '1ecd349cd894ff04'
		'3955e568dc7e51e9': '697cd2288681a718'
		'39a45c3f5a2c4ec5': '1a4d9c3a88ff100a'
		'48cad6dfb1e598d2': '63a8768e85b4253a'
		'48cbeda9149b9d90': 'fb9361eb6cbfd6dc'
		'49259369cfea127b': '0686afd78a551f0d'
		'56bf60736e47897d': '759864d4ceb892e9'
		'5e3331fed1e90d5e': 'e3ec751ac3b89129'
		'627f3ce6ef3d3aec': 'a01b1beb90fa3bc0'
		'6bb0bc7d52895eef': 'e80063e8c6c2ce58'
		'727f7a3691bdb1cf': '98cb5311971e4a33'
		'75ee606bebbb9856': 'a966aae1fb87c1a7'
		'7a1823380c32d1fe': '11687dd4a5060423'
		'8cf60fb249145508': '022a41267fb40043'
		'981723a1df76bd4e': '5fefb2be6ed54ca4'
		'9c725c14254b2f62': '85bfcb132f8fe722'
		'b2f01d83fe2a4440': 'c283f2a3e2d11022'
		'b9e3807216264fee': '7442fca1988e1083'
		'bacdf0a331c9f7ed': '642154f9ae958c18'
		'bf0294f026fc86d2': '7bdc82070870590a'
		'dea51d8b129f7d39': 'd340d4160018d688'
		'e05cc38cab516e92': '90e1d7eff0e7cbce'
		'e2b375521cc1d35b': 'a3daeb0417f2e47d'
		'edcd6b85fed92936': '7ca32ea9288c48ef'
		'f9911f428908818f': 'a86fad6177ae5b7c'
	}

	fn fixture_hash(macos_reference string) string {
		$if linux {
			return linux_fixture_hashes[macos_reference] or { macos_reference }
		} $else {
			return macos_reference
		}
	}
}
