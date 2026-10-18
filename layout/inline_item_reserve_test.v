module layout

import css
import dom
import math

fn reserve_previous_iterator_new(mut state LayoutState, containing_block &BlockContainer, containing_block_used_values &UsedValues, layout_mode LayoutMode, available_space AvailableSpace, parent_block_context ?&BlockFormattingContext) &InlineLevelIterator {
	mut iterator := &InlineLevelIterator{
		state: state
		containing_block: containing_block
		containing_block_used_values: containing_block_used_values
		next_node: unsafe { &Node(containing_block) }.first_child()
		layout_mode: layout_mode
		available_space: available_space
		parent_block_context: parent_block_context
	}
	iterator.is_unidirectional_left_to_right = iterator.compute_is_unidirectional_left_to_right()
	iterator.skip_to_next()
	iterator.reserve_previous_generate_all_items()
	return iterator
}

fn (mut iterator InlineLevelIterator) reserve_previous_generate_all_items() {
	for {
		item := iterator.reserve_previous_generate_next_item() or { break }
		if item.type_ in [.forced_break, .block_level_box] {
			iterator.accumulated_width_for_tabs = CSSPixels.new(0)
		} else {
			iterator.accumulated_width_for_tabs =
				iterator.accumulated_width_for_tabs.plus(item.border_box_width())
		}
		iterator.items << item
	}
}

