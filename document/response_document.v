module main

import encoding.base64
import mimesniff

fn browser_navigation_response_markup(body string, content_type string) string {
	if content_type.to_lower().contains('html') {
		return body
	}
	if mime := mimesniff.MimeType.parse(content_type) {
		// SVG is an active XML document when navigated to directly. Keep its
		// namespaces, CDATA and scripts for the XML parser.
		if mime.is_xml() { return body }
		if mime.type_() == 'image' {
			// Reuse the already-fetched bytes through the ordinary image decoder.
			// Binary image data must never enter the text document's <pre> path.
			source := 'data:${mime.essence()};base64,${base64.encode_str(body)}'
			return '<!doctype html><html><head><title>Image</title><style>html{background:#0e0e0e}body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center}img{display:block;max-width:100vw;max-height:100vh}</style></head><body><img src="${source}" alt="Image"></body></html>'
		}
	}
	return '<html><body><h1>${html_escape(content_type)}</h1><pre>${html_escape(body)}</pre></body></html>'
}
