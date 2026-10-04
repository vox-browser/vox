// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Serializable File's primary interface overrides its genuine Blob base.
module browserjs

import fileapi

fn (runtime &Runtime) native_clone_file(value voidptr) ?&fileapi.File {
	host := file_bindings_[voidptr(runtime)] or { return none }
	if host.closed { return none }
	record := host.by_wrapper[value] or { return none }
	if voidptr(record.host) != voidptr(host) { return none }
	return record.file
}
