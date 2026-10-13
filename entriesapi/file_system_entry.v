// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of EntriesAPI/FileSystemEntry.{h,cpp,idl}.
module entriesapi

import libjs

// The two kinds of entries represented by FileSystemEntry.
pub enum EntryType {
	file
	directory
}

// https://wicg.github.io/entries-api/#filesystementry
@[heap]
pub struct FileSystemEntry {
mut:
	entry_type_ EntryType
	name_       string
	name_utf16_ ?libjs.Utf16String
}

// FileSystemEntry.create is the V equivalent of the realm-allocating C++
// factory. V strings own their contents, so the returned object owns its name.
pub fn FileSystemEntry.create(entry_type EntryType, name string) &FileSystemEntry {
	return &FileSystemEntry{
		entry_type_: entry_type
		name_:       name
	}
}

// The DataTransfer producer's UTF-16 -> UTF-8 -> UTF-16 source round trip
// retains lone surrogates and null units. Keep its actual name beside the
// compatibility byte-string view without normalizing the USVString getter.
pub fn FileSystemEntry.create_utf16(entry_type EntryType, name libjs.Utf16String) &FileSystemEntry {
	return &FileSystemEntry{
		entry_type_: entry_type
		name_:       name.str()
		name_utf16_: name
	}
}

// https://wicg.github.io/entries-api/#dom-filesystementry-isfile
pub fn (entry &FileSystemEntry) is_file() bool {
	return entry.entry_type_ == .file
}

// https://wicg.github.io/entries-api/#dom-filesystementry-isdirectory
pub fn (entry &FileSystemEntry) is_directory() bool {
	return entry.entry_type_ == .directory
}

// https://wicg.github.io/entries-api/#dom-filesystementry-name
pub fn (entry &FileSystemEntry) name() string {
	return entry.name_
}

pub fn (entry &FileSystemEntry) name_utf16() libjs.Utf16String {
	if original := entry.name_utf16_ {
		if original.str() == entry.name_ { return original }
	}
	return libjs.utf16_string_from_utf8_without_validation(entry.name_)
}
