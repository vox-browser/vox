// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module css

import dom

__global import_mime_test_source ImportedStyleSheetSource

fn import_mime_test_loader(_ &dom.Document, _ string) ?ImportedStyleSheetSource {
	return import_mime_test_source
}

// Ladybird 0e61955a3ff8c5099de5ff0d419eb3a2075b66d7.
fn test_import_uses_response_mime_and_requires_cors_same_origin_for_quirks_exception() {
	install_remote_style_sheet_loader(import_mime_test_loader)
	defer { install_remote_style_sheet_loader(none) }
	for content_type in ['text/plain', 'text/css; charset=utf-8', '', 'invalid'] {
		for quirks in [false, true] {
			for cors_same_origin in [false, true] {
				mut document := dom.Document.create(dom.URL{value: 'https://imports.test/'})
				defer { document.finalize() }
				document.set_quirks_mode(if quirks { .yes } else { .no })
				// Even a same-origin final URL can have an opaque response after
				// a cross-origin redirect. The transport's tainting decides.
				import_mime_test_source = ImportedStyleSheetSource{
					css_text: 'body { --secret: credentialed-response; }'
					response_url: 'https://imports.test/response'
					content_type: content_type
					cors_same_origin: cors_same_origin
				}
				sheet := parse_css_style_sheet_for_owner_node(document, '@import "/resource";', document.url.serialize())
				loaded := sheet.import_rules[0].loaded_style_sheet_for_bindings()
				assert (loaded != none) == (content_type != 'text/plain' || (quirks && cors_same_origin))
			}
		}
	}
}
