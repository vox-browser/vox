module browserjs

import fileapi

fn test_source_sync_text_reprocesses_malformed_utf8_prefix_into_actual_owned_primitive() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reader := fileapi.FileReaderSync.create()
	for input in [[u8(0xe1), `A`, 0], [u8(0xe1), 0x80, `A`, 0]] {
		blob := fileapi.Blob.create(input, '')
		actual := runtime.javascript_file_reader_sync_text(reader, blob, none)!
		assert runtime.native_utf16_string(actual)!.code_units() == [u16(0xfffd), u16(`A`), 0]
	}
	final_partial := runtime.javascript_file_reader_sync_text(reader, fileapi.Blob.create([
		u8(0xe1),
		0x80,
	], ''), none)!
	assert runtime.native_utf16_string(final_partial)!.code_units() == [u16(0xfffd)]
}

fn test_source_sync_text_projects_owned_bom_decoding_units_to_native_primitive() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reader := fileapi.FileReaderSync.create()
	mut bytes := [u8(0xef), 0xbb, 0xbf, 0x41, 0, 0xf0, 0x9f, 0x98, 0x80]
	blob := fileapi.Blob.create(bytes, 'text/plain;charset=windows-1252')
	actual := runtime.javascript_file_reader_sync_text(reader, blob, 'UTF-16LE')!
	assert runtime.native_utf16_string(actual)!.code_units() == [u16(0x41), 0, 0xd83d, 0xde00]
	bytes[3] = 0x42
	assert runtime.native_utf16_string(actual)!.code_units()[0] == 0x41
	runtime.define_value_host_function('__syncText', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	assert runtime.evaluate_host('typeof __syncText()==="string"&&__syncText().length===4&&__syncText().charCodeAt(1)===0&&__syncText().charCodeAt(2)===55357')! == 'true'
	be := runtime.javascript_file_reader_sync_text(reader, fileapi.Blob.create([
		u8(0xfe),
		0xff,
		0,
		0x42,
	], ''), 'windows-1252')!
	assert runtime.native_utf16_string(be)!.code_units() == [u16(0x42)]
	replacement := runtime.javascript_file_reader_sync_text(reader, fileapi.Blob.create([u8(255)], ''), none)!
	assert runtime.native_utf16_string(replacement)!.code_units() == [u16(0xfffd)]
	empty := runtime.javascript_file_reader_sync_text(reader, fileapi.Blob.create([], ''), none)!
	assert runtime.native_utf16_string(empty)!.code_units().len == 0
}

fn test_source_sync_text_uses_typed_label_fallback_and_actual_target_runtimes() {
	$if !darwin {
		return
	}
	mut first_runtime := Runtime.create()
	defer { first_runtime.close() }
	mut second_runtime := Runtime.create()
	defer { second_runtime.close() }
	reader := fileapi.FileReaderSync.create()
	blob := fileapi.Blob.create([u8(0x80), 0], 'text/plain;charset=windows-1252')
	first_runtime.evaluate_host('globalThis.String=function(){throw new Error("poisoned String")};globalThis.globalThis={String:function(){throw new Error("poisoned alias")}};undefined')!
	first := first_runtime.javascript_file_reader_sync_text(reader, blob, 'invalid-label')!
	second := second_runtime.javascript_file_reader_sync_text(reader, blob, none)!
	assert first_runtime.native_utf16_string(first)!.code_units() == [u16(0x20ac), 0]
	assert second_runtime.native_utf16_string(second)!.code_units() == [u16(0x20ac), 0]
	explicit_utf8 := first_runtime.javascript_file_reader_sync_text(reader, blob, 'UTF-8')!
	assert first_runtime.native_utf16_string(explicit_utf8)!.code_units() == [
		u16(0xfffd),
		0,
	]
}

fn test_source_sync_text_uses_selected_shift_jis_whole_decoder_for_owned_native_primitive() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reader := fileapi.FileReaderSync.create()
	// These bytes/units are witnessed by the original whole-input Source FFI.
	japanese := fileapi.Blob.create([u8(0x82), 0xa0], 'text/plain;charset=windows-1252')
	explicit := runtime.javascript_file_reader_sync_text(reader, japanese, 'windows-31j')!
	assert runtime.native_utf16_string(explicit)!.code_units() == [u16(0x3042)]
	malformed := fileapi.Blob.create([u8(0x82), 0], 'text/plain;charset=Shift_JIS')
	fallback := runtime.javascript_file_reader_sync_text(reader, malformed, 'invalid-label')!
	assert runtime.native_utf16_string(fallback)!.code_units() == [u16(0xfffd), 0]
	// A genuine Unicode BOM still selects the Unicode whole decoder.
	unicode := fileapi.Blob.create([u8(0xff), 0xfe, 0x41, 0], '')
	bom := runtime.javascript_file_reader_sync_text(reader, unicode, 'Shift_JIS')!
	assert runtime.native_utf16_string(bom)!.code_units() == [u16(0x41)]
}

fn test_source_sync_text_uses_whole_utf8_bom_order_for_owned_native_primitive() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reader := fileapi.FileReaderSync.create()
	// After initial sniffing, the remaining two-BOM span/output is witnessed
	// by the actual whole UTF8 FFI with matching-BOM removal enabled.
	blob := fileapi.Blob.create([u8(0xef), 0xbb, 0xbf, 0xef, 0xbb, 0xbf, 0xef, 0xbb, 0xbf, `Z`], '')
	actual := runtime.javascript_file_reader_sync_text(reader, blob, 'Shift_JIS')!
	assert runtime.native_utf16_string(actual)!.code_units() == [u16(0xfeff), u16(`Z`)]
}
