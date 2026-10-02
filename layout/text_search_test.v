module layout

import dom
import html

fn search_fixture(source string) &dom.Document {
	document := html.parse_document('<!doctype html>${source}')
	_ = run_document_layout(document, 500, 200) or { panic('missing layout') }
	return document
}

fn test_search_uses_rendered_text_and_returns_live_dom_boundaries_across_inline_nodes() {
	document := search_fixture('<p id="p">  he<span>llo  </span><em id="em">  world</em>  </p><script>hello world</script><style>.unused{content:"hello world"}</style>')
	matches := document.find_matching_text('HELLO world', .case_insensitive)
	assert matches.len == 1
	p := document.get_element_by_id('p') or { panic('missing p') }
	first := p.as_node().first_child() or { panic('missing first text') }
	em := document.get_element_by_id('em') or { panic('missing em') }
	last := em.as_node().first_child() or { panic('missing last text') }
	assert matches[0].start_container() == first
	assert matches[0].start_offset() == 2
	assert matches[0].end_container() == last
	assert matches[0].end_offset() == 7
	assert document.find_matching_text('HELLO world', .case_sensitive).len == 0
}

fn test_search_excludes_hidden_inert_and_generated_text_and_keeps_box_boundaries() {
	document := search_fixture('<style>#generated::before{content:"ghost"}</style><div style="display:none">ghost</div><p style="visibility:hidden">ghost</p><p style="opacity:0">ghost</p><p inert>ghost</p><p id="generated">visible</p><p>one</p><p>two</p>')
	assert document.find_matching_text('ghost', .case_insensitive).len == 0
	assert document.find_matching_text('one two', .case_insensitive).len == 0
	assert document.find_matching_text('visible', .case_sensitive).len == 1
}

fn test_search_maps_transformed_first_letter_and_supplementary_text_to_source_code_units() {
	document := search_fixture('<style>#p{text-transform:uppercase}#p::first-letter{color:red}</style><p id="p">ßa😀</p>')
	matches := document.find_matching_text('SSA😀', .case_sensitive)
	assert matches.len == 1
	assert matches[0].start_offset() == 0
	assert matches[0].end_offset() == 4
	assert matches[0].start_container() == matches[0].end_container()
	assert document.find_matching_text('ß', .case_insensitive).len == 0
}

fn test_search_rechecks_live_layout_and_preserves_source_post_match_advance() {
	mut document := search_fixture('<p id="p">foofoo foo</p>')
	assert document.find_matching_text('foo', .case_sensitive).len == 2
	p := document.get_element_by_id('p') or { panic('missing p') }
	mut text := p.as_node().first_child() or { panic('missing text') }
	text.set_text_content('changed')!
	assert document.find_matching_text('foo', .case_sensitive).len == 0
	assert document.find_matching_text('changed', .case_sensitive).len == 1
	assert document.find_matching_text('', .case_sensitive).len == 0
}