fn (mut iterator InlineLevelIterator) reserve_previous_generate_next_item() ?InlineLevelItem {
	current := iterator.current_node or { return none }
	if text_node := current.as_text_node() {
		if !iterator.has_text_node_context {
			iterator.reserve_previous_enter_text_node(text_node)
		}
		mut context := &iterator.text_node_context
		is_first_chunk := context.next_chunk_index == 0
		if context.next_chunk_index >= context.chunks.len {
			iterator.has_text_node_context = false
			iterator.text_node_context = InlineTextNodeContext{}
			iterator.previous_chunk_can_break_after = false
			iterator.skip_to_next()
			return iterator.reserve_previous_generate_next_item()
		}
		chunk := context.chunks[context.next_chunk_index]
		context.next_chunk_index++
		is_last_chunk := context.next_chunk_index >= context.chunks.len
		mut text_type := chunk.text_type
		if text_type in [.ltr, .rtl] {
			context.last_known_direction = text_type
		}
		if context.should_respect_linebreaks && chunk.has_breaking_newline {
			text_type = if chunk.is_all_whitespace { .end_padding } else { text_type }
		}
		if text_type == .context_dependent {
			text_type = iterator.resolve_text_direction_from_context()
		}
		if context.should_respect_linebreaks && chunk.has_breaking_newline {
			return InlineLevelItem{
				type_: .forced_break
			}
		}
		computed := text_node.Node.computed_values()
		letter_spacing := resolved_text_spacing_for_node(unsafe { &Node(text_node) }, .letter_spacing).to_double()
		word_spacing :=
			resolved_text_spacing_for_node(unsafe { &Node(text_node) }, .word_spacing).to_double()
		mut shaped_text := chunk.view
		mut x := 0.0
		if chunk.has_breaking_tab {
			tab_size := computed.tab_size()
			tab_width := if tab_size.is_length {
				resolve_font_dependent_length_for_node(unsafe { &Node(text_node) }, tab_size.length).to_double()
			} else {
				tab_size.number * (f64(chunk.font.glyph_width(u32(` `))) + word_spacing + letter_spacing)
			}
			accumulated := iterator.accumulated_width_for_tabs.to_double()
			mut stop_distance := if accumulated > 0 && tab_width > 0 {
				math.ceil(accumulated / tab_width) * tab_width - accumulated
			} else {
				tab_width
			}
			if stop_distance < f64(chunk.font.glyph_width(u32(`0`))) * 0.5 {
				stop_distance += tab_width
			}
			mut tab_count := 0
			for character in shaped_text.runes() {
				if character != `\t` {
					break
				}
				tab_count++
			}
			stop_distance *= tab_count
			units := utf16_code_units_for_line_box(shaped_text)
			shaped_text = string_from_utf16_code_units_for_line_box(units[tab_count..])
			x = stop_distance
		}
		shaped := iterator.shape_text_for_layout(text_node, f32(x), f32(letter_spacing), f32(word_spacing), shaped_text, chunk.font, text_type)
		glyph_run := shaped.glyph_run
		chunk_width := CSSPixels.nearest_value_for(f64(glyph_run.width()) + x)
		is_empty_editable := chunk.length == 0 && text_node.produces_line_box_fragment_when_empty_
		is_generated_empty_string := is_empty_editable
			|| (text_node.retains_empty_generated_fragment_ && chunk.length == 0)
		mut item := InlineLevelItem{
			type_: .text
			node: current
			glyph_run: glyph_run
			offset_in_node: chunk.start
			length_in_node: chunk.length
			width: chunk_width
			is_collapsible_whitespace: context.should_collapse_whitespace && chunk.is_all_whitespace
				&& !is_generated_empty_string
			is_all_whitespace: chunk.is_all_whitespace
			can_break_before: iterator.previous_chunk_can_break_after
			trailing_whitespace: if chunk.is_all_whitespace {
				TrailingWhitespace{
					length_in_code_units: chunk.length
					inline_size: chunk_width
				}
			} else {
				TrailingWhitespace{
					length_in_code_units: shaped.trailing_whitespace.length_in_code_units
					inline_size: CSSPixels.nearest_value_for(shaped.trailing_whitespace.advance)
				}
			}
		}
		iterator.previous_chunk_can_break_after = chunk.can_break_after
		iterator.add_extra_box_model_metrics_to_item(mut item, is_first_chunk, is_last_chunk)
		// The zero-length generated fragment anchors its inline ancestor's box
		// geometry. Its closing edges are derived from that ancestor's used values;
		// they do not advance the following text in upstream's retained line.
		if text_node.retains_empty_generated_fragment_ && chunk.length == 0 {
			item.padding_end = CSSPixels.new(0)
			item.border_end = CSSPixels.new(0)
			item.margin_end = CSSPixels.new(0)
		}
		return item
	}

	if current.is_absolutely_positioned() {
		mut has_unattached_inline_start_edges := false
		if leading := iterator.extra_leading_metrics {
			has_unattached_inline_start_edges = leading.margin.raw_value() != 0
				|| leading.border.raw_value() != 0 || leading.padding.raw_value() != 0
		}
		iterator.skip_to_next()
		return InlineLevelItem{
			type_: .absolutely_positioned_element
			node: current
			preceded_by_unattached_inline_start_edges: has_unattached_inline_start_edges
		}
	}
	if current.is_floating() {
		iterator.skip_to_next()
		return InlineLevelItem{
			type_: .floating_element
			node: current
		}
	}
	if current.is_break_node() {
		iterator.skip_to_next()
		return InlineLevelItem{
			type_: .forced_break
			node: current
		}
	}
	if current.is_list_item_marker_box() {
		marker := current.as_list_item_marker_box() or { return none }
		if marker.list_style_position() != .inside {
			// An outside marker owns an independent inline formatting context and
			// does not participate in the list item's principal inline run.
		iterator.next_node = current.next_sibling()
		iterator.skip_to_next()
		return iterator.reserve_previous_generate_next_item()
	}
	}
	if !current.is_box() {
		iterator.skip_to_next()
		return iterator.reserve_previous_generate_next_item()
	}

	box := current.as_box() or { return none }
	if is_inline_flow_interrupting_block(current) && !current.is_list_item_marker_box() {
		iterator.skip_to_next()
		return InlineLevelItem{
			type_: .block_level_box
			node: current
		}
	}
	iterator.dimension_box_on_line(box)
	styled := current.as_node_with_style() or { return none }
	box_state := iterator.state.get(styled)
	mut item := InlineLevelItem{
		type_: .element
		node: current
		width: box_state.content_width()
		padding_start: box_state.padding_left
		padding_end: box_state.padding_right
		border_start: box_state.border_left
		border_end: box_state.border_right
		margin_start: box_state.margin_left
		margin_end: box_state.margin_right
	}
	iterator.add_extra_box_model_metrics_to_item(mut item, true, true)
	if current.is_list_item_marker_box() {
		// Treat an inside marker atomically in its list item's IFC; its own text
		// was already laid out by layout_list_item_marker().
		iterator.next_node = current.next_sibling()
	}
	iterator.skip_to_next()
	return item
}

