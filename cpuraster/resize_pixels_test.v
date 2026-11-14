module cpuraster

fn test_premultiplied_upload_resize_keeps_alpha_and_source_storage() {
	source := [u8(0), 0, 0, 0, 0, 0, 128, 128]
	copy := source.clone()
	output := resize_premultiplied_rgba(source, 2, 1, 1, 1) or { panic('resize') }
	assert output == [u8(0), 0, 64, 64]
	assert source == copy
	assert resize_premultiplied_rgba(source[..4], 2, 1, 1, 1) == none
	assert resize_premultiplied_rgba(source, 2, 1, 0, 1) == none
}
