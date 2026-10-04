// Copyright (c) 2022-2023, the SerenityOS developers.
// SPDX-License-Identifier: BSD-2-Clause

// FileAPI/Blob.cpp:409-419 returns a genuine Uint8Array sharing the exact
// read-all ArrayBuffer. Its relevant Realm supplies the engine view allocator.
module html

import fileapi
import streams
import webidl

pub fn (settings &EnvironmentSettingsObject) blob_bytes_in_realm(blob &fileapi.Blob, realm streams.StreamRealm) &webidl.Promise {
	mut promise := settings.read_all_blob_bytes_in_realm(blob, realm)
	return promise.upon_fulfillment(fn [realm] (argument webidl.Value) !webidl.Value {
		return realm.uint8_array_value(argument) or {
			panic('Source MUST: Blob Uint8Array record allocation failed: ${err.msg()}')
		}
	})
}
