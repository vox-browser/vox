// Copyright (c) 2024, Tim Flynn <trflynn89@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of SelectedFile.cpp. IPC encoder/decoder bindings are outside
// LibWeb and are therefore not reproduced here.
module html

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

pub fn (mut file SelectedFile) take_contents() []u8 {
	if file.file_or_contents is []u8 {
		contents := file.file_or_contents as []u8
		file.file_or_contents = []u8{}
		return contents
	}
	panic('SelectedFile.take_contents() requires in-memory contents')
}
