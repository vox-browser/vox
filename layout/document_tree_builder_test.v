module layout

import dom
import css
import html

fn document_tree_builder_node_with_id(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.id() or { '' } == id {
				return root
			}
		}
	}
	for child in root.children() {
		if found := document_tree_builder_node_with_id(child, id) {
			return found
		}
	}
	return none
}

// build_layout_tree walks the DOM and produces a real layout tree rooted at the Viewport (whose DOM node is
// the Document); the root element's box is the viewport's child. display:none elements (and their subtrees)
// get no box.
fn test_build_layout_tree() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut body := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'body') or { panic('${err}') }
	mut div := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	mut hidden := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or { panic('${err}') }
	hidden.set_attribute_value('style', 'display: none')

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('append html: ${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(body.as_node()) or { panic('append body: ${err}') }
	mut body_node := body.as_node()
	body_node.append_child(div.as_node()) or { panic('append div: ${err}') }
	body_node.append_child(hidden.as_node()) or { panic('append p: ${err}') }

	root := build_layout_tree(doc) or { panic('no layout tree') }
	// The root is the Viewport; its DOM node is the Document, and <html> is its single box child.
	assert root.is_viewport()
	assert root.child_count() == 1
	html_box := root.first_child() or { panic('no html box') }
	assert html_box.is_block_container()
	root_el := (html_box.dom_node() or { panic('html box has no dom node') }).as_element() or {
		panic('html box dom node not element')
	}
	assert root_el.local_name() == 'html'

	// html has one layout child: body.
	assert html_box.child_count() == 1
	body_box := html_box.first_child() or { panic('no body box') }

	// body's children: div is boxed, the display:none <p> is not.
	assert body_box.child_count() == 1
	div_box := body_box.first_child() or { panic('no div box') }
	div_el := (div_box.dom_node() or { panic('div box has no dom node') }).as_element() or {
		panic('div box dom node not element')
	}
	assert div_el.local_name() == 'div'
	assert div_box.is_block_container()
}

// run_document_layout packages tree-building + block layout into one document entry point.
fn test_run_document_layout() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut div1 := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	div1.set_attribute_value('style', 'height: 30px')
	mut div2 := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	div2.set_attribute_value('style', 'height: 40px')
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(div1.as_node()) or { panic('${err}') }
	html_node.append_child(div2.as_node()) or { panic('${err}') }

	result := run_document_layout(doc, 800.0, 600.0) or { panic('layout produced no result') }

	// The viewport's content box is pinned to the viewport rectangle.
	viewport_nws := result.root.as_node_with_style() or { panic('viewport not nws') }
	viewport_uv := result.used_values_for(viewport_nws) or { panic('no viewport used values') }
	assert viewport_uv.content_width().to_double() == 800.0
	assert viewport_uv.content_height().to_double() == 600.0

	// <html> fills the viewport width; its auto height = 30 + 40 = 70.
	html_box := result.root.first_child() or { panic('no html box') }
	html_nws := html_box.as_node_with_style() or { panic('html not nws') }
	html_uv := result.used_values_for(html_nws) or { panic('no html used values') }
	assert html_uv.content_width().to_double() == 800.0
	assert html_uv.content_height().to_double() == 70.0

	div2_nws := html_box.children()[1].as_node_with_style() or { panic('div2 not nws') }
	div2_uv := result.used_values_for(div2_nws) or { panic('no div2 used values') }
	assert div2_uv.content_height().to_double() == 40.0
	assert div2_uv.offset.y().to_double() == 30.0
}

fn test_tree_dump_layout_does_not_build_renderer_transport() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut body := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'body') or {
		panic('${err}')
	}
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(body.as_node()) or { panic('${err}') }

	result := run_document_layout_for_tree_dump(doc, 320, 200) or {
		panic('layout produced no result')
	}
	assert result.paint_tree.tag_name == ''
	assert result.paint_tree.width == 0
	assert result.paint_tree.height == 0
	tree_text := dump_current_document_layout_tree(doc) or {
		panic('layout tree was not retained')
	}
	assert tree_text.contains('Viewport')
	assert tree_text.contains('BlockContainer <html>')
}

fn test_layout_snapshot_uses_current_upstream_sections() {
	mut doc := html.parse_document('<!doctype html><div>snapshot</div>')
	snapshot := dump_document_layout_snapshot(doc, 320, 200) or {
		panic('layout snapshot was not produced')
	}
	sections := snapshot.split('\n\n')
	// Since 980be4b6b2d, LayoutTest no longer includes the intermediate
	// paintable-tree dump. The second and final section is the stacking tree.
	assert sections.len == 2
	assert sections[0].starts_with('Viewport <#document>')
	assert sections[1].starts_with('SC for Viewport<#document>')
	assert !sections[1].contains('[children:')
}

