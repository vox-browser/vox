// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module html

pub fn (settings &EnvironmentSettingsObject) fetch_request_client_is_svg_image() bool {
	document := settings.responsible_document() or { return false }
	return document.is_svg_image_document()
}
