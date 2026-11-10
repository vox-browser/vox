// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Blob.textStream(), upstream Bindings/Rust/src/file_api/blob.rs at 2919bf87a5e:
// pipe the owning Blob byte stream through a fresh UTF-8 TextDecoderStream.
module html

import fileapi
import streams

pub fn (settings &EnvironmentSettingsObject) blob_text_stream_in_realm(blob &fileapi.Blob, realm streams.StreamRealm) !&streams.ReadableStream {
	mut source := settings.get_blob_stream_in_realm(blob, realm)
	mut transform := create_utf8_text_decoder_transform(realm)!
	return source.piped_through(mut transform, false, false, false, none)
}