fn test_layout_tree_dump_includes_scrollable_overflow() {
	mut doc := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#scroller { width: 100px; height: 50px; overflow: auto }
		#content { width: 200px; height: 100px }
	</style><div id="scroller"><div id="content"></div></div>')
	tree := dump_document_layout_tree(doc, 320, 200) or {
		panic('layout tree was not produced')
	}
	scroller_line := tree.split_into_lines().filter(it.contains('<div#scroller>'))[0]
	assert scroller_line.ends_with(' overflow: [0,0 200x100]')
}

fn test_layout_tree_dump_includes_viewport_overflow() {
	mut doc := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#content { width: 400px; height: 300px }
	</style><div id="content"></div>')
	tree := dump_document_layout_tree(doc, 320, 200) or {
		panic('layout tree was not produced')
	}
	assert tree.split_into_lines()[0].ends_with(' overflow: [0,0 400x300]')
}

fn test_scrollable_overflow_preserves_end_padding() {
	mut doc := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#scroller { width: 100px; height: 50px; padding: 25px; overflow: auto }
		#content { box-sizing: content-box; width: 100px; height: 100px; border: 1px solid }
	</style><div id="scroller"><div id="content"></div></div>')
	result := run_document_layout(doc, 320, 200) or { panic('layout failed') }
	scroller := document_tree_builder_node_with_id(result.root, 'scroller') or {
		panic('missing #scroller')
	}
	styled := scroller.as_node_with_style() or { panic('#scroller has no style') }
	used := result.state.try_get(styled) or { panic('#scroller has no used values') }
	overflow := used.scrollable_overflow_rect() or { panic('#scroller has no overflow rect') }
	assert used.has_scrollable_overflow()
	assert layout_debug_css_rect(overflow) == '[0,0 152x152]'
}

// A DOM text node becomes a Layout::TextNode carrying offset-preserving rendered text.
fn test_text_node_layout() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut para := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or { panic('${err}') }
	text := doc.create_text_node('  Hello    world  ')

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(para.as_node()) or { panic('${err}') }
	mut para_node := para.as_node()
	para_node.append_child(text.as_node()) or { panic('${err}') }

	root := build_layout_tree(doc) or { panic('no layout tree') }
	html_box := root.first_child() or { panic('no html box') }
	para_box := html_box.first_child() or { panic('no p box') }
	assert para_box.is_block_container()

	text_box := para_box.first_child() or { panic('no text box') }
	assert text_box.is_text_node()
	assert !text_box.is_box()
	text_node := text_box.as_text_node() or { panic('text box is not a TextNode') }
	// TextNode::compute_text_for_rendering converts collapsible tabs/newlines
	// without destroying code-unit offsets; repeated spaces are collapsed later
	// by ChunkIterator.
	assert text_node.text_for_rendering() == '  Hello    world  '
	text_dom := text_box.dom_node() or { panic('text box has no dom node') }
	assert text_dom.is_text()

	// The bridge marks it as a text node on the DOM side too.
	result := run_document_layout(doc, 800.0, 600.0) or { panic('no layout result') }
	attach_layout_nodes(result.root)
	text_layout := text.as_node().layout_node() or { panic('text has no layout node') }
	assert text_layout.is_text_node()
	assert text.as_node().accessible_name(doc, .no)! == '  Hello    world  '
}

// A block whose content is inline (text) gets the computed line-height.
fn test_inline_content_height() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut para := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or { panic('${err}') }
	text := doc.create_text_node('Hello world')
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(para.as_node()) or { panic('${err}') }
	mut para_node := para.as_node()
	para_node.append_child(text.as_node()) or { panic('${err}') }

	result := run_document_layout(doc, 800.0, 600.0) or { panic('no layout result') }
	html_box := result.root.first_child() or { panic('no html box') }
	para_box := html_box.first_child() or { panic('no p box') }
	para_nws := para_box.as_node_with_style() or { panic('p not nws') }
	para_uv := result.used_values_for(para_nws) or { panic('no p used values') }
	// Compare with ComputedProperties::line_height(), rather than duplicating
	// the engine's current normal-line-height scale.
	height := para_uv.content_height().to_double()
	assert height == para_nws.computed_values().line_height().to_double()
}

