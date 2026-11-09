module html

import dom

fn test_parser_keeps_the_inline_script_start_line_for_host_execution() {
	mut document := parse_document('<!doctype html>
<head></head>
<body>
<script id="script">
callsite();
</script>')
	defer { document.finalize() }
	element := document.get_element_by_id('script') or { panic('script') }
	model := html_script_element_model_for_dom_element(unsafe { &dom.HTMLScriptElement(element) })
	assert model.source_line_number() == 4
}
