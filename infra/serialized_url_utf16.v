// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Libraries/LibWeb/Infra/SerializedURL.h16–24's actual owned return record.
module infra

import libjs

// Keep the Source record at callers that require its raw ASCII storage and
// code-unit projection. The existing string helper remains a compatibility
// projection for older URL/string consumers.
pub fn utf16_string_record_from_url_ascii(value string) libjs.Utf16String {
	return libjs.utf16_string_from_ascii_without_validation(value.bytes())
}
