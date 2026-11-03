module layout

import css
import dom
import html
import math

fn scroll_source_fixture(styles string, markup string) !(&dom.Document, &html.WindowModel, &css.CSSAnimation) {
	document := html.parse_document('<!doctype html><style>html,body{margin:0} @keyframes progress {from{opacity:0}to{opacity:1}} #target{animation:progress 1s linear both} ' + styles + '</style>' + markup)
	window := html.WindowModel.create_top_level(document, none, 'scroll-source')!
	_ = layout_document_typed_in_viewport(document, 200, 100)
	target := document.get_element_by_id('target') or { return error('target') }
	computer := css.css_style_computer_for(document)
	animation := computer.css_animation_for(dom.AbstractElement.new(target, none), 'progress') or { return error('animation') }
	return document, window, animation
}

fn test_scroll_source_root_inline_uses_attachment_lengths_and_reverses() {
	document, mut window, mut animation := scroll_source_fixture('body{width:600px;height:50px} #target{animation-timeline:scroll(root inline);animation-range:0px 50vw}', '<div id="target"></div>')!
	defer { document.finalize() }
	for offset, expected in {0: 0.0, 50: 0.5, 100: 1.0, 25: 0.25, 400: 1.0} {
		_ = window.scroll_xy(offset, 0)
		progress := animation.sample_at(50000) or { panic('inactive real root scroll clock') }
		assert math.abs(progress - expected) < 0.0001
	}
}

fn test_scroll_source_root_calculated_percentage_attachment_range() {
	document, mut window, mut animation := scroll_source_fixture('body{width:600px;height:50px} #target{animation-timeline:scroll(root x);animation-range:calc(25% + 10px) calc(75% - 10px)}', '<div id="target"></div>')!
	defer { document.finalize() }
	_ = window.scroll_xy(200, 0)
	assert math.abs((animation.sample_at(9999) or { -1 }) - 0.5) < 0.0001
	_ = window.scroll_xy(110, 0)
	assert math.abs(animation.sample_at(1) or { -1 }) < 0.0001
	_ = window.scroll_xy(290, 0)
	assert math.abs((animation.sample_at(1) or { -1 }) - 1) < 0.0001
}

fn test_scroll_source_auto_duration_keeps_its_compositor_property_identity() {
	document, mut window, mut animation := scroll_source_fixture('body{width:600px;height:50px} #target{animation-duration:auto;animation-timeline:scroll(root inline);animation-range:0px 100px}', '<div id="target"></div>')!
	defer { document.finalize() }
	assert animation.effect_.specified_iteration_duration == 0
	_ = window.scroll_xy(50, 0)
	assert math.abs((animation.sample_at(100000) or { -1 }) - 0.5) < 0.0001
	target := document.get_element_by_id('target') or { panic('target') }
	assert css.compositor_animation_properties(dom.AbstractElement.new(target, none)).opacity
}

fn test_scroll_source_nearest_and_self_use_the_element_scroll_box() {
	for self in [false, true] {
		id := if self { 'scroller' } else { 'target' }
		source := if self { 'self' } else { 'nearest' }
		styles := '#scroller{width:100px;height:50px;overflow:hidden} #content{height:250px} #' + id + '{animation:progress 1s linear both;animation-timeline:scroll(' + source + ' y);animation-range:10px 110px}'
		document := html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes progress{from{opacity:0}to{opacity:1}}' + styles + '</style><div id="scroller"><section><div id="target"></div><div id="content"></div></section></div>')
		defer { document.finalize() }
		_ = html.WindowModel.create_top_level(document, none, 'element-scroll-source')!
		_ = layout_document_typed_in_viewport(document, 200, 100)
		mut scroller := document.get_element_by_id('scroller') or { panic('scroller') }
		target := document.get_element_by_id(id) or { panic('target') }
		computer := css.css_style_computer_for(document)
		mut animation := computer.css_animation_for(dom.AbstractElement.new(target, none), 'progress') or { panic('animation') }
		scroller.set_scroll_top(60)
		assert scroller.scroll_top() == 60
		assert math.abs((animation.sample_at(50000) or { -1 }) - 0.5) < 0.0001
	}
}

fn test_scroll_source_rtl_inline_progress_and_removed_target_inactivity() {
	document, _, mut animation := scroll_source_fixture('#target{width:100px;height:50px;overflow:hidden;direction:rtl;animation-timeline:scroll(self inline);animation-range:0px 100px} #content{width:300px;height:20px}', '<div id="target"><div id="content"></div></div>')!
	defer { document.finalize() }
	mut target := document.get_element_by_id('target') or { panic('target') }
	target.set_scroll_left(-50)
	assert target.scroll_left() == -50
	assert math.abs((animation.sample_at(1000) or { -1 }) - 0.5) < 0.0001
	target.as_node().remove(false)
	assert animation.sample_at(2000) == none
	assert animation.effect_.output_progress == none
}

fn test_scroll_source_zero_overflow_does_not_publish_forwards_fill() {
	document, _, mut animation := scroll_source_fixture('body{width:200px;height:50px} #target{animation-timeline:scroll(root x);animation-range:0px 100px}', '<div id="target"></div>')!
	defer { document.finalize() }
	assert animation.sample_at(100000) == none
	assert animation.effect_.output_progress == none
}
