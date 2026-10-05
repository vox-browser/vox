module dom

fn test_removed_body_only_blocks_rendering_while_the_parser_is_active() {
	mut document := Document.create(URL{value: 'https://example.test/'})
	document.set_content_type('text/html')
	document.set_parser(&HTMLParser{})
	document.update_readiness(.loading)
	document.populate_with_html_head_and_body()!
	assert !document.is_render_blocked()

	body := document.body() or { panic('missing body') }
	mut body_node := unsafe { &Element(body) }.as_node()
	body_node.remove(false)
	assert document.body() == none
	assert document.is_render_blocked()

	document.update_readiness(.interactive)
	assert !document.is_render_blocked()

	mut explicit_blocker := document.create_element('style')!
	document.add_render_blocking_element(explicit_blocker)
	assert document.is_render_blocked()
	document.remove_render_blocking_element(explicit_blocker)
	assert !document.is_render_blocked()
}
