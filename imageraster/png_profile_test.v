module imageraster

fn png_profile_chunk(kind string, words []u32) []u8 {
	mut chunk := []u8{}
	size := u32(words.len * 4)
	chunk << [u8(size >> 24), u8(size >> 16), u8(size >> 8), u8(size)]
	chunk << kind.bytes()
	for word in words { chunk << [u8(word >> 24), u8(word >> 16), u8(word >> 8), u8(word)] }
	chunk << [u8(0), 0, 0, 0]
	return chunk
}

fn png_profile_stream(chunks [][]u8) []u8 {
	header := $embed_file('@VMODROOT/Tests/Browser/Brave/resources/image-decode-cold.png').to_bytes()
	mut bytes := header[..33].clone()
	for chunk in chunks { bytes << chunk }
	bytes << png_profile_chunk('IDAT', [])
	return bytes
}

fn test_png_legacy_profile_precedence_and_unsupported_metadata() {
	gamma := png_profile_chunk('gAMA', [u32(45455)])
	primaries := png_profile_chunk('cHRM', [u32(31270), 32900, 64000, 33000, 30000, 60000, 15000,
		6000])
	legacy := png_sampling_profile(png_profile_stream([gamma, primaries])) or { panic('legacy') }
	assert legacy.gamma == f32(2.2)
	assert legacy.gamut == png_srgb_chromaticities_gamut
	assert png_sampling_profile(png_profile_stream([gamma]))?.gamma == 0
	assert png_sampling_profile(png_profile_stream([gamma, primaries, png_profile_chunk('sRGB', [])]))?.gamma == 0
	assert png_sampling_profile(png_profile_stream([png_profile_chunk('gAMA', [u32(100000)])]))?.gamma == 1
	linear := png_sampling_profile(png_profile_stream([
		png_profile_chunk('gAMA', [u32(100000)]),
		primaries,
	])) or { panic('linear') }
	assert linear.gamma == 1 && linear.gamut == PNGSamplingProfile{}.gamut
	for kind in ['iCCP', 'cICP', 'acTL'] {
		assert png_sampling_profile(png_profile_stream([gamma, primaries, png_profile_chunk(kind, [])])) == none
	}
	assert png_sampling_profile(png_profile_stream([png_profile_chunk('gAMA', [u32(0)])])) == none
	assert png_sampling_profile(png_profile_stream([gamma,
		png_profile_chunk('cHRM', [u32(31270), 32900, 68000, 32000, 26500, 69000, 15000, 6000])])) == none
	assert png_sampling_profile([u8(137), 80]) == none
	mut truncated := png_profile_stream([gamma, primaries])
	truncated << [u8(0)]
	assert png_sampling_profile(truncated[..truncated.len - 5]) == none
}
