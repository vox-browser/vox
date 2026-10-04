// Copyright (c) 2022-2023, the SerenityOS developers.
// SPDX-License-Identifier: BSD-2-Clause

// FileAPI/Blob.cpp:395-406 copies the read-all ArrayBuffer into a new
// relevant-realm ArrayBuffer in the Source fulfillment reaction.
module html

import fileapi
import streams
import webidl

pub fn (settings &EnvironmentSettingsObject) blob_array_buffer(blob &fileapi.Blob) &webidl.Promise {
	return settings.blob_array_buffer_in_realm(blob, settings.stream_realm())
}

pub fn (settings &EnvironmentSettingsObject) blob_array_buffer_in_realm(blob &fileapi.Blob, realm streams.StreamRealm) &webidl.Promise {
	mut promise := settings.read_all_blob_bytes_in_realm(blob, realm)
	return promise.upon_fulfillment(fn [realm] (argument webidl.Value) !webidl.Value {
		bytes := realm.array_buffer_bytes(argument) or { panic('Source VERIFY: Blob ArrayBuffer data: ${err.msg()}') }
		return realm.array_buffer_value(bytes) or { panic('Source MUST: Blob ArrayBuffer copy allocation failed: ${err.msg()}') }
	})
}