fn (mut iterator InlineLevelIterator) reserve_previous_enter_text_node(text_node &TextNode) {
	computed := text_node.Node.computed_values()
	white_space_collapse := computed.white_space_collapse()
	should_wrap_lines := computed.text_wrap_mode() == .wrap
	should_respect_linebreaks := white_space_collapse in [.preserve, .preserve_breaks, .break_spaces]
	mut chunks := []TextNodeChunk{}
	font_generation := css.css_style_computer_for(text_node.Node.document()).font_computer().environment_generation()
	if cached := text_node.cached_inline_chunks_ {
		// The cached chunks are immutable after construction; sharing their
		// backing array avoids copying it for each intrinsic-sizing pass. A font
		// load replaces the cascade, so chunks retaining the previous platform
		// fonts must be shaped again.
		if text_node.cached_font_environment_generation_ == font_generation {
		chunks = unsafe { cached }
		}
	}
	if chunks.len == 0 {
		mut chunk_iterator := TextNodeChunkIterator.new_with_direction(text_node, should_wrap_lines,
			should_respect_linebreaks, if iterator.is_unidirectional_left_to_right {
				TextDirectionMode.unidirectional_left_to_right
			} else {
				TextDirectionMode.per_code_point
			})
		for {
			chunk := chunk_iterator.next() or { break }
			chunks << chunk
		}
		// InlineLevelIterator::generate_next_item() synthesizes one empty chunk for
		// mutable form-control editing text and generated empty strings. The V DOM
		// does not materialize the closed UA shadow root, so TreeBuilder records the
		// former on its equivalent internal TextNode.
		if chunks.len == 0 && text_node.text_for_rendering().len == 0
			&& (text_node.retains_empty_generated_fragment_
			|| text_node.produces_line_box_fragment_when_empty_) {
			chunks << chunk_iterator.create_empty_chunk()
		}
		mut mutable_text_node := unsafe { &TextNode(text_node) }
		mutable_text_node.cached_inline_chunks_ = chunks
		mutable_text_node.cached_font_environment_generation_ = css.css_style_computer_for(text_node.Node.document()).font_computer().environment_generation()
		mutable_text_node.cached_intrinsic_text_shapes_.clear()
	}
	iterator.has_text_node_context = true
	iterator.text_node_context = InlineTextNodeContext{
		chunks: chunks
		should_collapse_whitespace: white_space_collapse in [.collapse, .preserve_breaks]
		should_wrap_lines: should_wrap_lines
		should_respect_linebreaks: should_respect_linebreaks
	}
}
fn reserve_style(document &dom.Document, tag string, declarations string) &css.ComputedProperties {
 mut element := document.create_element_ns(dom.namespace_html_uri, tag) or { panic(err) }
 element.set_attribute_value('style', declarations)
 return css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
}

fn reserve_fixture(texts []string, declarations string) (&dom.Document, &BlockContainer) {
 document := dom.Document.create(dom.url_about_blank())
 style := reserve_style(document, 'div', 'display:block;font:16px SerenitySans;'+declarations)
 mut container := BlockContainer.new(document, none, style)
 container.set_children_are_inline(true)
 for text in texts {
  dom_text := document.create_text_node(text)
  node := TextNode.new(document, dom_text.as_node(), text)
  container.append_child(unsafe { &Node(node) })
 }
 return document, container
}

fn reserve_iterator(container &BlockContainer, baseline bool, mode LayoutMode) &InlineLevelIterator {
 assign_layout_indexes(unsafe { &Node(container) })
 mut state := LayoutState.new()
 style := unsafe { &Node(container) }.as_node_with_style() or { panic('style') }
 mut used := state.get_mutable(style)
 used.set_content_width(CSSPixels.new(350))
 used.set_content_height(CSSPixels.new(300))
 space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(350)), AvailableSize.make_definite(CSSPixels.new(300)))
 if baseline { return reserve_previous_iterator_new(mut state,container,used,mode,space,none) }
 return InlineLevelIterator.new(mut state,container,used,mode,space,none)
}

fn reserve_assert_same(actual &InlineLevelIterator, expected &InlineLevelIterator) {
 assert actual.items.len == expected.items.len
 assert actual.items.cap >= actual.items.len
 assert actual.accumulated_width_for_tabs == expected.accumulated_width_for_tabs
 for index,a in actual.items {
  b := expected.items[index]
  assert a.type_ == b.type_
  assert a.offset_in_node == b.offset_in_node
  assert a.length_in_node == b.length_in_node
  assert a.is_collapsible_whitespace == b.is_collapsible_whitespace
  assert a.is_all_whitespace == b.is_all_whitespace
  assert a.can_break_before == b.can_break_before
  assert a.trailing_whitespace == b.trailing_whitespace
  assert a.preceded_by_unattached_inline_start_edges == b.preceded_by_unattached_inline_start_edges
  assert a.width == b.width
  assert a.padding_start == b.padding_start && a.padding_end == b.padding_end
  assert a.border_start == b.border_start && a.border_end == b.border_end
  assert a.margin_start == b.margin_start && a.margin_end == b.margin_end
  if n := a.node { other := b.node or { panic('node') }; assert voidptr(n)==voidptr(other) } else { assert b.node==none }
  if run := a.glyph_run {
   other := b.glyph_run or { panic('glyph') }
   assert run.glyphs_ == other.glyphs_
   assert run.width() == other.width()
   assert run.text_type() == other.text_type()
   assert voidptr(run.font()) == voidptr(other.font())
  } else { assert b.glyph_run==none }
 }
}

