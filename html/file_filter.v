// Copyright (c) 2024, Tim Flynn <trflynn89@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/FileFilter.cpp.
module html

pub enum FileFilterFileType {
	audio
	image
	video
}

pub struct FileFilterMimeType {
pub:
	value string
}

pub struct FileFilterExtension {
pub:
	value string
}

pub type FileFilterType = FileFilterExtension | FileFilterFileType | FileFilterMimeType

pub struct FileFilter {
pub mut:
	filters []FileFilterType
}

fn file_filters_equal(a FileFilterType, b FileFilterType) bool {
	match a {
		FileFilterFileType {
			if b is FileFilterFileType {
				return a == (b as FileFilterFileType)
			}
			return false
		}
		FileFilterMimeType {
			if b is FileFilterMimeType {
				return a == (b as FileFilterMimeType)
			}
			return false
		}
		FileFilterExtension {
			if b is FileFilterExtension {
				return a == (b as FileFilterExtension)
			}
			return false
		}
	}
}

pub fn (mut file_filter FileFilter) add_filter(filter FileFilterType) {
	for existing in file_filter.filters {
		if file_filters_equal(existing, filter) {
			return
		}
	}
	file_filter.filters << filter
}

// IPC::encode/decode specializations from FileFilter.cpp. V has no function
// overloading, so each specialization carries its translated type name.
pub fn encode_file_filter_mime_type(mime_type FileFilterMimeType) []u8 {
	mut output := []u8{}
	select_item_append_string(mut output, mime_type.value)
	return output
}

pub fn decode_file_filter_mime_type(data []u8) !FileFilterMimeType {
	mut decoder := SelectItemDecoder{data: data}
	value := decoder.read_string()!
	if decoder.offset != data.len {
		return error('trailing FileFilter MIME type IPC data')
	}
	return FileFilterMimeType{value}
}

pub fn encode_file_filter_extension(extension FileFilterExtension) []u8 {
	mut output := []u8{}
	select_item_append_string(mut output, extension.value)
	return output
}

pub fn decode_file_filter_extension(data []u8) !FileFilterExtension {
	mut decoder := SelectItemDecoder{data: data}
	value := decoder.read_string()!
	if decoder.offset != data.len {
		return error('trailing FileFilter extension IPC data')
	}
	return FileFilterExtension{value}
}

pub fn encode_file_filter(filter FileFilter) []u8 {
	mut output := []u8{}
	select_item_append_u32(mut output, u32(filter.filters.len))
	for entry in filter.filters {
		match entry {
			FileFilterFileType {
				output << u8(0)
				output << u8(entry)
			}
			FileFilterMimeType {
				output << u8(1)
				select_item_append_string(mut output, entry.value)
			}
			FileFilterExtension {
				output << u8(2)
				select_item_append_string(mut output, entry.value)
			}
		}
	}
	return output
}

pub fn decode_file_filter(data []u8) !FileFilter {
	mut decoder := SelectItemDecoder{data: data}
	count := int(decoder.read_u32()!)
	mut filter := FileFilter{}
	for _ in 0 .. count {
		tag := decoder.read_u8()!
		match tag {
			0 {
				value := decoder.read_u8()!
				if value > u8(FileFilterFileType.video) {
					return error('invalid FileFilter file type IPC value')
				}
				filter.filters << unsafe { FileFilterFileType(value) }
			}
			1 { filter.filters << FileFilterMimeType{decoder.read_string()!} }
			2 { filter.filters << FileFilterExtension{decoder.read_string()!} }
			else { return error('invalid FileFilter IPC variant tag') }
		}
	}
	if decoder.offset != data.len {
		return error('trailing FileFilter IPC data')
	}
	return filter
}
