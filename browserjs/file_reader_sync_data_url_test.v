module browserjs

import fileapi
import libjs

fn test_source_sync_data_url_projects_unchecked_ascii_units_from_supplied_mime_compatibility_bytes() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reader := fileapi.FileReaderSync.create()
	// This internal owner supplies raw UTF8 compatibility MIME bytes. It
	// checks output storage/projection, not C++ MIME UTF16 conversion or the
	// public Blob constructor's independently normalized ASCII type.
	mime := libjs.utf16_string_from_code_units([u16(`x`), 0xd800, 0, 0x00e9, 0xdc00])
	blob := fileapi.Blob.create_utf16([u8(255), 0], mime)
	actual := runtime.javascript_file_reader_sync_data_url(reader, blob)!
	mut serialized := 'data:'.bytes()
	serialized << [u8(`x`), 0xed, 0xa0, 0x80, 0, 0xc3, 0xa9, 0xed, 0xb0, 0x80]
	serialized << ';base64,/wA='.bytes()
	units := runtime.native_utf16_string(actual)!.code_units()
	assert units.len == serialized.len
	for index, unit in units {
		assert unit == u16(char(serialized[index]))
	}
	runtime.define_value_host_function('__syncDataURL', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	assert runtime.evaluate_host('typeof __syncDataURL()==="string"&&__syncDataURL().charCodeAt(6)===65517&&__syncDataURL().charCodeAt(9)===0')! == 'true'
	// Genuine primitive units differ from decoding the retained WTF8 bytes.
	assert units != libjs.utf16_string_from_utf8_without_validation(serialized.bytestr()).code_units()
}

fn test_source_sync_data_url_uses_actual_target_runtime_with_empty_default_type_and_poisoned_aliases() {
	$if !darwin {
		return
	}
	mut first_runtime := Runtime.create()
	defer { first_runtime.close() }
	mut second_runtime := Runtime.create()
	defer { second_runtime.close() }
	reader := fileapi.FileReaderSync.create()
	blob := fileapi.Blob.create([], '')
	first_runtime.evaluate_host('globalThis.String=function(){throw new Error("poisoned String")};globalThis.globalThis={String:function(){throw new Error("poisoned alias")}};undefined')!
	first := first_runtime.javascript_file_reader_sync_data_url(reader, blob)!
	second := second_runtime.javascript_file_reader_sync_data_url(reader, blob)!
	expected := libjs.utf16_string_from_code_units('data:application/octet-stream;base64,'.bytes().map(u16(it))).code_units()
	assert first_runtime.native_utf16_string(first)!.code_units() == expected
	assert second_runtime.native_utf16_string(second)!.code_units() == expected
	first_runtime.define_value_host_function('__syncDataURL', fn [first] (_ voidptr, _ []voidptr) !voidptr {
		return first
	})!
	assert first_runtime.evaluate_host('typeof __syncDataURL()==="string"&&__syncDataURL()==="data:application/octet-stream;base64,"')! == 'true'
	ascii_blob := fileapi.Blob.construct_impl([fileapi.BlobPart.from_bytes([u8(255), 0])], fileapi.BlobPropertyBag{ type_: 'Text/Plain' })
	assert ascii_blob.type_() == 'text/plain'
	ascii_result := first_runtime.javascript_file_reader_sync_data_url(reader, ascii_blob)!
	assert first_runtime.native_utf16_string(ascii_result)!.code_units() == libjs.utf16('data:text/plain;base64,/wA=')
}
