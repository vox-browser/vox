module fileapi

fn test_source_file_reader_text_package_accepts_internal_replacement_encodings() {
	for label in ['csiso2022kr', 'hz-gb-2312', 'iso-2022-cn', 'iso-2022-cn-ext', 'iso-2022-kr',
		'replacement'] {
		assert blob_package_data([], .text, none, label)!.text == ''
		assert blob_package_data('AB'.bytes(), .text, 'text/plain;charset=utf-8', label)!.text == '\ufffd'
		assert blob_package_data('AB'.bytes(), .text, 'text/plain;charset=${label}', none)!.text == '\ufffd'
		assert blob_package_data('AB'.bytes(), .text, 'text/plain;charset=${label}', 'invalid-label')!.text == '\ufffd'
		// A valid explicit label keeps precedence over a MIME replacement label.
		assert blob_package_data('AB'.bytes(), .text, 'text/plain;charset=${label}', 'UTF-8')!.text == 'AB'
		assert blob_package_data([u8(0xff), 0xfe, 0x41, 0], .text, none, label)!.text == 'A'
	}
	blob := Blob.create('AB'.bytes(), 'text/plain;charset=iso-2022-kr')
	reader := FileReaderSync.construct_impl()
	assert reader.read_as_text(blob, none)! == '\ufffd'
}
