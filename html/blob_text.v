// Copyright (c) 2022-2023, the SerenityOS developers.
// SPDX-License-Identifier: BSD-2-Clause

// FileAPI/Blob.cpp::text returns the fulfillment of its actual owning byte
// Promise, with UTF-8 fallback and LibTextCodec's pinned BOM override.
module html

import encoding
import fileapi
import libjs
import webidl

pub fn (settings &EnvironmentSettingsObject) blob_text(blob &fileapi.Blob) &webidl.Promise {
	mut promise := settings.read_all_blob_bytes(blob)
	return promise.upon_fulfillment(fn (argument webidl.Value) !webidl.Value {
		buffer := argument.buffer_value or { panic('Source VERIFY: Blob text result is an ArrayBuffer') }
		assert buffer.kind == .array_buffer, 'Source VERIFY: Blob text result is an ArrayBuffer'
		text := encoding.convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', webidl.get_buffer_source_copy(buffer))!
		return webidl.string_utf16_value(libjs.utf16_string(text))
	})
}
