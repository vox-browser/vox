module browserjs

import fileapi

fn test_source_sync_binary_string_projects_all_byte_units_to_a_genuine_native_primitive() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reader := fileapi.FileReaderSync.create()
	mut bytes := []u8{cap: 256}
	for index in 0 .. 256 { bytes << u8(index) }
	blob := fileapi.Blob.create(bytes, '')
	actual := runtime.javascript_file_reader_sync_binary_string(reader, blob)!
	runtime.define_value_host_function('__syncBinary', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	assert runtime.evaluate_host('(function(){const result=__syncBinary();if(typeof result!=="string"||result.length!==256)return false;for(let i=0;i<256;i++)if(result.charCodeAt(i)!==i)return false;return true})()')! == 'true'
	units := runtime.native_utf16_string(actual)!.code_units()
	for index in 0 .. 256 {
		assert units[index] == u16(index)
	}
	bytes[0] = 99
	assert runtime.native_utf16_string(actual)!.code_units()[0] == 0
	empty := runtime.javascript_file_reader_sync_binary_string(reader, fileapi.Blob.create([], ''))!
	assert runtime.native_utf16_string(empty)!.code_units().len == 0
}

fn test_source_sync_binary_string_uses_target_runtime_after_poisoned_string_and_global_aliases() {
	$if !darwin {
		return
	}
	mut first_runtime := Runtime.create()
	defer { first_runtime.close() }
	mut second_runtime := Runtime.create()
	defer { second_runtime.close() }
	reader := fileapi.FileReaderSync.create()
	blob := fileapi.Blob.create([u8(0), 0x41, 255, 0], '')
	first_runtime.evaluate_host('globalThis.String=function(){throw new Error("poisoned String")};globalThis.globalThis={String:function(){throw new Error("poisoned alias")}};undefined')!
	first := first_runtime.javascript_file_reader_sync_binary_string(reader, blob)!
	second := second_runtime.javascript_file_reader_sync_binary_string(reader, blob)!
	assert first_runtime.native_utf16_string(first)!.code_units() == [u16(0), 0x41, 255, 0]
	assert second_runtime.native_utf16_string(second)!.code_units() == [u16(0), 0x41, 255, 0]
	first_runtime.define_value_host_function('__syncBinary', fn [first] (_ voidptr, _ []voidptr) !voidptr {
		return first
	})!
	assert first_runtime.evaluate_host('typeof __syncBinary()==="string"&&__syncBinary().length===4')! == 'true'
}
