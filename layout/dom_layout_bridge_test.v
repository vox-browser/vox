module layout

import css
import dom
import html

// After layout, attach_layout_nodes wires the real layout tree back onto the DOM: node.layout_node()
// returns real data (its DOM node, parent layout node, and computed display) instead of the old stubs.
fn test_dom_layout_bridge() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut div := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(div.as_node()) or { panic('${err}') }

	result := run_document_layout(doc, 800.0, 600.0) or { panic('no layout result') }
	attach_layout_nodes(result.root)

	// <html> now has a layout node pointing back at its DOM node, with a real (non-none, non-anonymous) display.
	html_layout := html_el.as_node().layout_node() or { panic('html has no layout node') }
	html_layout_dom := html_layout.dom_node() or { panic('html layout node has no dom node') }
	assert voidptr(html_layout_dom) == voidptr(html_el.as_node())
	assert !html_layout.is_anonymous()
	assert !html_layout.is_text_node()
	assert !html_layout.display().is_none()
	// html's layout parent is the Viewport (the layout root), whose DOM node is the Document.
	html_layout_parent := html_layout.parent() or {
		panic('html layout node should have the viewport as parent')
	}
	viewport_dom := html_layout_parent.dom_node() or {
		panic('viewport layout node has no dom node')
	}
	assert viewport_dom.is_document()
	// CSS Overflow 3 propagates the root element's visible overflow to auto on
	// the layout viewport. Internals reads this same committed layout value.
	assert html_layout_parent.overflow_x() == .auto_

	// The div's layout node parent is the html layout node.
	div_layout := div.as_node().layout_node() or { panic('div has no layout node') }
	div_layout_parent := div_layout.parent() or { panic('div layout node has no parent') }
	assert voidptr(div_layout_parent) == voidptr(html_layout)
	div_layout_dom := div_layout.dom_node() or { panic('div layout node has no dom node') }
	assert voidptr(div_layout_dom) == voidptr(div.as_node())

	// Element/AbstractElement's styled-layout view is backed by the same attached tree rather than
	// the former always-null placeholder.
	html_with_style := html_el.el_layout_node() or { panic('html has no styled layout view') }
	div_with_style := div.el_layout_node() or { panic('div has no styled layout view') }
	assert voidptr(html_with_style.dom_node() or { panic('missing html DOM node') }) == voidptr(html_el.as_node())
	assert html_with_style.is_before(div_with_style)
	assert !div.not_rendered()
}

fn test_dom_layout_bridge_retains_visual_lines_for_caret_navigation() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		p { margin: 0; width: 48px; font: 16px/20px SerenityMono; white-space: pre-wrap }
	</style><body><p id="wrapped">four four</p><p id="preserved">a\n\nb</p></body>')
	_ := run_document_layout(document, 160, 120) or { panic('layout failed') }

	wrapped_element := document.get_element_by_id('wrapped') or { panic('missing wrapped text') }
	wrapped_node := wrapped_element.as_node().first_child() or { panic('missing wrapped node') }
	assert wrapped_node.is_text()
	wrapped_text := unsafe { &dom.Text(wrapped_node) }
	wrapped_lines := dom.collect_visual_lines(wrapped_text)
	assert wrapped_lines.len == 2
	assert wrapped_lines[0].start_offset == 0
	assert wrapped_lines[0].end_offset == 4
	assert wrapped_lines[0].end_offset_with_trailing_whitespace == 5
	assert wrapped_lines[1].start_offset == 5
	assert wrapped_lines[1].end_offset == 9
	assert wrapped_lines[0].caret_stops.len >= 5
	assert wrapped_lines[1].caret_stops.len >= 5
	assert wrapped_lines[0].owner_paintable == wrapped_lines[1].owner_paintable

	first_line_position := dom.compute_cursor_position_on_previous_line(wrapped_text, 7,
		.downstream) or { panic('missing previous visual line') }
	assert first_line_position.offset < 5
	next_character := dom.compute_cursor_position_on_next_character(wrapped_text, 5,
		.upstream) or { panic('missing soft-wrap character step') }
	assert next_character == dom.CursorLinePosition{offset: 5, affinity: .downstream}

	preserved_element := document.get_element_by_id('preserved') or {
		panic('missing preserved text')
	}
	preserved_node := preserved_element.as_node().first_child() or {
		panic('missing preserved node')
	}
	assert preserved_node.is_text()
	preserved_text := unsafe { &dom.Text(preserved_node) }
	preserved_lines := dom.collect_visual_lines(preserved_text)
	assert preserved_lines.len == 3
	assert preserved_lines[0].start_offset == 0
	assert preserved_lines[0].end_offset == 1
	assert !preserved_lines[1].has_fragments
	assert preserved_lines[1].start_offset == 2
	assert preserved_lines[1].end_offset == 2
	assert preserved_lines[2].start_offset == 3
	assert preserved_lines[2].end_offset == 4
}

