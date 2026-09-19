module html

import editing
import dom

fn replacement_fragment_range(document &dom.Document) &dom.Range {
	host := document.get_element_by_id('host') or { panic('missing host') }
	mut range := document.create_range()
	range.select_node_contents(host.as_node()) or { panic(err) }
	return range
}

fn test_replacement_fragment_consumes_interchange_transport_markup() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable></div></body>')
	replacement := editing.ReplacementFragment.new(replacement_fragment_range(document),
		'<span>&nbsp;</span>word<span>&nbsp;</span><i></i><br class="Apple-interchange-newline">') or {
		panic(err)
	}

	assert replacement.has_interchange_newline_at_end()
	assert !replacement.has_interchange_newline_at_start()
	assert replacement.contains_only_text()
	assert !replacement.contains_block_content()
	assert replacement.fragment().as_node().serialize_fragment(.no, .inner) or { '' } == '&nbsp;word&nbsp;'
}

fn test_replacement_fragment_records_leading_marker_and_block_content() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable></div></body>')
	replacement := editing.ReplacementFragment.new(replacement_fragment_range(document),
		' \n <b><br class="Apple-interchange-newline"></b><div>block</div> \n ') or {
		panic(err)
	}

	assert replacement.has_interchange_newline_at_start()
	assert !replacement.has_interchange_newline_at_end()
	assert !replacement.contains_only_text()
	assert replacement.contains_block_content()
	assert replacement.children().len == 2
}

fn test_replacement_fragment_protects_external_edge_whitespace() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable></div></body>')
	replacement := editing.ReplacementFragment.new(replacement_fragment_range(document),
		'<em> leading and trailing </em>') or { panic(err) }

	assert replacement.fragment().as_node().serialize_fragment(.no, .inner) or { '' } == '<em>&nbsp;leading and trailing&nbsp;</em>'
}
