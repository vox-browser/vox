// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module layout

import dom

// Decoded SVG images can only load embedded data resources. Enforce this
// before handing a URL or cached raster bitmap to paint replay as well as at
// fetch time: an embedder's resource cache is shared with ordinary documents.
fn image_source_allowed_for_paint(document &dom.Document, source string) bool {
	if !document.is_svg_image_document() { return true }
	parsed := document.encoding_parse_url(source) or { return false }
	return parsed.scheme() == 'data'
}

fn allowed_paint_image_url(document &dom.Document, source string) string {
	return if image_source_allowed_for_paint(document, source) { source } else { '' }
}
