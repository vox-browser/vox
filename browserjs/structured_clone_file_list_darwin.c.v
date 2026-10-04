// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// FileList's actual primary SerializablePlatformObject record.
module browserjs

import fileapi

fn (runtime &Runtime) native_clone_file_list(value voidptr) ?&fileapi.FileList {
	host := file_list_bindings_[voidptr(runtime)] or { return none }
	if host.closed { return none }
	record := host.by_wrapper[value] or { return none }
	if voidptr(record.host) != voidptr(host) { return none }
	return record.list
}
