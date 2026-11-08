// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Blob.textStream(), upstream Bindings/Rust/src/file_api/blob.rs at 2919bf87a5e:
// pipe the owning Blob byte stream through a fresh UTF-8 TextDecoderStream.
module html

import encoding
import fileapi
import streams

pub fn (settings &EnvironmentSettingsObject) blob_text_stream_in_realm(blob &fileapi.Blob, realm streams.StreamRealm) !&streams.ReadableStream {
	mut source := settings.get_blob_stream_in_realm(blob, realm)
	mut decoder := encoding.TextDecoderStream.create('utf-8', encoding.TextDecoderOptions{})!
	mut transform := streams.TransformStream.create(realm, streams.Transformer{
		transform: fn [mut decoder, realm] (chunk streams.Value) ![]streams.Value {
			bytes := if chunk.kind == .bytes { chunk.bytes_ } else {
				value := chunk.runtime_value_ or { return error('TypeError: Expected Blob byte chunk') }
				copy := realm.uint8_array_bytes or { return error('TypeError: Missing Blob byte realm') }
				actual := copy(value)!
				actual.bytes or { return error('TypeError: Expected Blob byte chunk') }
			}
			text := decoder.decode_and_enqueue_chunk(bytes)!
			return if text == '' { []streams.Value{} } else { [streams.string_value(text)] }
		}
		flush: fn [mut decoder] () ![]streams.Value {
			text := decoder.flush_and_enqueue()!
			return if text == '' { []streams.Value{} } else { [streams.string_value(text)] }
		}
	}, streams.QueuingStrategy{}, streams.QueuingStrategy{})!
	return source.piped_through(mut transform, false, false, false, none)
}
