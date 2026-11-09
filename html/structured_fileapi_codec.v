// Copyright (c) 2020-2022, the SerenityOS developers.
// SPDX-License-Identifier: BSD-2-Clause
// FileAPI/{Blob,File,FileList}.cpp payloads use the HTML source encoders.
module html

import fileapi

fn (mut serializer StructuredSerializer) write_blob_payload(blob &fileapi.Blob) ! {
	// Source's SnapshotState FIXME is retained; no invented snapshot field.
	serializer.write_utf16_string(blob.type_utf16())!
	serializer.write_bytes(blob.raw_bytes())!
}

fn (mut serializer StructuredSerializer) write_file_payload(file &fileapi.File) ! {
	serializer.write_utf16_string(file.type_utf16())!
	serializer.write_bytes(file.raw_bytes())!
	serializer.write_utf16_string(file.name_utf16())!
	serializer.write_i64(file.last_modified())
}

fn (mut serializer StructuredSerializer) write_fileapi_payload(object &StructuredObject) ! {
	interface_name := object.serializable_interface_ or { return error('DataCloneError: missing FileAPI primary interface') }
	match interface_name {
		.blob {
			blob := object.blob_ or { return error('DataCloneError: serializable Blob has no native record') }
			serializer.write_blob_payload(blob)!
		}
		.file {
			file := object.file_ or { return error('DataCloneError: serializable File has no native record') }
			serializer.write_file_payload(file)!
		}
		.file_list {
			list := object.file_list_ or { return error('DataCloneError: serializable FileList has no native record') }
			serializer.write_u64(u64(list.length()))
			for file in list.files() {
				// FileList.cpp calls File::serialization_steps directly. Inner
				// File identities do not enter the general serialization memory.
				serializer.write_tag(.serializable_object)
				serializer.write_serializable_interface(.file)!
				if serializer.type_ == .storage {
					serializer.write_u64(structured_serializable_payload_version)
				}
				serializer.write_file_payload(file)!
			}
		}
		else { return error('DataCloneError: invalid FileAPI primary interface') }
	}
}

fn (mut decoder StructuredDecoder) read_blob_payload(mut blob fileapi.Blob) ! {
	type_ := decoder.read_utf16_string()!
	bytes := decoder.read_bytes()!
	blob.deserialization_steps_utf16(type_, bytes)
}

fn (mut decoder StructuredDecoder) read_file_payload(mut file fileapi.File) ! {
	type_ := decoder.read_utf16_string()!
	bytes := decoder.read_bytes()!
	name := decoder.read_utf16_string()!
	last_modified := decoder.read_i64()!
	file.deserialization_steps_utf16(type_, bytes, name, last_modified)
}

fn (mut decoder StructuredDecoder) read_fileapi_payload(mut object StructuredObject) ! {
	interface_name := object.serializable_interface_ or { return error('DataCloneError: missing FileAPI primary interface') }
	match interface_name {
		.blob {
			mut blob := object.blob_ or { return error('DataCloneError: missing Blob target record') }
			decoder.read_blob_payload(mut blob)!
		}
		.file {
			mut file := object.file_ or { return error('DataCloneError: missing File target record') }
			decoder.read_file_payload(mut file)!
		}
		.file_list {
			mut list := object.file_list_ or { return error('DataCloneError: missing FileList target record') }
			count := decoder.read_collection_count(1)!
			for _ in 0 .. count {
				tag := decoder.read_u8()!
				name := decoder.read_serializable_interface()!
				if tag != u8(StructuredSerializeValueTag.serializable_object) || name != .file {
					return error('DataCloneError: Invalid FileList entry')
				}
				if decoder.type_ == .storage && decoder.read_u64()! != 1 {
					return error('DataCloneError: Unsupported FileList entry version')
				}
				// Source bypasses both general memory registration and the
				// inner File exposure gate in this direct nested payload path.
				mut file := fileapi.File.create([], '', '', 0)
				decoder.read_file_payload(mut file)!
				list.add_file(file)
			}
		}
		else { return error('DataCloneError: invalid FileAPI primary interface') }
	}
}
