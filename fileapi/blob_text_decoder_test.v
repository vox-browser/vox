module fileapi

fn test_standalone_blob_text_uses_the_pinned_source_decoder_instead_of_mime_charset() {
	assert Blob.create([u8(0xFF), 0xFE, 0x61, 0], 'text/plain;charset=UTF-8').text()! == 'a'
	assert Blob.create([u8(0xFE), 0xFF, 0, 0x61], '').text()! == 'a'
	assert Blob.create([u8(0xE9)], 'text/plain;charset=windows-1252').text()! == '\ufffd'
	assert Blob.create([u8(0xEF), 0xBB, 0xBF, 0xEF, 0xBB, 0xBF], '').text()! == ''
	assert Blob.create([u8(0xEF), 0xBB, 0xBF, 0xEF, 0xBB, 0xBF, 0xEF, 0xBB, 0xBF], '').text()! == '\ufeff'
}
