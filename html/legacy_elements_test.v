module html

import dom

fn legacy_test_find_element(node &dom.Node, local_name string) ?&dom.Element {
	if element := node.as_element() {
		if element.local_name() == local_name {
			return element
		}
	}
	for child in node.children_as_vector() {
		if element := legacy_test_find_element(child, local_name) {
			return element
		}
	}
	return none
}

fn test_legacy_font_dimension_and_presentation_hint_parsing() {
	assert parse_legacy_font_size('  +2 trailing')? == 'x-large'
	assert parse_legacy_font_size('-9')? == 'x-small'
	assert parse_legacy_font_size('9')? == 'xxx-large'
	assert parse_legacy_font_size('+') == none
	assert parse_legacy_dimension_value('  12.5%junk')? == LegacyDimension{
		value:      12.5
		percentage: true
	}
	font := legacy_element_presentational_hints('font', {
		'color': 'red'
		'face':  'serif'
		'size':  '+1'
	})
	assert font.color?.r == 255
	assert font.font_family? == 'serif'
	assert font.font_size? == 'large'

	hr := legacy_element_presentational_hints('hr', {
		'color': '#123456'
		'size':  '8'
		'width': '75%'
	})
	assert hr.border_style? == 'solid'
	assert hr.border_top_width? == 4
	assert hr.width?.percentage
	assert hr.width?.value == 75

	marquee := legacy_element_presentational_hints('marquee', {
		'bgcolor': 'blue'
		'hspace':  '4'
		'height':  '10.5px'
	})
	assert marquee.background_color?.b == 255
	assert marquee.margin_left?.value == 4
	assert marquee.margin_right?.value == 4
	assert marquee.height?.value == 10.5
}

fn test_legacy_list_alignment_clear_and_caption_hints() {
	assert legacy_element_presentational_hints('ol', {
		'type': 'I'
	}).list_style_type? == 'upper-roman'
	assert legacy_element_presentational_hints('ul', {
		'type': 'CIRCLE'
	}).list_style_type? == 'circle'
	assert legacy_element_presentational_hints('li', {
		'type': 'none'
	}).list_style_type? == 'none'
	assert legacy_element_presentational_hints('p', {
		'align': 'CENTER'
	}).text_align? == 'center'
	assert legacy_element_presentational_hints('div', {
		'align': 'right'
	}).text_align? == 'libweb-right'
	assert legacy_element_presentational_hints('br', {
		'clear': 'all'
	}).clear? == 'both'
	assert legacy_element_presentational_hints('caption', {
		'align': 'bottom'
	}).caption_side? == 'bottom'
	assert is_legacy_presentational_hint('font', 'size')
	assert !is_legacy_presentational_hint('font', 'href')
}

fn test_marquee_table_col_legend_and_display_algorithms() {
	document :=
		parse_document('<form><fieldset><legend>x</legend></fieldset></form><marquee></marquee><table><colgroup><col></colgroup></table>')
	root := unsafe { &dom.Node(document) }
	marquee_element := legacy_test_find_element(root, 'marquee')?
	marquee := unsafe { &dom.HTMLMarqueeElement(marquee_element) }
	assert html_marquee_element_scroll_amount(marquee) == 6
	assert html_marquee_element_scroll_delay(marquee) == 85
	set_html_marquee_element_scroll_amount(marquee, 12)
	set_html_marquee_element_scroll_delay(marquee, 40)
	assert html_marquee_element_scroll_amount(marquee) == 12
	assert html_marquee_element_scroll_delay(marquee) == 40

	col_element := legacy_test_find_element(root, 'col')?
	col := unsafe { &dom.HTMLTableColElement(col_element) }
	set_html_table_col_element_span(col, 2000)
	assert html_table_col_element_span(col) == 1000
	legend_element := legacy_test_find_element(root, 'legend')?
	legend := unsafe { &dom.HTMLLegendElement(legend_element) }
	assert html_legend_element_form(legend) != none
	assert legacy_element_adjusted_display('br', 'contents') == 'none'
	assert legacy_element_adjusted_display('div', 'contents') == 'contents'
	assert html_html_element_should_use_body_background(false, false, false, dom.color_transparent)
}

fn test_frame_element_lifecycle_and_about_blank_load() {
	mut frame := HTMLFrameElementModel.create(dom.URL{ value: 'https://example.test/base/' }, dom.Origin{
		value: 'https://example.test'
	})
	assert frame.default_tab_index_value() == 0
	frame.inserted(true, true, [])!
	assert frame.event_count('load') == 1
	assert frame.container.content_navigable()?.has_session_history_entry_and_ready
	frame.set_src('next.html', [])!
	assert frame.container.content_navigable()?.active_document.url.serialize() == 'https://example.test/base/next.html'
	frame.removed_from_document()
	assert frame.container.content_navigable() == none
}
