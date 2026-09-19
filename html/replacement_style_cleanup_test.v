module html

import editing
import css
import dom

fn replacement_style_content(document_html string, author_style string) (&editing.InsertedContent, &dom.Element, &dom.Element) {
	document := parse_document(document_html)
	css.add_document_author_style_sheet(document, author_style)
	host := document.get_element_by_id('host') or { panic('missing host') }
	inserted := document.get_element_by_id('inserted') or { panic('missing inserted content') }
	mut content := editing.InsertedContent.new([inserted.as_node()])
	return content, host, inserted
}

fn test_replacement_style_cleanup_unwraps_redundant_style_only_span() {
	mut content, host, inserted := replacement_style_content('<!doctype html><body><div id="host" contenteditable><span id="inserted" style="color: red">text</span></div></body>',
		'#host span { color: red; }')
	inserted.remove_attribute('id')
	text := inserted.as_node().first_child() or { panic('missing text') }

	editing.remove_redundant_styles_from_inserted_content(mut content)

	assert host.inner_html()! == 'text'
	assert inserted.as_node().parent() == none
	assert content.first_node()? == text
}

fn test_replacement_style_cleanup_retains_only_effective_inline_difference() {
	mut content, _, inserted := replacement_style_content('<!doctype html><body><div id="host" contenteditable><span id="inserted" style="color: blue; font-weight: 700">text</span></div></body>',
		'#host span { color: red; font-weight: 700; }')

	editing.remove_redundant_styles_from_inserted_content(mut content)

	style := inserted.get_attribute('style') or { panic('style was removed') }
	assert style.contains('color')
	assert !style.contains('font-weight')
	assert inserted.as_node().parent() != none
}

fn test_replacement_style_cleanup_keeps_non_span_container_after_style_removal() {
	mut content, host, inserted := replacement_style_content('<!doctype html><body><div id="host" contenteditable><b id="inserted" style="color: red">text</b></div></body>',
		'#host b { color: red; }')

	editing.remove_redundant_styles_from_inserted_content(mut content)

	assert inserted.get_attribute('style') == none
	assert host.inner_html()! == '<b id="inserted">text</b>'
}

fn test_replacement_style_cleanup_preserves_custom_properties() {
	mut content, _, inserted := replacement_style_content('<!doctype html><body><div id="host" contenteditable><span id="inserted" style="--accent: green; color: red">text</span></div></body>',
		'#host span { color: red; }')

	editing.remove_redundant_styles_from_inserted_content(mut content)

	style := inserted.get_attribute('style') or { panic('custom style was removed') }
	assert style.contains('--accent: green')
	assert !style.contains('color')
}
