module yuv

import crypto.sha256

fn test_jpeg_bilinear_chroma_matches_the_brave_photo_interior() {
	planes := $embed_file('@VMODROOT/Tests/Browser/Brave/resources/avatar-jpeg-420.yuv').to_bytes()
	rgba := jpeg_bilinear_rgba(planes, 16, 16, true) or { panic('JPEG planes rejected') }
	mut interior := []u8{}
	for y in 3 .. 13 { interior << rgba[(y * 16 + 3) * 4..(y * 16 + 13) * 4] }
	// Immutable 10x10 interior of avatar-jpeg-fractional.png, captured in Brave.
	assert sha256.hexhash(interior.bytestr()) == '8f84886ae7dcfda00219977ebc5bc2472585d6e2968e9a1361424660b8229e0f'
}

fn test_jpeg_bilinear_neutral_chroma_preserves_luma_and_clamps_edges() {
	rgba := jpeg_bilinear_rgba([u8(0), 64, 128, 255, 128, 128], 2, 2, true) or { panic('neutral planes') }
	assert rgba == [u8(0), 0, 0, 255, 64, 64, 64, 255, 128, 128, 128, 255, 255, 255, 255, 255]
	assert jpeg_bilinear_rgba([u8(12), 128, 128], 1, 1, false)? == [u8(12), 12, 12, 255]
	assert jpeg_bilinear_rgba([], 3, 2, true) == none
	assert jpeg_bilinear_rgba([], 0, 1, true) == none
	assert jpeg_bilinear_rgba([], 2, 2, true) == none
	assert jpeg_bilinear_rgba([], max_int, max_int, true) == none
}
