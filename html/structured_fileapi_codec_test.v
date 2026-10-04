module html

import fileapi
import libjs

fn fileapi_codec_context() StructuredDeserializationContext {
	return StructuredDeserializationContext{
		is_exposed: fn (name StructuredSerializableInterface) bool {
			return name in [.blob, .file, .file_list]
		}
	}
}

fn fileapi_codec_record(object &StructuredObject, storage bool) !SerializationRecord {
	return if storage {
		structured_serialize_for_storage(structured_object_value(object))!
	} else {
		structured_serialize(structured_object_value(object))!
	}
}

fn test_source_blob_file_ipc_storage_payload_goldens_raw_slots_and_owned_bytes() {
	type_ := libjs.utf16_string_from_code_units([u16(0xd800), 0])
	name := libjs.utf16_string_from_code_units([u16(0xdc00)])
	blob := fileapi.Blob.create_utf16([u8(7), 9], type_)
	file := fileapi.File.create_utf16([u8(7), 9], name, type_, -7)
	objects := [StructuredObject.create_blob(blob), StructuredObject.create_file(file)]
	ipc_goldens := [
		[u8(24), 143, 0, 0, 2, 0, 0, 0, 0, 216, 0, 0, 2, 0, 0, 0, 7, 9],
		[u8(24), 144, 0, 0, 2, 0, 0, 0, 0, 216, 0, 0, 2, 0, 0, 0, 7, 9, 0, 1, 0, 0, 0, 0, 220,
			249, 255, 255, 255, 255, 255, 255, 255],
	]
	storage_goldens := [
		[u8(76), 66, 83, 67, 1, 0, 24, 9, 66, 108, 111, 98, 1, 4, 0, 216, 0, 0, 2, 7, 9],
		[u8(76), 66, 83, 67, 1, 0, 24, 9, 70, 105, 108, 101, 1, 4, 0, 216, 0, 0, 2, 7, 9, 2, 0,
			220, 121],
	]
	for index, object in objects {
		for storage in [false, true] {
			record := fileapi_codec_record(object, storage)!
			assert record.data == if storage { storage_goldens[index] } else { ipc_goldens[index] }
			decoded := structured_object_from_value(structured_deserialize_with_context(record, fileapi_codec_context())!)!
			if index == 0 {
				assert decoded.blob_?.type_utf16().code_units() == type_.code_units()
				assert decoded.blob_?.raw_bytes() == [u8(7), 9]
				assert voidptr(decoded.blob_?) != voidptr(blob)
			} else {
				assert decoded.file_?.type_utf16().code_units() == type_.code_units()
				assert decoded.file_?.name_utf16().code_units() == name.code_units()
				assert decoded.file_?.raw_bytes() == [u8(7), 9]
				assert decoded.file_?.last_modified() == -7
				assert voidptr(decoded.file_?) != voidptr(file)
			}
			if _ := structured_deserialize_with_context(record, StructuredDeserializationContext{}) {
				assert false
			}
			for length in 0 .. record.data.len {
				if _ := structured_deserialize_with_context(SerializationRecord{ data: record.data[..length], type_: record.type_ }, fileapi_codec_context()) {
					assert false
				}
			}
		}
	}
}

