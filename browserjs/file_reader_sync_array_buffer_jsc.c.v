// Copyright (c) 2025, Tim Ledbetter <tim.ledbetter@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause
// FileReaderSync.cpp::read_as_array_buffer uses the caller's actual Realm.
module browserjs

import fileapi
import webidl


// The actual implementation and Blob are supplied by the owning binding.
// Dedicated/SharedWorker receiver/interface exposure remains separate.
pub fn (mut runtime Runtime) source_file_reader_sync_array_buffer(reader &fileapi.FileReaderSync, blob &fileapi.Blob) !webidl.Value {
	runtime.require_javascript_value_context()!
	bytes := reader.read_as_array_buffer_impl(blob)!
	return runtime.source_array_buffer(bytes)
}

// Source's BinaryString method returns read_as<Utf16String>; the generated
// binding consumes that owned record at the target VM's primitive-string ABI.
pub fn (mut runtime Runtime) javascript_file_reader_sync_binary_string(reader &fileapi.FileReaderSync, blob &fileapi.Blob) !voidptr {
	runtime.require_javascript_value_context()!
	result := reader.read_as(blob, .binary_string, none)!
	raw := result.string_utf16_record() or { panic('Source VERIFY: FileReaderSync BinaryString requires its UTF16 result') }
	return runtime.javascript_utf16_string(raw)
}

// Source's DataURL return retains the unchecked ASCII owner's code units at
// the primitive ABI, independently of its diagnostic/raw UTF8 byte projection.
pub fn (mut runtime Runtime) javascript_file_reader_sync_data_url(reader &fileapi.FileReaderSync, blob &fileapi.Blob) !voidptr {
	runtime.require_javascript_value_context()!
	result := reader.read_as(blob, .data_url, none)!
	raw := result.string_utf16_record() or { panic('Source VERIFY: FileReaderSync DataURL requires its UTF16 result') }
	return runtime.javascript_utf16_string(raw)
}

// Source's Text method returns its owning read_as<Utf16String> result. The
// encoding label stays the existing typed UTF8 compatibility input boundary;
// generated optional DOMString conversion belongs to the public Worker binding.
pub fn (mut runtime Runtime) javascript_file_reader_sync_text(reader &fileapi.FileReaderSync, blob &fileapi.Blob, encoding_name ?string) !voidptr {
	runtime.require_javascript_value_context()!
	result := reader.read_as(blob, .text, encoding_name)!
	raw := result.string_utf16_record() or { panic('Source VERIFY: FileReaderSync Text requires its UTF16 result') }
	return runtime.javascript_utf16_string(raw)
}
