// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Serializable Blob identity is its actual wrapper owner and immutable record.
module browserjs

import fileapi

fn (runtime &Runtime) native_clone_blob(value voidptr) ?&fileapi.Blob {
	host := blob_bindings_[voidptr(runtime)] or { return none }
	if host.closed { return none }
	record := host.by_wrapper[value] or { return none }
	if voidptr(record.host) != voidptr(host) { return none }
	return record.blob
}
