// Copyright (c) 2022-2023, the SerenityOS developers.
// SPDX-License-Identifier: BSD-2-Clause

// FileAPI/Blob.cpp::text returns the fulfillment of its actual owning byte
// Promise, using the UTF-8 decoder without sniffing another encoding.
// Upstream 2919bf87a5e: Blob.cpp::web_blob_text calls utf8_decode_to_utf16.
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
		decoder := encoding.TextDecoder.create()
		text := decoder.decode(bytes, encoding.TextDecodeOptions{})!
		return webidl.string_utf16_value(libjs.utf16_string(text))
	})
}