fn test_source_filelist_direct_nested_file_headers_exposure_and_distinct_memory() {
	file := fileapi.File.create([u8(9)], 'n', 't', -1)
	mut list := fileapi.FileList.create()
	list.add_file(file)
	list.add_file(file)
	object := StructuredObject.create_file_list(list)
	ipc_file := [u8(24), 144, 0, 1, 1, 0, 0, 0, 116, 1, 0, 0, 0, 9, 1, 1, 0, 0, 0, 110, 255, 255,
		255, 255, 255, 255, 255, 255]
	storage_file := [u8(24), 9, 70, 105, 108, 101, 1, 3, 116, 1, 9, 3, 110, 127]
	for storage in [false, true] {
		mut expected := if storage {
			[u8(76), 66, 83, 67, 1, 0, 24, 17, 70, 105, 108, 101, 76, 105, 115, 116, 1, 2]
		} else {
			[u8(24), 145, 0, 2, 0, 0, 0, 0, 0, 0, 0]
		}
		nested_offset := expected.len
		expected << if storage { storage_file } else { ipc_file }
		expected << if storage { storage_file } else { ipc_file }
		record := fileapi_codec_record(object, storage)!
		assert record.data == expected
		// Source FileList::deserialization_steps does not check File exposure.
		context := StructuredDeserializationContext{ is_exposed: fn (name StructuredSerializableInterface) bool {
			return name == .file_list
		} }
		decoded := structured_object_from_value(structured_deserialize_with_context(record, context)!)!.file_list_?
		assert decoded.length() == 2
		assert decoded.item(0)?.name() == 'n' && decoded.item(1)?.last_modified() == -1
		assert voidptr(decoded.item(0)?) != voidptr(decoded.item(1)?)
		assert voidptr(decoded.item(0)?) != voidptr(file)
		for length in 0 .. record.data.len {
			if _ := structured_deserialize_with_context(SerializationRecord{ data: record.data[..length], type_: record.type_ }, context) {
				assert false
			}
		}
		mut invalid_tag := record.data.clone()
		invalid_tag[nested_offset] = u8(StructuredSerializeValueTag.object_reference)
		if _ := structured_deserialize_with_context(SerializationRecord{ data: invalid_tag, type_: record.type_ }, context) {
			assert false
		} else {
			assert err.msg().contains('Invalid FileList entry')
		}
		mut invalid_interface := record.data.clone()
		invalid_interface[nested_offset + if storage { 2 } else { 1 }] = if storage {
			u8(`B`)
		} else {
			u8(143)
		}
		if _ := structured_deserialize_with_context(SerializationRecord{ data: invalid_interface, type_: record.type_ }, context) {
			assert false
		}
		if storage {
			mut invalid_version := record.data.clone()
			invalid_version[nested_offset + 6] = 2
			if _ := structured_deserialize_with_context(SerializationRecord{ data: invalid_version, type_: .storage }, context) {
				assert false
			} else {
				assert err.msg().contains('Unsupported FileList entry version')
			}
		}
		mut root := StructuredObject.create(.array)
		list_value := structured_object_value(object)
		file_value := structured_object_value(StructuredObject.create_file(file))
		root.values = [&list_value, &list_value, &file_value, &file_value]
		container := fileapi_codec_record(root, storage)!
		result := structured_object_from_value(structured_deserialize_with_context(container, fileapi_codec_context())!)!
		assert result.values[0].object_data == result.values[1].object_data
		assert result.values[2].object_data == result.values[3].object_data
		nested_list := structured_object_from_value(*result.values[0])!.file_list_?
		outer_file := structured_object_from_value(*result.values[2])!.file_?
		assert voidptr(nested_list.item(0)?) != voidptr(outer_file)
	}
}

fn test_source_file_i64_timestamp_native_bytes_and_signed_storage_width_gates() {
	values := [i64(0), -1, 63, 64, -64, -65, 128, -128, 9223372036854775807, -9223372036854775807 - 1]
	goldens := [
		[u8(0)],
		[u8(127)],
		[u8(63)],
		[u8(192), 0],
		[u8(64)],
		[u8(191), 127],
		[u8(128), 1],
		[u8(128), 127],
		[u8(255), 255, 255, 255, 255, 255, 255, 255, 255, 0],
		[u8(128), 128, 128, 128, 128, 128, 128, 128, 128, 127],
	]
	for index, value in values {
		mut writer := StructuredSerializer{ type_: .storage }
		writer.write_i64(value)
		assert writer.data == goldens[index]
		mut reader := StructuredDecoder{ type_: .storage, data: goldens[index] }
		assert reader.read_i64()! == value
		assert reader.offset == goldens[index].len
		mut ipc := StructuredSerializer{}
		ipc.write_i64(value)
		assert ipc.data.len == 8
		for byte in 0 .. 8 {
			assert ipc.data[byte] == u8(u64(value) >> (byte * 8))
		}
		mut ipc_reader := StructuredDecoder{ data: ipc.data }
		assert ipc_reader.read_i64()! == value
	}
	for invalid in [
		[u8(128)],
		[u8(128), 128, 128, 128, 128, 128, 128, 128, 128, 2],
		[u8(128), 128, 128, 128, 128, 128, 128, 128, 128, 126],
		[u8(128), 128, 128, 128, 128, 128, 128, 128, 128, 128],
	] {
		mut reader := StructuredDecoder{ type_: .storage, data: invalid }
		if _ := reader.read_i64() {
			assert false
		}
	}
	// Source signed LEB128 permits a longer valid zero representation.
	mut reader := StructuredDecoder{ type_: .storage, data: [u8(128), 0] }
	assert reader.read_i64()! == 0
}
