// Copyright (c) 2023-2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Actual settings/Document side of FileAPI's cyclic HTML boundary.
module html

import dom
import domurl
import fileapi
import url as liburl

pub fn (settings &EnvironmentSettingsObject) blob_url_settings_origin() liburl.Origin {
	return settings.origin().liburl_origin() or {
		panic('Source Blob URL settings require an actual typed origin')
	}
}

pub fn (settings &EnvironmentSettingsObject) blob_url_settings_identity() voidptr {
	return voidptr(settings)
}

pub fn (settings &EnvironmentSettingsObject) blob_url_partition_origin() liburl.Origin {
	return settings.blob_url_settings_origin()
}

pub fn (environment &Environment) blob_url_partition_origin() liburl.Origin {
	if environment.settings_handle != unsafe { nil } {
		settings := unsafe { &EnvironmentSettingsObject(environment.settings_handle) }
		return settings.blob_url_partition_origin()
	}
	creation := environment.creation_url.parsed() or {
		panic('Source Blob URL Environment requires an actual creation URL')
	}
	return creation.origin()
}

// DOMURL::create_object_url/FileAPI::add_entry_to_blob_url_store obtain the
// current settings from the actual execution-context stack.
pub fn create_object_url(object fileapi.BlobURLObject) !string {
	return domurl.DOMURL.create_object_url(object, current_principal_settings_object())
}

pub fn revoke_object_url(value string) {
	domurl.DOMURL.revoke_object_url(value, current_principal_settings_object())
}

pub fn run_blob_url_unloading_cleanup_steps(document &dom.Document) {
	owner := document.relevant_settings_object()
	if owner == unsafe { nil } { return }
	settings := unsafe { &EnvironmentSettingsObject(owner) }
	mut store := fileapi.blob_url_store()
	store.run_unloading_cleanup_steps(settings)
}
