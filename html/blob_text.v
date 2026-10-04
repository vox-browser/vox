// Copyright (c) 2022-2023, the SerenityOS developers.
// SPDX-License-Identifier: BSD-2-Clause

// FileAPI/Blob.cpp::text returns the fulfillment of its actual owning byte
// Promise, with UTF-8 fallback and LibTextCodec's pinned BOM override.
module html

import encoding
import fileapi
import libjs
import streams
import webidl

pub fn (settings &EnvironmentSettingsObject) blob_text(blob &fileapi.Blob) &webidl.Promise {
	return settings.blob_text_in_realm(blob, settings.stream_realm())
}

pub fn (settings &EnvironmentSettingsObject) blob_text_in_realm(blob &fileapi.Blob, realm streams.StreamRealm) &webidl.Promise {
	mut promise := settings.read_all_blob_bytes_in_realm(blob, realm)
	return promise.upon_fulfillment(fn [realm] (argument webidl.Value) !webidl.Value {
		bytes := realm.array_buffer_bytes(argument)!
		text := encoding.convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', bytes)!
		return webidl.string_utf16_value(libjs.utf16_string(text))
	})
}