// Mixed inline + block content in one container: a text node beside a block element. The text is wrapped in
// an anonymous block box (CSS 2.1 §9.2.1.1) so the container's children are all block-level, and the block
// sibling is not dropped.
fn test_anonymous_block_wrapping_for_mixed_content() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut div := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	div.set_attribute_value('style', 'color: rgb(1, 2, 3); margin-top: 33px')
	text := doc.create_text_node('hello')
	mut para := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or { panic('${err}') }

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(div.as_node()) or { panic('${err}') }
	mut div_node := div.as_node()
	div_node.append_child(text.as_node()) or { panic('${err}') }
	div_node.append_child(para.as_node()) or { panic('${err}') }

	// Build + lay out once, then navigate that single tree (build_layout_tree runs again internally, so a
	// tree built separately would hold different node pointers than the laid-out one).
	result := run_document_layout(doc, 800.0, 600.0) or { panic('no layout result') }
	html_box := result.root.first_child() or { panic('no html box') }
	div_box := html_box.first_child() or { panic('no div box') }

	// The div has mixed content, so it is block-level with two block children: an anonymous wrapper (holding
	// the text) followed by the <p> box.
	assert !div_box.children_are_inline()
	assert div_box.child_count() == 2

	wrapper := div_box.first_child() or { panic('no wrapper') }
	assert wrapper.is_anonymous()
	assert wrapper.children_are_inline()
	assert wrapper.child_count() == 1
	wrapper_style := wrapper.as_node_with_style() or { panic('wrapper has no style') }
	assert wrapper_style.computed_values().display().is_block_outside()
	assert (wrapper_style.computed_values().property(.margin_top, .yes) or {
		panic('missing margin-top')
	}).css_text != '33px'
	assert (wrapper_style.computed_values().property(.color, .yes) or { panic('missing color') }).css_text == (div_box.computed_values().property(.color, .yes) or { panic('missing parent color') }).css_text
	wrapper_child := wrapper.first_child() or { panic('no wrapper child') }
	assert wrapper_child.is_text_node()

	para_box := div_box.children()[1]
	assert !para_box.is_anonymous()
	para_el := (para_box.dom_node() or { panic('p box has no dom node') }).as_element() or {
		panic('p box dom node not element')
	}
	assert para_el.local_name() == 'p'

	// The block sibling is laid out (not dropped): it sits below the anonymous text line box (~19.2px).
	para_uv := result.used_values_for(para_box.as_node_with_style() or { panic('p not nws') }) or {
		panic('no p used values')
	}
	assert para_uv.offset.y().to_double() > 19.0
}

fn test_flex_children_are_blockified_and_marked_as_items() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut flex := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	flex.set_attribute_value('style', 'display:flex')
	text := doc.create_text_node('text')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(flex.as_node()) or { panic('${err}') }
	mut flex_node := flex.as_node()
	flex_node.append_child(text.as_node()) or { panic('${err}') }
	flex_node.append_child(child.as_node()) or { panic('${err}') }

	result := run_document_layout(doc, 800, 600) or { panic('layout failed') }
	root := result.root
	flex_box := (root.first_child() or { panic('html') }).first_child() or { panic('flex') }
	assert flex_box.display().is_flex_inside()
	assert flex_box.child_count() == 2
	assert flex_box.children()[0].is_anonymous()
	assert flex_box.children()[0].is_flex_item()
	assert flex_box.children()[1].is_flex_item()
}

// The initial containing block is the viewport, so a root-level percentage height resolves against the
// viewport height (CSS 2.1 §10.5): `html { height: 50% }` in a 600px-tall viewport is 300px.
fn test_root_percentage_height_resolves_against_viewport() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	html_el.set_attribute_value('style', 'height: 50%')
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }

	result := run_document_layout(doc, 800.0, 600.0) or { panic('no layout result') }
	html_box := result.root.first_child() or { panic('no html box') }
	html_nws := html_box.as_node_with_style() or { panic('html not nws') }
	html_uv := result.used_values_for(html_nws) or { panic('no html used values') }
	// 50% of the 600px viewport height.
	assert html_uv.content_height().to_double() == 300.0
}

