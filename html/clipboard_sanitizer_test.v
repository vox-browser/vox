module html

import editing

fn test_clipboard_html_sanitizer_removes_active_content_and_unsafe_attributes() {
	document := parse_document('<div id="editor">ab</div>')
	editor := document.get_element_by_id('editor') or { panic('missing editor') }
	mut range := document.create_range()
	range.select_node_contents(editor.as_node()) or { panic(err) }

	fragment := editing.sanitize_clipboard_html(range,
		'<base href="https://evil.test/"><b id="safe" style="color: red" onclick="run()">safe</b><script>run()</script><iframe srcdoc="<script>run()</script>"></iframe><a id="link" href="JAVASCRIPT:run()">link</a><img id="image" src="/safe.png" onerror="run()"><style>#editor{display:none}</style>') or {
		panic(err)
	}

	sanitized := fragment.as_node().serialize_fragment(.no, .inner)!
	assert !sanitized.contains('<base')
	assert !sanitized.contains('<script')
	assert !sanitized.contains('<iframe')
	assert !sanitized.contains('<style')
	assert !sanitized.contains('onclick')
	assert !sanitized.contains('onerror')
	assert !sanitized.contains('javascript:')
	assert sanitized.contains('<b id="safe" style="color: red">safe</b>')
	assert sanitized.contains('<a id="link">link</a>')
	assert sanitized.contains('<img id="image" src="/safe.png">')
}

fn test_clipboard_html_sanitizer_preserves_inert_markup_and_safe_urls() {
	document := parse_document('<div id="editor"></div>')
	editor := document.get_element_by_id('editor') or { panic('missing editor') }
	mut range := document.create_range()
	range.select_node_contents(editor.as_node()) or { panic(err) }

	fragment := editing.sanitize_clipboard_html(range,
		'<section data-note="on purpose"><a href="https://example.test/path">safe</a><img src="data:image/png;base64,AA=="></section>') or {
		panic(err)
	}
	sanitized := fragment.as_node().serialize_fragment(.no, .inner)!
	assert sanitized == '<section data-note="on purpose"><a href="https://example.test/path">safe</a><img src="data:image/png;base64,AA=="></section>'
}
