module fileapi

fn test_standalone_blob_text_decodes_utf8_without_sniffing_utf16_or_mime_charset() {
	assert Blob.create([u8(0xFF), 0xFE, 0x61, 0], 'text/plain;charset=UTF-8').text()! == '\ufffd\ufffda\x00'
	assert Blob.create([u8(0xFE), 0xFF, 0, 0x61], '').text()! == '\ufffd\ufffd\x00a'
	assert Blob.create([u8(0xE9)], 'text/plain;charset=windows-1252').text()! == '\ufffd'
	assert Blob.create([u8(0xEF), 0xBB, 0xBF, 0xEF, 0xBB, 0xBF], '').text()! == '\ufeff'
	assert Blob.create([u8(0xEF), 0xBB, 0xBF, 0xEF, 0xBB, 0xBF, 0xEF, 0xBB, 0xBF], '').text()! == '\ufeff\ufeff'
}

fn test_blob_text_preserves_internal_bom_and_replaces_truncated_utf8() {
	assert Blob.create([u8(0x50), 0xEF, 0xBB, 0xBF], '').text()! == 'P\ufeff'
	assert Blob.create([u8(0x50), 0xC3], '').text()! == 'P\ufffd'
	assert Blob.construct([BlobPart.from_blob(Blob.create([u8(0xEF)], '')),
		BlobPart.from_bytes([u8(0xBB), 0xBF, 0xC3, 0xA9])], none).text()! == 'é'
}