fn test_display_type_selects_literal_layout_node_subclass() {
	doc := dom.Document.create(dom.url_about_blank())
	style_computer := css.css_style_computer_for(doc)

	span := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic('${err}') }
	span_style := style_computer.compute_style(dom.AbstractElement.new(span, none))
	span_node := create_layout_node_for_element(doc, span, span_style) or { panic('no span node') }
	assert span_node.is_inline_node()
	assert span_node.is_inline()
	assert !span_node.is_box()

	mut flex := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	flex.set_attribute_value('style', 'display: flex')
	flex_style := style_computer.compute_style(dom.AbstractElement.new(flex, none))
	flex_node := create_layout_node_for_element(doc, flex, flex_style) or { panic('no flex node') }
	assert flex_node.is_box()
	assert !flex_node.is_block_container()

	list_item := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'li') or { panic('${err}') }
	list_style := style_computer.compute_style(dom.AbstractElement.new(list_item, none))
	list_node := create_layout_node_for_element(doc, list_item, list_style) or {
		panic('no list-item node')
	}
	assert list_node.is_list_item_box()
	assert list_node.is_block_container()

	br := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'br') or { panic('${err}') }
	br_style := style_computer.compute_style(dom.AbstractElement.new(br, none))
	br_node := create_layout_node_for_element(doc, br, br_style) or { panic('no br node') }
	assert br_node.is_break_node()
	assert !br_node.can_have_children()

	mut checkbox := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'input') or {
		panic('${err}')
	}
	checkbox.set_attribute_value('type', 'checkbox')
	checkbox_style := style_computer.compute_style(dom.AbstractElement.new(checkbox, none))
	checkbox_node := create_layout_node_for_element(doc, checkbox, checkbox_style) or {
		panic('no checkbox node')
	}
	assert checkbox_node.is_replaced_box()
	assert !checkbox_node.can_have_children()
	checkbox_box := checkbox_node.as_box() or { panic('checkbox is not a box') }
	checkbox_width := checkbox_box.auto_content_box_size().width or { CSSPixels.new(0) }
	assert checkbox_width.to_double() == 13

	mut hidden_input := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'input') or {
		panic('${err}')
	}
	hidden_input.set_attribute_value('type', 'hidden')
	hidden_style := style_computer.compute_style(dom.AbstractElement.new(hidden_input, none))
	assert create_layout_node_for_element(doc, hidden_input, hidden_style) == none

	mut primitive_input := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'input') or {
		panic('${err}')
	}
	primitive_input.set_attribute_value('style', 'appearance:none;display:inline')
	primitive_style := style_computer.compute_style(dom.AbstractElement.new(primitive_input, none))
	primitive_node := create_layout_node_for_element(doc, primitive_input, primitive_style) or {
		panic('no primitive input node')
	}
	assert primitive_node.is_block_container()
	assert !primitive_node.is_text_input_box()

	media_document := html.parse_document('<!doctype html><audio id="audio" controls><span id="audio-fallback">fallback</span></audio><video id="video"><span id="video-fallback">fallback</span></video>')
	media_root := build_layout_tree(media_document) or { panic('no media layout tree') }
	attach_layout_nodes(media_root)
	assert tree_builder_node_with_id(media_root, 'audio') or { panic('no audio box') }.is_replaced_box()
	assert tree_builder_node_with_id(media_root, 'video') or { panic('no video box') }.is_replaced_box()
	assert tree_builder_node_with_id(media_root, 'audio-fallback') == none
	assert tree_builder_node_with_id(media_root, 'video-fallback') == none
	audio_dom := media_document.get_element_by_id('audio') or { panic('audio DOM') }
	video_dom := media_document.get_element_by_id('video') or { panic('video DOM') }
	assert html_audio_element_layout_node(unsafe { &dom.HTMLAudioElement(audio_dom) }) != none
	assert html_video_element_layout_node(unsafe { &dom.HTMLVideoElement(video_dom) }) != none

	textarea := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'textarea') or {
		panic('${err}')
	}
	textarea_style := style_computer.compute_style(dom.AbstractElement.new(textarea, none))
	textarea_node := create_layout_node_for_element(doc, textarea, textarea_style) or {
		panic('no textarea node')
	}
	assert textarea_node.is_textarea_box()
	assert textarea_node.is_block_container()

	fieldset := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'fieldset') or {
		panic('${err}')
	}
	fieldset_style := style_computer.compute_style(dom.AbstractElement.new(fieldset, none))
	fieldset_node := create_layout_node_for_element(doc, fieldset, fieldset_style) or {
		panic('no fieldset node')
	}
	assert fieldset_node.is_fieldset_box()
	assert html_field_set_element_layout_node(fieldset_node) != none
	assert creates_block_formatting_context(fieldset_node.as_node_with_style() or {
		panic('fieldset has no style')
	})

	legend := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'legend') or {
		panic('${err}')
	}
	legend_style := style_computer.compute_style(dom.AbstractElement.new(legend, none))
	legend_node := create_layout_node_for_element(doc, legend, legend_style) or {
		panic('no legend node')
	}
	assert legend_node.is_legend_box()
	assert html_legend_element_layout_node(legend_node) != none

	iframe := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'iframe') or {
		panic('${err}')
	}
	iframe_style := style_computer.compute_style(dom.AbstractElement.new(iframe, none))
	iframe_node := html_iframe_element_create_layout_node(doc, unsafe {
		&dom.HTMLIFrameElement(iframe)
	}, iframe_style)
	assert iframe_node.is_navigable_container_viewport()

	canvas := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas') or {
		panic('${err}')
	}
	canvas_style := style_computer.compute_style(dom.AbstractElement.new(canvas, none))
	canvas_node := html_canvas_element_create_layout_node(doc, unsafe {
		&dom.HTMLCanvasElement(canvas)
	}, canvas_style)
	assert canvas_node.is_replaced_box()
}

