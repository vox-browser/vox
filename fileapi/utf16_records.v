// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// FileAPI::Blob/File keep Utf16String internal slots, not UTF-8 diagnostics.
module fileapi

import libjs

fn fileapi_preserved_utf16(text string, original ?libjs.Utf16String) libjs.Utf16String {
	if value := original {
		if value.str() == text { return value }
	}
	return libjs.utf16_string(text)
}
