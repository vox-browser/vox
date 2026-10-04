module fileapi

fn test_source_file_reader_text_package_bom_overrides_explicit_and_mime_fallback_encodings() {
	le := [u8(0xff), 0xfe, 0x41, 0]
	be := [u8(0xfe), 0xff, 0, 0x42]
	utf8 := [u8(0xef), 0xbb, 0xbf, 0x43]
	assert blob_package_data(le, .text, 'text/plain;charset=utf-8', 'windows-1252')!.text == 'A'
	assert blob_package_data(be, .text, 'text/plain;charset=windows-1252', 'UTF-8')!.text == 'B'
	assert blob_package_data(utf8, .text, 'text/plain;charset=windows-1252', 'UTF-16LE')!.text == 'C'
	assert blob_package_data(be, .text, 'text/plain;charset=windows-1252', 'invalid-label')!.text == 'B'
	assert blob_package_data(le, .text, none, none)!.text == 'A'
	// Without a BOM, Source still selects explicit label, MIME charset, UTF8.
	assert blob_package_data([u8(0x80)], .text, 'text/plain;charset=utf-8', 'windows-1252')!.text == '€'
	assert blob_package_data([u8(0x80)], .text, 'text/plain;charset=windows-1252', 'invalid-label')!.text == '€'
	assert blob_package_data([u8(0xff)], .text, 'invalid-mime', 'invalid-label')!.text == '\ufffd'
}

fn test_source_file_reader_package_preserves_pinned_repeated_bom_removal_and_opposing_bom() {
	assert FileReader.blob_package_data([u8(0xef), 0xbb, 0xbf, 0xef, 0xbb, 0xbf], .text,
		none, 'windows-1252')!.text == ''
	assert FileReader.blob_package_data([u8(0xef), 0xbb, 0xbf, 0xef, 0xbb, 0xbf, 0xef, 0xbb, 0xbf], .text, none, 'windows-1252')!.text == '\ufeff'
	assert FileReader.blob_package_data([u8(0xff), 0xfe, 0xfe, 0xff], .text, none,
		'UTF-8')!.text == '\ufffe'
}

fn test_source_file_reader_sync_and_existing_async_compatibility_consume_correct_text_package() {
	blob := Blob.create([u8(0xff), 0xfe, 0x41, 0], 'text/plain;charset=utf-8')
	sync_reader := FileReaderSync.construct_impl()
	assert sync_reader.read_as_text(blob, 'windows-1252')! == 'A'
	mut reader := FileReader.create()
	reader.read_as_text(blob, 'windows-1252')!
	assert reader.ready_state() == .loading
	assert reader.result().kind == .null_
	reader.process_pending_tasks()
	assert reader.ready_state() == .done
	assert reader.result().text == 'A'
	assert reader.event_log() == ['loadstart', 'progress', 'load', 'loadend']
}
