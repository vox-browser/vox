module html

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

fn normalization_test_attribute(name string, value string, index int) Attribute {
	return Attribute{
		local_name: name
		value: value
		prefix: 'fixture-prefix'
		namespace_: 'urn:normalization-fixture'
		name_start_position: Position{ line: index, column: index + 1 }
		name_end_position: Position{ line: index, column: index + 3 }
		value_start_position: Position{ line: index, column: index + 4 }
		value_end_position: Position{ line: index, column: index + 9 }
	}
}

fn test_normalization_empty_and_single_attribute_preserve_sticky_flag_without_allocation() {
	mut empty := HTMLToken.make_start_tag('div')
	empty.had_duplicate_attribute = true
	mut single := HTMLToken.make_start_tag('span')
	attribute := normalization_test_attribute('id', 'first', 2)
	single.add_attribute(attribute)
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	for _ in 0 .. 1024 {
		empty.normalize_attributes()
		single.normalize_attributes()
	}
	mut allocated := uint(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert allocated == 0
	assert empty.attributes.len == 0
	assert empty.had_duplicate_attribute
	assert single.attributes.len == 1
	assert single.attributes[0] == attribute
	assert !single.had_duplicate_attribute
	gc_collect()
	assert single.attributes[0].value == 'first'
}

fn test_normalization_sixteen_unique_attributes_keep_complete_values_without_allocation() {
	mut token := HTMLToken.make_start_tag('div')
	for index in 0 .. 16 {
		token.add_attribute(normalization_test_attribute('key-${index}', 'value-${index}', index))
	}
	original := token.attributes.clone()
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	for _ in 0 .. 128 { token.normalize_attributes() }
	mut allocated := uint(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert allocated == 0
	assert token.attributes == original
	assert !token.had_duplicate_attribute
	gc_collect()
	assert token.attributes[15] == original[15]
}

fn test_normalization_small_duplicates_keep_first_order_spans_and_original_array() {
	mut token := HTMLToken.make_start_tag('div')
	first := normalization_test_attribute('a', 'first', 1)
	second := normalization_test_attribute('b', 'second', 2)
	third := normalization_test_attribute('c', 'third', 3)
	token.attributes = [first, normalization_test_attribute('a', 'later-a', 4), second,
		normalization_test_attribute('b', 'later-b', 5), third,
		normalization_test_attribute('a', 'last-a', 6)]
	original := token.attributes
	token.normalize_attributes()
	assert token.had_duplicate_attribute
	assert token.attributes == [first, second, third]
	assert original.len == 6
	assert original[1].value == 'later-a'
	assert original[2] == second
	assert original[5].value == 'last-a'
	token.normalize_attributes()
	gc_collect()
	assert token.had_duplicate_attribute
	assert token.attributes == [first, second, third]
	assert original[4] == third
}

fn test_normalization_uses_exact_local_names_before_namespace_adjustment_and_large_hash_fallback() {
	mut token := HTMLToken.make_start_tag('svg')
	first := normalization_test_attribute('A', 'uppercase', 0)
	mut same_local_other_namespace := normalization_test_attribute('A', 'other-namespace', 1)
	same_local_other_namespace.namespace_ = 'urn:other'
	token.attributes = [first, normalization_test_attribute('a', 'lowercase', 2), same_local_other_namespace]
	token.normalize_attributes()
	assert token.had_duplicate_attribute
	assert token.attributes.len == 2
	assert token.attributes[0] == first
	assert token.attributes[1].local_name == 'a'
	mut large := HTMLToken.make_start_tag('div')
	for index in 0 .. 17 {
		large.add_attribute(normalization_test_attribute('key-${index}', 'value-${index}', index))
	}
	original := large.attributes.clone()
	large.normalize_attributes()
	assert large.attributes == original
	assert !large.had_duplicate_attribute
	large.add_attribute(normalization_test_attribute('key-0', 'replace-first', 18))
	large.add_attribute(normalization_test_attribute('key-16', 'replace-last', 19))
	large.normalize_attributes()
	gc_collect()
	assert large.had_duplicate_attribute
	assert large.attributes == original
}

fn test_tokenizer_normalization_keeps_first_ascii_case_duplicate_and_source_positions() {
	mut tokenizer := HTMLTokenizer.new('<p A="first" a="later" B="last">')
	token := tokenizer.next_token() or { panic('missing start tag') }
	assert token.type_ == .start_tag
	assert token.had_duplicate_attribute
	assert token.attributes.len == 2
	first := token.attributes[0]
	assert first.local_name == 'a'
	assert first.value == 'first'
	assert first.name_start_position == Position{ line: 0, column: 3 }
	assert first.name_end_position == Position{ line: 0, column: 4 }
	assert first.value_start_position == Position{ line: 0, column: 5 }
	assert first.value_end_position == Position{ line: 0, column: 12 }
	assert token.attributes[1].local_name == 'b'
	assert token.attributes[1].value == 'last'
	gc_collect()
	assert token.attributes[0] == first
}

fn test_html_tree_builder_receives_first_attributes_duplicate_flag_and_svg_name_adjustment() {
	document := parse_document('<!doctype html><div ID="target" id="discarded" data-x="first" DATA-X="later">text&amp;ok</div><svg id="graphic" viewBox="0 0 10 20" viewbox="0 0 99 99"></svg>')
	element := document.get_element_by_id('target') or { panic('first id was lost') }
	assert document.get_element_by_id('discarded') == none
	assert element.get_attribute_value('data-x') == 'first'
	assert element.attribute_list_size() == 2
	assert element.had_duplicate_attribute_during_tokenization
	assert element.as_node().text_content() or { '' } == 'text&ok'
	graphic := document.get_element_by_id('graphic') or { panic('missing SVG') }
	assert graphic.get_attribute_value('viewBox') == '0 0 10 20'
	assert graphic.get_attribute_value('viewbox') == ''
	assert graphic.had_duplicate_attribute_during_tokenization
	gc_collect()
	assert element.get_attribute_value('data-x') == 'first'
	assert graphic.get_attribute_value('viewBox') == '0 0 10 20'
}

fn test_unique_token_and_dom_attributes_survive_later_tokens_and_collection() {
	input := '<a></a><b id="single"></b><c id="multiple" a1="v1" a2="v2" a3="v3" a4="v4" a5="v5" a6="v6" a7="v7"></c>' +
		'<i></i><i q="later"></i><i q0="x0" q1="x1" q2="x2" q3="x3" q4="x4" q5="x5" q6="x6" q7="x7"></i>'.repeat(256)
	mut tokenizer := HTMLTokenizer.new(input)
	mut retained := []HTMLToken{}
	mut later_tokens := 0
	for {
		token := tokenizer.next_token() or { break }
		if token.is_start_tag() && token.tag_name in ['a', 'b', 'c'] {
			retained << token
		} else {
			later_tokens++
		}
	}
	gc_collect()
	assert retained.len == 3
	assert later_tokens > 1000
	assert retained[0].attributes.len == 0
	assert retained[1].attributes.len == 1
	assert retained[1].attributes[0].value == 'single'
	assert retained[2].attributes.len == 8
	assert retained[2].attributes[7].local_name == 'a7'
	assert retained[2].attributes[7].value == 'v7'
	assert !retained[0].had_duplicate_attribute
	assert !retained[1].had_duplicate_attribute
	assert !retained[2].had_duplicate_attribute
	document := parse_document(input)
	gc_collect()
	single := document.get_element_by_id('single') or { panic('single attribute lost') }
	multiple := document.get_element_by_id('multiple') or { panic('eight attributes lost') }
	assert single.attribute_list_size() == 1
	assert multiple.attribute_list_size() == 8
	assert multiple.get_attribute_value('a7') == 'v7'
	assert !single.had_duplicate_attribute_during_tokenization
	assert !multiple.had_duplicate_attribute_during_tokenization
}
