module layout

import css
import dom
import platform

fn test_text_items_keep_distinct_sources_after_later_text_contexts_and_collection() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	element.set_attribute_value('style', 'font:16px SerenitySans;white-space:pre')
	style :=
		css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	texts := ['alpha', 'אבג', 'Ω', '😀', 'final']
	mut sources := []&TextNode{}
	for text in texts {
		dom_text := document.create_text_node(text)
		node := TextNode.new(document, dom_text.as_node(), text)
		sources << node
		container.append_child(unsafe { &Node(node) })
	}
	assign_layout_indexes(unsafe { &Node(container) })
	mut state := LayoutState.new()
	mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
	used.set_content_width(CSSPixels.new(500))
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(500)),
		AvailableSize.make_indefinite())
	mut iterator := InlineLevelIterator.new(mut state, container, used, .normal, space, none)
	items := iterator.items()
	assert items.len >= texts.len
	mut expected := []string{}
	for item in items {
		if item.type_ != .text { continue
		 }
		source := item.node or { panic('missing source') }
		text := source.as_text_node() or { panic('missing text source') }
		assert texts.contains(text.text_for_rendering())
		run := item.glyph_run or { panic('missing glyphs') }
		expected << '${text.text_for_rendering()} ${item.offset_in_node} ${item.length_in_node} ${run.width()} ${run.glyphs()}'
	}
	for _ in 0 .. 64 {
		mut later :=
			InlineLevelIterator.new(mut state, container, used, .intrinsic_sizing, space, none)
		assert later.items().len == items.len
	}
	gc_collect()
	mut actual := []string{}
	for item in items {
		if item.type_ != .text { continue
		 }
		source := item.node or { panic('missing source') }
		text := source.as_text_node() or { panic('missing text source') }
		run := item.glyph_run or { panic('missing glyphs') }
		assert run.bounding_box() == platform.glyph_run_bounding_box(run.font(), run.glyphs(),
			run.face())
		actual << '${text.text_for_rendering()} ${item.offset_in_node} ${item.length_in_node} ${run.width()} ${run.glyphs()}'
	}
	assert actual == expected
	assert sources.len == texts.len
}
