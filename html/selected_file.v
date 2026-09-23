// Copyright (c) 2024, Tim Flynn <trflynn89@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of SelectedFile.{h,cpp}, including its IPC specializations.
module html

import io
import os

pub enum AllowMultipleFiles {
	no
	yes
}

pub type SelectedFileData = []u8 | os.File

pub struct SelectedFile {
pub:
	name string
pub mut:
	file_or_contents SelectedFileData
}

pub fn SelectedFile.from_file_path(file_path string) !SelectedFile {
	// Filenames must not contain path components, even if an entire directory
	// hierarchy was selected.
	name := os.base(file_path)
	file := os.open(file_path)!
	return SelectedFile{
		name:             name
		file_or_contents: file
	}
}

pub fn SelectedFile.from_contents(name string, contents []u8) SelectedFile {
	return SelectedFile{
		name:             name
		file_or_contents: contents
	}
}

pub fn SelectedFile.from_file(name string, file os.File) SelectedFile {
	return SelectedFile{
		name:             name
		file_or_contents: file
	}
}

pub fn (file &SelectedFile) name() string {
	return file.name
}

pub fn (file &SelectedFile) file_or_contents() SelectedFileData {
	return file.file_or_contents
}

// Clipboard and picker boundaries own their snapshots. Clone in-memory bytes
// while retaining the same open file handle for descriptor-backed selections.
pub fn (file &SelectedFile) clone_for_transfer() SelectedFile {
	if file.file_or_contents is []u8 {
		return SelectedFile.from_contents(file.name, file.file_or_contents.clone())
	}
	return SelectedFile.from_file(file.name, file.file_or_contents as os.File)
}

pub fn (mut file SelectedFile) take_contents() []u8 {
	if file.file_or_contents is []u8 {
		contents := file.file_or_contents as []u8
		file.file_or_contents = []u8{}
		return contents
	}
	panic('SelectedFile.take_contents() requires in-memory contents')
}

fn selected_file_contents(file &SelectedFile) !([]u8, u8) {
	match file.file_or_contents {
		[]u8 {
			return file.file_or_contents.clone(), u8(1)
		}
		os.File {
			mut open_file := file.file_or_contents
			original_position := open_file.tell()!
			open_file.seek(0, .start)!
			contents := io.read_all(reader: open_file, read_to_end_of_stream: true)!
			open_file.seek(original_position, .start)!
			return contents, u8(0)
		}
	}
}

// IPC::encode(SelectedFile). File-backed selections retain the upstream
// variant tag; the standalone V boundary transports their bytes instead of an
// OS-specific descriptor and the decoder materializes both alternatives.
pub fn encode_selected_file(file &SelectedFile) ![]u8 {
	mut output := []u8{}
	select_item_append_string(mut output, file.name)
	contents, variant_tag := selected_file_contents(file)!
	output << variant_tag
	select_item_append_u32(mut output, u32(contents.len))
	output << contents
	return output
}

// IPC::decode(SelectedFile).
pub fn decode_selected_file(data []u8) !SelectedFile {
	mut decoder := SelectItemDecoder{data: data}
	name := decoder.read_string()!
	variant_tag := decoder.read_u8()!
	if variant_tag > 1 {
		return error('invalid SelectedFile IPC variant tag')
	}
	length := int(decoder.read_u32()!)
	if length > data.len - decoder.offset {
		return error('truncated SelectedFile IPC contents')
	}
	contents := data[decoder.offset..decoder.offset + length].clone()
	decoder.offset += length
	if decoder.offset != data.len {
		return error('trailing SelectedFile IPC data')
	}
	return SelectedFile.from_contents(name, contents)
}