fn test_object_unknown_representation_runs_fallback_steps_and_keeps_inline_display() {
	mut document := html.parse_document('<!doctype html><body><object id="object" data="https://example.test/missing.html" type="text/html">fallback</object></body>')
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)

	root := build_layout_tree(document) or { panic('no object fallback layout tree') }
	object_node := tree_builder_node_with_id(root, 'object') or { panic('no object layout node') }
	assert object_node.is_inline_node()
	fallback_text := object_node.first_child() or { panic('no object fallback text') }
	assert fallback_text.is_text_node()
	object_element := document.get_element_by_id('object') or { panic('no object element') }
	model := html.html_object_element_model_for_dom_element(unsafe {
		&dom.HTMLObjectElement(object_element)
	})
	assert model.representation() == .children
}

fn tree_builder_node_with_id(node &Node, id string) ?&Node {
	if dom_node := node.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id {
				return node
			}
		}
	}
	for child in node.children() {
		if found := tree_builder_node_with_id(child, id) {
			return found
		}
	}
	return none
}

fn test_before_and_after_pseudo_elements_generate_layout_content_in_tree_order() {
	document := html.parse_document('<!doctype html><style>
		#target::before { content:"before" }
		#target::after { content:"after" }
</style><div id="target" role="button">middle</div>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	target := tree_builder_node_with_id(root, 'target') or { panic('no target') }
	assert target.children_are_inline()
	assert target.child_count() == 3
	assert target.children()[0].is_generated_for_before_pseudo_element()
	assert (target.children()[0].first_child() or { panic('before has no text') }).as_text_node() or {
		panic('before child is not text')
	}.text_for_rendering() == 'before'
	assert target.children()[1].as_text_node() or { panic('middle is not text') }.text_for_rendering() == 'middle'
	assert target.children()[2].is_generated_for_after_pseudo_element()
	assert (target.children()[2].first_child() or { panic('after has no text') }).as_text_node() or {
		panic('after child is not text')
	}.text_for_rendering() == 'after'
	attach_layout_nodes(root)
	target_element := document.get_element_by_id('target') or { panic('no target element') }
	assert target_element.as_node().accessible_name(document, .yes)! == 'before middleafter'
}

fn test_generated_inline_content_is_laid_out_inside_mixed_content_wrappers() {
	document := html.parse_document('<!doctype html><style>
		span { display:list-item }
		span::before { content:"before" }
		span::after { content:"after" }
	</style><span id="target"><div></div></span>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	target := tree_builder_node_with_id(result.root, 'target') or { panic('no target') }
	assert target.child_count() == 4
	before_wrapper := target.children()[1]
	after_wrapper := target.children()[3]
	assert before_wrapper.is_anonymous() && before_wrapper.children_are_inline()
	assert after_wrapper.is_anonymous() && after_wrapper.children_are_inline()
	before_generated := before_wrapper.first_child() or { panic('no generated before') }
	after_generated := after_wrapper.first_child() or { panic('no generated after') }
	assert before_generated.is_inline_node()
	assert before_generated.display().is_inline_outside()
	assert before_generated.display().is_flow_inside()
	assert (before_generated.first_child() or { panic('before child') }).display().is_inline_outside()
	assert (before_generated.first_child() or { panic('before text') }).as_text_node() or {
		panic('before text node')
	}.text_for_rendering() == 'before'
	assert (after_generated.first_child() or { panic('after text') }).as_text_node() or {
		panic('after text node')
	}.text_for_rendering() == 'after'
	before_used := result.used_values_for(before_wrapper.as_node_with_style() or {
		panic('before wrapper style')
	}) or { panic('before wrapper used values') }
	after_used := result.used_values_for(after_wrapper.as_node_with_style() or {
		panic('after wrapper style')
	}) or { panic('after wrapper used values') }
	mut mutable_state := unsafe { &LayoutState(result.state) }
	manual_iterator := InlineLevelIterator.new(mut mutable_state, before_wrapper.as_block_container() or {
		panic('before wrapper block')
	}, before_used, .normal, AvailableSpace.new(AvailableSize.make_definite(before_used.content_width()), AvailableSize.make_indefinite()), none)
	assert manual_iterator.items().len > 0
	assert before_used.line_boxes.len == 1
	assert after_used.line_boxes.len == 1
	assert before_used.content_height().to_double() > 0
	assert after_used.content_height().to_double() > 0
}

fn test_normal_list_marker_is_created_and_laid_out() {
	document := html.parse_document('<!doctype html><ol><li id="item">item</li></ol>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item_node := tree_builder_node_with_id(result.root, 'item') or { panic('no list item') }
	list_item := item_node.as_list_item_box() or { panic('item is not ListItemBox') }
	marker_node := list_item.marker() or { panic('list item has no marker') }
	marker := marker_node.as_list_item_marker_box() or { panic('marker has wrong node type') }
	assert marker.text() or { '' } == '1. '
	marker_used := result.used_values_for(marker_node.as_node_with_style() or {
		panic('marker has no style')
	}) or { panic('marker was not laid out') }
	assert marker_used.content_width().to_double() > 0
	assert marker_used.offset.x().to_double() < 0
}

fn test_predefined_symbol_marker_uses_geometric_marker_size() {
	document := html.parse_document('<!doctype html><ul><li id="item">item</li></ul>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item_node := tree_builder_node_with_id(result.root, 'item') or { panic('no list item') }
	list_item := item_node.as_list_item_box() or { panic('item is not ListItemBox') }
	marker_node := list_item.marker() or { panic('list item has no marker') }
	marker := marker_node.as_list_item_marker_box() or { panic('marker has wrong node type') }
	assert marker.list_style_type_.name == 'disc'
	assert marker.text() == none
	assert marker.relative_size().to_double() == 6
	marker_used := result.used_values_for(marker_node.as_node_with_style() or {
		panic('marker has no style')
	}) or { panic('marker was not laid out') }
	assert marker_used.content_width().to_double() == 6
	assert marker_used.content_height().to_double() == 6
}

fn test_marker_preserves_literal_string_list_style_type() {
	document := html.parse_document('<!doctype html><style>li { list-style-type: "->" }</style><ul><li id="item">item</li></ul>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	item_node := tree_builder_node_with_id(root, 'item') or { panic('no list item') }
	marker := (item_node.as_list_item_box() or { panic('item is not ListItemBox') }).marker() or {
		panic('list item has no marker')
	}
	marker_box := marker.as_list_item_marker_box() or { panic('marker has wrong node type') }
	assert marker_box.list_style_type_.kind == .string
	assert marker_box.text() or { '' } == '->'
}

fn test_marker_uses_resolved_custom_counter_style() {
	document := html.parse_document('<!doctype html><style>
		@counter-style custom { system: fixed; symbols: "A" "B"; prefix: "["; suffix: "]"; }
		li { list-style-type: custom }
	</style><ol><li id="item">item</li></ol>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	item_node := tree_builder_node_with_id(root, 'item') or { panic('no list item') }
	marker := (item_node.as_list_item_box() or { panic('item is not ListItemBox') }).marker() or {
		panic('list item has no marker')
	}
	marker_box := marker.as_list_item_marker_box() or { panic('marker has wrong node type') }
	assert marker_box.list_style_type_.kind == .counter_style
	assert (marker_box.list_style_type_.counter_style or { panic('counter style did not resolve') }).name() == 'custom'
	assert marker_box.text() or { '' } == '[A]'
}

fn test_marker_missing_counter_style_falls_back_to_decimal() {
	document := html.parse_document('<!doctype html><style>li { list-style-type: missing }</style><ol><li id="item">item</li></ol>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	item_node := tree_builder_node_with_id(root, 'item') or { panic('no list item') }
	marker := (item_node.as_list_item_box() or { panic('item is not ListItemBox') }).marker() or {
		panic('list item has no marker')
	}
	marker_box := marker.as_list_item_marker_box() or { panic('marker has wrong node type') }
	assert marker_box.list_style_type_.kind == .counter_style
	assert marker_box.list_style_type_.counter_style == none
	assert marker_box.text() or { '' } == '1. '
}

fn test_table_fixup_generates_wrapper_rows_and_cells() {
	document := html.parse_document('<!doctype html><style>
		#misparented { display:table-cell }
	</style><div id="misparented">cell</div><div id="table" style="display:table">text</div>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	misparented := tree_builder_node_with_id(root, 'misparented') or { panic('no cell') }
	assert misparented.display().is_table_cell()
	row := misparented.parent() or { panic('cell has no row') }
	assert row.is_anonymous()
	assert row.display().is_table_row()
	anonymous_table := row.parent() or { panic('row has no table') }
	assert anonymous_table.is_anonymous()
	assert anonymous_table.display().is_table_inside()
	assert (anonymous_table.parent() or { panic('table has no wrapper') }).is_table_wrapper()
	assert anonymous_table.has_been_wrapped_in_table_wrapper()

	table := tree_builder_node_with_id(root, 'table') or { panic('no explicit table') }
	assert (table.parent() or { panic('explicit table has no wrapper') }).is_table_wrapper()
	assert table.has_been_wrapped_in_table_wrapper()
	generated_row := table.first_child() or { panic('table text has no generated row') }
	assert generated_row.is_anonymous()
	assert generated_row.display().is_table_row()
	generated_cell := generated_row.first_child() or { panic('row has no generated cell') }
	assert generated_cell.is_anonymous()
	assert generated_cell.display().is_table_cell()
	assert (generated_cell.first_child() or { panic('cell has no text') }).is_text_node()
}

fn test_table_fixup_discards_irrelevant_whitespace() {
	document := html.parse_document('<!doctype html><style>
		.cell { display: table-cell }
	</style>
	<table id="table">
		<tbody id="group"><tr><td>cell</td></tr></tbody>
	</table>
	<div id="host"><span id="one" class="cell">one</span> <span id="two" class="cell">two</span> tail</div>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	table := tree_builder_node_with_id(root, 'table') or { panic('no table') }
	assert table.child_count() == 1
	group := tree_builder_node_with_id(root, 'group') or { panic('no row group') }
	assert voidptr(table.first_child() or { panic('table is empty') }) == voidptr(group)
	one := tree_builder_node_with_id(root, 'one') or { panic('no first cell') }
	two := tree_builder_node_with_id(root, 'two') or { panic('no second cell') }
	row := one.parent() or { panic('first cell has no row') }
	assert voidptr(row) == voidptr(two.parent() or { panic('second cell has no row') })
	assert row.child_count() == 2
	generated_table := row.parent() or { panic('cells have no generated table') }
	assert generated_table.display().is_table_inside()
	assert (generated_table.parent() or { panic('generated table has no wrapper') }).next_sibling() != none
}

fn test_fieldset_moves_non_legend_content_into_flow_root_wrapper() {
	document := html.parse_document('<!doctype html><style>
		#fieldset { width:200px; border:2px solid; padding:10px }
		#legend { width:50px; height:20px }
		#content { height:30px }
	</style><fieldset id="fieldset"><legend id="legend">Legend</legend><div id="content"></div></fieldset>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	fieldset_node := tree_builder_node_with_id(result.root, 'fieldset') or { panic('no fieldset') }
	assert fieldset_node.is_fieldset_box()
	assert fieldset_node.child_count() == 2
	legend_node := fieldset_node.children()[0]
	assert legend_node.is_legend_box()
	wrapper := fieldset_node.children()[1]
	assert wrapper.is_anonymous()
	assert wrapper.display().is_flow_root_inside()
	assert tree_builder_node_with_id(wrapper, 'content') != none
	fieldset_used := result.used_values_for(fieldset_node.as_node_with_style() or {
		panic('fieldset has no style')
	}) or { panic('fieldset has no used values') }
	legend_used := result.used_values_for(legend_node.as_node_with_style() or {
		panic('legend has no style')
	}) or { panic('legend has no used values') }
	assert fieldset_used.padding_top.to_double() == 10
	assert legend_used.offset.y().to_double() < 0
	assert fieldset_used.content_height().to_double() >= 48
}

fn test_block_inside_inline_creates_before_and_after_inline_continuations() {
	document := html.parse_document('<!doctype html><div id="outer">before<span id="inline">one<div id="block" style="height:20px">block</div>two</span>after</div>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	outer := tree_builder_node_with_id(root, 'outer') or { panic('no outer') }
	assert !outer.children_are_inline()
	assert outer.child_count() == 3
	before_wrapper := outer.children()[0]
	middle_wrapper := outer.children()[1]
	after_wrapper := outer.children()[2]
	assert before_wrapper.is_anonymous() && before_wrapper.children_are_inline()
	assert middle_wrapper.is_anonymous() && !middle_wrapper.children_are_inline()
	assert middle_wrapper.child_count() == 1
	block := middle_wrapper.children()[0]
	block_dom := block.dom_node() or { panic('block has no DOM node') }
	assert (block_dom.as_element() or { panic('block DOM node is not element') }).get_attribute_value('id') == 'block'
	assert after_wrapper.is_anonymous() && after_wrapper.children_are_inline()
	inline_before := tree_builder_node_with_id(before_wrapper, 'inline') or {
		panic('no primary inline node')
	}
	mut inline_after := ?&Node(none)
	for child in after_wrapper.children() {
		if child.is_inline_node() && child.dom_node() != none {
			inline_after = child
			break
		}
	}
	continuation := inline_after or { panic('no inline continuation') }
	assert !layout_nodes_same(inline_before, continuation)
	metrics := continuation.as_node_with_style_and_box_model_metrics() or {
		panic('continuation has no metrics')
	}
	assert metrics.continuation_of_node() != none
	middle_metrics := middle_wrapper.as_node_with_style_and_box_model_metrics() or {
		panic('middle continuation has no metrics')
	}
	assert middle_metrics.continuation_of_node() != none
	assert layout_nodes_same(unsafe {
		&Node(metrics.continuation_of_node() or { panic('continuation has no source') })
	}, middle_wrapper)
}

fn test_svg_elements_create_their_concrete_layout_node_types_without_html_wrappers() {
	document := html.parse_document('<!doctype html><svg id="root-svg" width="200" height="100" viewBox="0 0 100 50"><g id="group"><rect id="shape" x="20" y="10" width="30" height="15"/><text id="label">hello</text></g><foreignObject id="foreign" x="5" y="6" width="40" height="20"><div id="html-child">x</div></foreignObject><defs><rect id="definition"/></defs></svg>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	svg_root := tree_builder_node_with_id(root, 'root-svg') or { panic('no SVG root') }
	assert svg_root.is_svg_svg_box()
	assert svg_root.is_replaced_box_with_children()
	group := tree_builder_node_with_id(svg_root, 'group') or { panic('no SVG group') }
	assert group.is_svg_graphics_box()
	assert layout_nodes_same(group.parent() or { panic('group has no parent') }, svg_root)
	shape := tree_builder_node_with_id(group, 'shape') or { panic('no SVG shape') }
	assert shape.is_svg_geometry_box()
	assert layout_nodes_same(shape.parent() or { panic('shape has no parent') }, group)
	label := tree_builder_node_with_id(group, 'label') or { panic('no SVG text') }
	assert label.is_svg_text_box()
	foreign := tree_builder_node_with_id(svg_root, 'foreign') or { panic('no foreignObject') }
	assert foreign.is_svg_foreign_object_box()
	assert tree_builder_node_with_id(foreign, 'html-child') != none
	assert tree_builder_node_with_id(svg_root, 'definition') == none
}

fn test_document_layout_caches_only_paintable_boxes_with_auto_content_visibility() {
	document := html.parse_document('<!doctype html><style>#near, #far { content-visibility: auto } #gone { content-visibility: auto; display: none }</style><div id="near"></div><div id="ordinary"></div><div id="far"></div><div id="gone"></div>')
	_ = run_document_layout(document, 800, 600) or { panic('layout failed') }
	viewport_paintable := document.paintable() or { panic('no viewport paintable') }
	paintable_boxes := viewport_paintable.paintable_boxes_with_auto_content_visibility()
	assert paintable_boxes.len == 2
	assert (paintable_boxes[0].dom_node_.as_element() or { panic('first box has no element') }).id() or {
		''
	} == 'near'
	assert (paintable_boxes[1].dom_node_.as_element() or { panic('second box has no element') }).id() or {
		''
	} == 'far'

	// The getter is a readonly-span equivalent: mutating the returned slice must
	// not alter the cache owned by the viewport paintable.
	mut returned_boxes := paintable_boxes.clone()
	returned_boxes.clear()
	assert viewport_paintable.paintable_boxes_with_auto_content_visibility().len == 2
}
