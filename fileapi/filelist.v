// Copyright (c) 2022, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the self-contained core of Libraries/LibWeb/FileAPI/FileList.cpp — an ordered
// collection of File objects with a length and indexed item access. The legacy indexed-property
// binding is runtime-owned; typed structured serialization is represented below.
// https://w3c.github.io/FileAPI/#filelist-section
module fileapi

// https://w3c.github.io/FileAPI/#dfn-filelist
@[heap]
pub struct FileList {
mut:
	files []&File
	producer_target voidptr = unsafe { nil }
	producer fn (voidptr) []&File = unsafe { nil }
}

// FileList::create(realm) — an empty FileList.
pub fn FileList.create() &FileList {
	return &FileList{}
}

// A live producer supplies native files without changing this list's identity.
// Keeping the callback here avoids importing an owning API (such as HTML).
pub fn FileList.create_live(target voidptr, producer fn (voidptr) []&File) &FileList {
	return &FileList{producer_target: target, producer: producer}
}

fn (list &FileList) current_files() []&File {
	if list.producer != unsafe { nil } { return list.producer(list.producer_target) }
	return list.files
}

// FileList::add_file — append a File to the collection.
pub fn (mut list FileList) add_file(file &File) {
	list.files << file
}

// https://w3c.github.io/FileAPI/#dfn-length
pub fn (list &FileList) length() int {
	return list.current_files().len
}

// https://w3c.github.io/FileAPI/#dfn-item — the indexth File, or none when there is no such index.
pub fn (list &FileList) item(index int) ?&File {
	files := list.current_files()
	if index < 0 || index >= files.len {
		return none
	}
	return files[index]
}

pub fn (list &FileList) item_value(index int) ?&File {
	return list.item(index)
}

pub fn (list &FileList) files() []&File {
	return list.current_files().clone()
}

pub fn (list &FileList) serialization_steps() []SerializedFile {
	files := list.current_files()
	mut serialized := []SerializedFile{cap: files.len}
	for file in files {
		serialized << file.serialization_steps()
	}
	return serialized
}

pub fn FileList.deserialization_steps(serialized []SerializedFile) &FileList {
	mut list := FileList.create()
	for file in serialized {
		list.add_file(File.deserialization_steps(file))
	}
	return list
}