fn test_document_update_layout_runs_registered_layout_engine() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	child.set_attribute_value('style', 'position: relative; z-index: 1; left: 20px; top: 10px; width: 100px; height: 40px; padding: 10px; border: 2px solid')
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(child.as_node()) or { panic('${err}') }
	mut child_node := child.as_node()
	text := doc.create_text_node('  a   b  ')
	child_node.append_child(text.as_node()) or { panic('${err}') }

	install_document_layout_hook(doc)
	navigable := &dom.Navigable{
		active_document_: doc
	}
	doc.set_cached_navigable(navigable)
	doc.needs_full_layout_tree_update = true
	doc.update_layout(.debugging)
	assert doc.layout_engine_handle() != unsafe { nil }
	assert html_el.el_layout_node() != none
	assert child.el_layout_node() != none
	assert doc.layout_is_up_to_date()
	assert child.client_left() == 2
	assert child.client_top() == 2
	assert child.client_width() == 120
	assert child.client_height() == 60
	child_layout := child.as_node().layout_node() or { panic('missing child layout node') }
	assert child_layout.paintables().len == 1
	child_paintable := child.as_node().paintable_box() or { panic('missing child paintable box') }
	element_paintable := child.paintable_box() or { panic('element lost its paintable box') }
	assert voidptr(element_paintable) == voidptr(child_paintable)
	assert child_paintable.is_visible()
	assert child_paintable.has_stacking_context()
	assert child_paintable.scrollable_overflow_rect() != none
	rect := child.get_bounding_client_rect()
	assert rect.x == 20
	assert rect.y == 10
	assert rect.width == 124
	assert rect.height == 64
	html_child := unsafe { &dom.HTMLElement(child) }
	assert html.html_element_offset_width(html_child) == 124
	assert html.html_element_offset_height(html_child) == 64
	assert html.html_element_offset_left(html_child) == 20
	assert html.html_element_offset_top(html_child) == 10
	assert html.html_element_offset_parent(html_child) == none
	assert voidptr(html.html_element_scroll_parent(html_child) or {
		panic('missing scroll parent')}) == voidptr(html_el)
	// HTMLElement.cpp feeds TextNode::ChunkIterator(false, false) into the rendered-text
	// collection steps. It collapses each run but retains one leading/trailing collapsible space.
	assert html.html_element_inner_text(html_child) == ' a b '
	assert text.as_node().accessible_name(doc, .no)! == '  a   b  '
	mut mutable_child_node := child.as_node()
	mutable_child_node.set_needs_repaint(.paint_commands_and_hit_test_list)
	assert child_layout.paintables()[0].needs_repaint

	// A clean document returns at the same point as Document::update_layout()
	// upstream and retains the committed layout tree/state.
	first_layout_handle := doc.layout_engine_handle()
	doc.update_layout(.debugging)
	assert doc.layout_engine_handle() == first_layout_handle

	// Layout invalidation propagates through the mirrored layout-node tree and
	// causes the next update to rebuild and commit a fresh state.
	child_node.set_needs_layout_update(.style_change)
	assert !doc.layout_is_up_to_date()
	doc.update_layout(.debugging)
	assert doc.layout_is_up_to_date()
	assert doc.layout_engine_handle() != first_layout_handle

	// A style change which only requires relayout updates the retained typed
	// Layout::Node style and reuses the layout tree, as Element::recompute_style
	// and Document::update_layout do upstream.
	before_style_change := document_layout_result(doc) or { panic('missing layout result') }
	retained_root := before_style_change.root
	child.set_attribute_value('style', 'position: relative; left: 20px; top: 10px; width: 150px; height: 40px; padding: 10px; border: 2px solid')
	doc.update_layout(.debugging)
	updated_computed := css.computed_properties_for_element(child) or { panic('missing updated style') }
	assert updated_computed.length_percentage_to_px(.width, 800) or { -1 } == 150
	after_style_change := document_layout_result(doc) or { panic('missing updated layout result') }
	assert after_style_change.root == retained_root
	assert child.client_width() == 170
}

