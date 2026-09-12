module css

import dom

fn parsed_scroll_function(text string) FunctionStyleValue {
	parsed := parse_css_value_logic(.animation_timeline, text) or {
		panic('${text} did not parse')
	}
	list := parsed as StyleValueList
	return list.value_at(0, false) as FunctionStyleValue
}

fn test_scroll_function_uses_a_sparse_generic_tuple() {
	defaults := parsed_scroll_function('scroll(nearest block)')
	assert defaults.name() == 'scroll'
	assert defaults.serialize(.normal) == 'scroll()'
	default_arguments := defaults.value() as TupleStyleValue
	assert default_arguments.tuple().len == 2
	assert default_arguments.tuple()[tuple_scroll_function_scroller_index] == none
	assert default_arguments.tuple()[tuple_scroll_function_axis_index] == none

	canonical := parsed_scroll_function('scroll(x root)')
	assert canonical.serialize(.normal) == 'scroll(root x)'
	arguments := (canonical.value() as TupleStyleValue).tuple()
	scroller := arguments[tuple_scroll_function_scroller_index] or { panic('missing scroller') }
	axis := arguments[tuple_scroll_function_axis_index] or { panic('missing axis') }
	assert scroller.to_keyword() == .root
	assert axis.to_keyword() == .x
}

fn test_scroll_timeline_reads_generic_function_arguments() {
	document := dom.Document.create(dom.url_about_blank())
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	abstract_element := dom.AbstractElement.new(element, none)
	function := parsed_scroll_function('scroll(self inline)')
	timeline := computed_interpolation_animation_timeline_from_style_value(dom_style_value_from_value_logic(StyleValue(function)), &abstract_element) or { panic('scroll timeline was not created') }
	assert timeline.kind == .scroll
	assert timeline.scroll_scroller == .self_
	assert timeline.scroll_axis == .inline_

	from_text := computed_interpolation_animation_timeline_from_style_value(&dom.StyleValue{
		css_text: 'scroll(root y)'
	}, &abstract_element) or { panic('untyped scroll timeline was not created') }
	assert from_text.scroll_scroller == .root
	assert from_text.scroll_axis == .y
}
