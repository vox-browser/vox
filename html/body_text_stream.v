// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Fetch/Body.cpp and Bindings/Rust/src/fetch.rs, adapted to the native V owner.
module html

import encoding
import fetch
import streams

// Blob and fetch bodies share a streaming UTF-8 decoder. The returned stream
// belongs to the receiver's realm and never consults author constructors.
fn create_utf8_text_decoder_transform(realm streams.StreamRealm) !&streams.TransformStream {
	mut decoder := encoding.TextDecoderStream.create('utf-8', encoding.TextDecoderOptions{})!
	return streams.TransformStream.create(realm, streams.Transformer{
		transform: fn [mut decoder, realm] (chunk streams.Value) ![]streams.Value {
			bytes := if chunk.kind == .bytes { chunk.bytes_ } else {
				value := chunk.runtime_value_ or { return error('TypeError: Expected a Uint8Array chunk') }
				copy := realm.uint8_array_bytes or { return error('TypeError: Missing byte realm') }
				actual := copy(value)!
				actual.bytes or { return error('TypeError: Expected a Uint8Array chunk') }
			}
			text := decoder.decode_chunk(bytes)!
			return if text == '' { []streams.Value{} } else { [streams.string_value(text)] }
		}
		flush: fn [mut decoder] () ![]streams.Value {
			text := decoder.flush()!
			return if text == '' { []streams.Value{} } else { [streams.string_value(text)] }
		}
	}, streams.QueuingStrategy{}, streams.QueuingStrategy{})
}

pub fn (_ &EnvironmentSettingsObject) body_text_stream_in_realm(body fetch.BodyMixin,
	realm streams.StreamRealm) !&streams.ReadableStream {
	if body.is_unusable() { return error('TypeError: Body is unusable') }
	value := body.body or {
		mut empty := streams.ReadableStream.create_for_constructor(realm, streams.UnderlyingSource{},
			streams.QueuingStrategy{})!
		empty.close()
		return empty
	}
	mut source := value.stream()
	// Byte-backed Fetch records have no script realm until the binding exposes
	// them; an author-provided stream keeps its own callback realm.
	if source.realm().id == 0 { source.set_realm(realm) }
	transform := create_utf8_text_decoder_transform(realm)!
	return source.pipe_through(streams.ReadableWritablePair{
		readable: transform.readable()
		writable: transform.writable()
	}, streams.StreamPipeOptions{})
}