fn test_document_layout_stabilizes_container_relative_lengths_after_geometry_commit() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	doc.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	mut html_element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut container := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	container.set_attribute_value('style', 'container-type: size; width: 400px; height: 100px')
	child.set_attribute_value('style', 'width: 25cqw; height: 10px')
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(html_element.as_node())!
	mut html_node := html_element.as_node()
	html_node.append_child(container.as_node())!
	mut container_node := container.as_node()
	container_node.append_child(child.as_node())!

	install_document_layout_hook(doc)
	doc.set_cached_navigable(&dom.Navigable{
		active_document_: doc
	})
	doc.needs_full_layout_tree_update = true
	doc.update_style()
	provisional_container := css.computed_properties_for_element(container) or {
		panic('missing provisional container style')
	}
	assert provisional_container.container_type().is_size_container
	provisional_child := css.computed_properties_for_element(child) or {
		panic('missing provisional child style')
	}
	assert (provisional_child.property(.width, .no) or { panic('missing provisional width') }).css_text == '0px'
	assert doc.needs_container_query_evaluation_after_layout(container)
	doc.update_layout(.debugging)

	container_computed := css.computed_properties_for_element(container) or {
		panic('missing container style')
	}
	assert container_computed.container_type().is_size_container
	assert container.client_width() == 400
	child_computed := css.computed_properties_for_element(child) or { panic('missing child style') }
	assert voidptr(child_computed.subject_element_ or { panic('missing subject') }) == voidptr(child)
	assert (child_computed.property(.width, .no) or { panic('missing width') }).css_text == '100px'
	assert child_computed.length_percentage_to_px(.width, 800) or { -1 } == 100
	assert child.client_width() == 100
	assert child.style_depends_on_size_container_query()
	assert container.is_size_query_container()
	assert !doc.needs_container_query_evaluation_after_layout(container)
}

fn test_document_layout_stabilizes_size_container_query_styles_after_geometry_commit() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	doc.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	mut html_element := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut container := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	container.set_attribute_value('style', 'container-type: size; width: 400px; height: 100px')
	child.set_attribute_value('class', 'target')
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(html_element.as_node())!
	mut html_node := html_element.as_node()
	html_node.append_child(container.as_node())!
	mut container_node := container.as_node()
	container_node.append_child(child.as_node())!
	css.add_document_author_style_sheet(doc, '.target { color: blue; width: 20px } @container (width >= 300px) { .target { color: red; width: 50px } }')

	install_document_layout_hook(doc)
	doc.set_cached_navigable(&dom.Navigable{
		active_document_: doc
	})
	doc.needs_full_layout_tree_update = true
	doc.update_style()
	provisional_child := css.computed_properties_for_element(child) or {
		panic('missing provisional child style')
	}
	assert (provisional_child.property(.color, .no) or {
		panic('missing provisional color')
	}).css_text == 'rgb(0, 0, 255)'
	assert child.style_depends_on_size_container_query()
	assert doc.needs_container_query_evaluation_after_layout(container)

	doc.update_layout(.debugging)
	child_computed := css.computed_properties_for_element(child) or {
		panic('missing stabilized child style')
	}
	assert (child_computed.property(.color, .no) or {
		panic('missing stabilized color')
	}).css_text == 'rgb(255, 0, 0)'
	assert child.client_width() == 50
	assert child.style_depends_on_size_container_query()
	assert container.is_size_query_container()
	assert !doc.needs_container_query_evaluation_after_layout(container)
}

fn test_inline_geometry_skips_inline_block_descendant_fragments() {
	document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		i { display: inline-block }
		i::before { content: "X" }
	</style><body><a><i></i></a></body>')
	_ = layout_document_typed_in_viewport(document, 320, 200)
	anchor := document.query_selector('a') or { panic('missing anchor') }
	inline_block := document.query_selector('i') or { panic('missing inline block') }
	anchor_rect := anchor.get_bounding_client_rect()
	inline_block_rect := inline_block.get_bounding_client_rect()
	assert anchor_rect.x == inline_block_rect.x
	assert anchor_rect.width == inline_block_rect.width
}

