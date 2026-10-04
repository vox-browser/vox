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