fn test_inline_item_reserve_matches_complete_previous_generation_for_cold_and_cached_chunks() {
 for declaration in ['white-space-collapse:collapse', 'white-space-collapse:preserve', 'white-space-collapse:preserve-breaks', 'white-space-collapse:break-spaces', 'text-wrap-mode:nowrap'] {
  for texts in [ ['one   two','three four'], ['  ',''], ['a\tb\nc\r\nd','tail'], ['Русский текст, ещё слова!','сравнение'], ['á emoji 👩‍👩‍👧‍👦','עברית English العربية'] ] {
   _,container := reserve_fixture(texts,declaration)
   for mode in [LayoutMode.normal,.intrinsic_sizing] {
    expected := reserve_iterator(container,true,mode)
    actual := reserve_iterator(container,false,mode)
    reserve_assert_same(actual,expected)
    gc_collect()
    reserve_assert_same(actual,expected)
   }
  }
 }
}

fn test_many_small_text_nodes_keep_inline_item_allocation_linear() {
 mut items := []InlineLevelItem{}
 mut total_capacity := 0
 mut growths := 0
 for node in 0 .. 1024 {
  previous := items.data
  reserve_inline_item_capacity(mut items, 3)
  if items.data != previous { total_capacity += items.cap; growths++ }
  for chunk in 0 .. 3 { items << InlineLevelItem{offset_in_node: node, length_in_node: chunk} }
 }
 assert growths < 20
 assert total_capacity < items.len * 4
 for index, item in items {
  assert item.offset_in_node == index / 3
  assert item.length_in_node == index % 3
 }
}

fn test_inline_item_reserve_keeps_empty_editable_and_generated_chunks() {
 for generated in [false,true] {
  _,mut container := reserve_fixture([''],'white-space-collapse:preserve')
  child := unsafe { &Node(container) }.first_child() or { panic('child') }
  mut text := child.as_text_node() or { panic('text') }
  text.produces_line_box_fragment_when_empty_ = !generated
  text.retains_empty_generated_fragment_ = generated
  actual := reserve_iterator(container,false,.normal)
  expected := reserve_iterator(container,true,.normal)
  reserve_assert_same(actual,expected)
  assert actual.items.len==1 && actual.items[0].length_in_node==0
 }
}

fn test_inline_item_reserve_preserves_nested_edges_breaks_and_out_of_flow_items() {
 document,mut container := reserve_fixture(['before '],'white-space-collapse:preserve')
 mut inline_node := InlineNode.new(document,none,reserve_style(document,'span','display:inline;padding:2px 3px;border:1px solid;margin:4px'))
 text := document.create_text_node('many words in inline node')
 inline_node.append_child(unsafe { &Node(TextNode.new(document,text.as_node(),'many words in inline node')) })
 container.append_child(unsafe { &Node(inline_node) })
 mut br := document.create_element_ns(dom.namespace_html_uri,'br') or { panic(err) }
 container.append_child(unsafe { &Node(BreakNode.new(document,br.as_node(),reserve_style(document,'br','display:inline'))) })
 absolute := BlockContainer.new(document,none,reserve_style(document,'span','display:block;position:absolute;width:8px;height:9px'))
 container.append_child(unsafe { &Node(absolute) })
 tail := document.create_text_node('after break')
 container.append_child(unsafe { &Node(TextNode.new(document,tail.as_node(),'after break')) })
 actual := reserve_iterator(container,false,.normal)
 expected := reserve_iterator(container,true,.normal)
 reserve_assert_same(actual,expected)
 mut breaks:=0
 mut out_of_flow:=0
 for item in actual.items {
  if item.type_==.forced_break { breaks++ }
  if item.type_==.absolutely_positioned_element { out_of_flow++ }
 }
 assert breaks==1 && out_of_flow==1
}

fn test_inline_item_reserve_retains_prior_items_and_glyph_owners_after_later_generation() {
 _,container := reserve_fixture(['a b c d e f g h i j',' second text node has more words'],'')
 retained := reserve_iterator(container,false,.intrinsic_sizing)
 before := retained.items.clone()
 first := before[0].glyph_run or { panic('glyph') }
 glyphs := first.glyphs_.clone()
 for _ in 0..8 { _ = reserve_iterator(container,false,.normal) }
 gc_collect()
 assert retained.items.len==before.len
 assert first.glyphs_==glyphs
 for index,item in retained.items { assert item.offset_in_node==before[index].offset_in_node && item.width==before[index].width }
 expected := reserve_iterator(container,true,.normal)
 reserve_assert_same(retained,expected)
}