fn test_computed_cssom_uses_translated_layout_used_values() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	doc.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	child.set_attribute_value('style', 'position: relative; left: 10%; width: 100px; height: 40px; margin-left: 15px; padding: 10px; border: 2px solid red; color: red; line-height: 20px; transform: translate(5px, 6px); animation-duration: auto; animation-timeline: auto')
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(child.as_node()) or { panic('${err}') }

	install_document_layout_hook(doc)
	navigable := &dom.Navigable{
		active_document_: doc
	}
	doc.set_cached_navigable(navigable)
	resolved := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(child, none))
	assert resolved.get_property_value('width') == '100px'
	assert resolved.get_property_value('height') == '40px'
	assert resolved.get_property_value('margin-left') == '15px'
	assert resolved.get_property_value('padding-left') == '10px'
	assert resolved.get_property_value('border-left-width') == '2px'
	assert resolved.get_property_value('line-height') == '20px'
	assert resolved.get_property_value('left') == '80px'
	assert resolved.get_property_value('color') == 'rgb(255, 0, 0)'
	assert resolved.get_property_value('transform') == 'matrix(1, 0, 0, 1, 5, 6)'
	assert resolved.get_property_value('animation-duration') == '0s'
}

fn test_inherited_style_update_reuses_cascade_and_recomputes_font_relative_values() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	doc.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	html_el.set_attribute_value('style', 'font-size: 10px')
	child.set_attribute_value('style', 'width: 2em; height: 10px')
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(child.as_node()) or { panic('${err}') }

	install_document_layout_hook(doc)
	navigable := &dom.Navigable{
		active_document_: doc
	}
	doc.set_cached_navigable(navigable)
	doc.needs_full_layout_tree_update = true
	doc.update_layout(.debugging)
	html_computed := css.computed_properties_for_element(html_el) or { panic('missing html style') }
	child_computed := css.computed_properties_for_element(child) or { panic('missing child style') }
	assert html_computed.font_size().to_double() == 10
	assert child_computed.font_size().to_double() == 10
	assert child.client_width() == 20
	initial := document_layout_result(doc) or { panic('missing initial layout') }

	html_el.set_attribute_value('style', 'font-size: 20px')
	doc.update_layout(.debugging)
	updated := document_layout_result(doc) or { panic('missing updated layout') }
	assert updated.root == initial.root
	computed := css.computed_properties_for_element(child) or { panic('missing child style') }
	assert computed.length_percentage_to_px(.width, 800) or { -1 } == 40
	assert child.client_width() == 40
}

fn test_inherited_style_update_reaches_descendants_without_layout_nodes() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	mut root := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
	mut hidden := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut intermediary := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut target := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'em')!
	root.set_attribute_value('style', 'color: red')
	hidden.set_attribute_value('style', 'display: none')
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(hidden.as_node())!
	mut hidden_node := hidden.as_node()
	hidden_node.append_child(intermediary.as_node())!
	mut intermediary_node := intermediary.as_node()
	intermediary_node.append_child(target.as_node())!

	install_document_layout_hook(doc)
	doc.set_cached_navigable(&dom.Navigable{
		active_document_: doc
	})
	doc.needs_full_layout_tree_update = true
	doc.update_layout(.debugging)
	assert hidden.as_node().layout_node() == none
	assert target.as_node().layout_node() == none
	initial := css.computed_properties_for_element(target) or { panic('missing target style') }
	assert (initial.property(.color, .no) or { panic('missing initial color') }).css_text == 'rgb(255, 0, 0)'

	root.set_attribute_value('style', 'color: blue')
	doc.update_style()
	updated := css.computed_properties_for_element(target) or { panic('missing updated style') }
	assert (updated.property(.color, .no) or { panic('missing updated color') }).css_text == 'rgb(0, 0, 255)'
}

fn test_document_animated_style_update_samples_retained_transition() {
	mut doc := dom.Document.create(dom.url_about_blank())
	doc.set_browsing_context(&dom.BrowsingContext{})
	doc.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	child.set_attribute_value('style', 'opacity: 0; transition-property: opacity; transition-duration: 1000ms; transition-timing-function: linear')
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(child.as_node()) or { panic('${err}') }

	install_document_layout_hook(doc)
	doc.set_cached_navigable(&dom.Navigable{
		active_document_: doc
	})
	doc.needs_full_layout_tree_update = true
	doc.update_layout(.debugging)
	child.set_attribute_value('style', 'opacity: 1; transition-property: opacity; transition-duration: 1000ms; transition-timing-function: linear')
	doc.update_layout(.debugging)
	started := css.computed_properties_for_element(child) or { panic('missing started style') }
	assert (started.property(.opacity, .yes) or { panic('missing starting opacity') }).css_text == '0'

	mut style_computer := css.css_style_computer_for(doc)
	style_computer.set_animation_time_ms(500)
	doc.update_style()
	midpoint := css.computed_properties_for_element(child) or { panic('missing sampled style') }
	assert (midpoint.property(.opacity, .yes) or { panic('missing sampled opacity') }).css_text == '0.5'
}
