module layout

import css
import dom
import platform

fn spacing_context_style(document &dom.Document, declarations string) &css.ComputedProperties {
 mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic(err) }
 element.set_attribute_value('style', declarations)
 return css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
}

fn spacing_context_container(document &dom.Document, texts []string, declarations []string) (&BlockContainer, []&TextNode) {
 style := spacing_context_style(document, 'display:block;font:18px/22px SerenitySans')
 mut container := BlockContainer.new(document, none, style)
 container.set_children_are_inline(true)
 mut nodes := []&TextNode{}
 for index, text in texts {
  inline_style := spacing_context_style(document, 'display:inline;font:18px/22px SerenitySans;${declarations[index]}')
  mut inline_node := InlineNode.new(document, none, inline_style)
  node := TextNode.new(document, document.create_text_node(text).as_node(), text)
  inline_node.append_child(unsafe { &Node(node) })
  container.append_child(unsafe { &Node(inline_node) })
  nodes << node
 }
 return container, nodes
}

fn spacing_context_items(container &BlockContainer) []InlineLevelItem {
 assign_layout_indexes(unsafe { &Node(container) })
 mut state := LayoutState.new()
 mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
 used.set_content_width(CSSPixels.new(800))
 iterator := InlineLevelIterator.new(mut state, container, used, .normal,
  AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(800)), AvailableSize.make_indefinite()), none)
 return iterator.items()
}

fn spacing_context_check_oracle(items []InlineLevelItem) int {
 mut count := 0
 for item in items {
  if item.type_ != .text { continue }
  node := item.node or { panic('text node') }
  text_node := node.as_text_node() or { panic('text') }
  value := utf16_substring_for_line_box(text_node.text_for_rendering(), item.offset_in_node, item.length_in_node)
  actual := item.glyph_run or { panic('glyph run') }
  letter := resolved_text_spacing_for_node(node, .letter_spacing)
  word := resolved_text_spacing_for_node(node, .word_spacing)
  expected := platform.shape_text_with_spacing(0, f32(letter.to_double()), f32(word.to_double()), value, actual.font(), actual.text_type())
  assert actual.glyphs() == expected.glyph_run.glyphs()
  assert actual.glyph_indices() == expected.glyph_run.glyph_indices()
  assert actual.glyph_positions() == expected.glyph_run.glyph_positions()
  assert actual.width() == expected.glyph_run.width()
  assert actual.space_width == expected.glyph_run.space_width
  assert item.width == CSSPixels.nearest_value_for(f64(expected.glyph_run.width()))
  count++
 }
 return count
}

fn test_inline_spacing_context_matches_fresh_shaping_for_every_chunk_and_node() {
 document := dom.Document.create(dom.url_about_blank())
 declarations := [
  'letter-spacing:normal;word-spacing:normal',
  'letter-spacing:1.25px;word-spacing:2.5px',
  'letter-spacing:-0.5px;word-spacing:-1px',
  'letter-spacing:0.2em;word-spacing:0.3ch',
 ]
 text := 'alpha beta gamma delta 😀 你好 אבג á end'
 container, nodes := spacing_context_container(document, [text, text, text, text], declarations)
 items := spacing_context_items(container)
 assert spacing_context_check_oracle(items) > 40
 for node in nodes {
  assert items.filter(it.type_ == .text && voidptr(it.node or { panic('node') }) == voidptr(node)).len > 10
 }
 // Distinct per-node styles must never share a previous node's spacing.
 first := resolved_text_spacing_for_node(unsafe { &Node(nodes[0]) }, .letter_spacing)
 second := resolved_text_spacing_for_node(unsafe { &Node(nodes[1]) }, .letter_spacing)
 assert first.raw_value() == 0
 assert second.to_double() == 1.25
}

fn test_inline_spacing_context_preserves_tab_stops_across_forced_breaks() {
 document := dom.Document.create(dom.url_about_blank())
 container, nodes := spacing_context_container(document, ['a\tb\n\tc\t'], [
  'font:20px/24px SerenityMono;letter-spacing:2px;word-spacing:6px;tab-size:2;white-space-collapse:preserve',
 ])
 items := spacing_context_items(container)
 assert items.len == 7
 assert items[3].type_ == .forced_break
 font := nodes[0].font_for_rendering()
 tab_width := 2 * (f64(font.glyph_width(u32(` `))) + 6 + 2)
 a := platform.shape_text_with_spacing(0, 2, 6, 'a', font, .ltr)
 c := platform.shape_text_with_spacing(0, 2, 6, 'c', font, .ltr)
 assert f64(a.glyph_run.width()) < tab_width
 assert f64(c.glyph_run.width()) < tab_width
 assert items[1].width == CSSPixels.nearest_value_for(tab_width - items[0].width.to_double())
 assert items[4].width == CSSPixels.nearest_value_for(tab_width)
 assert items[6].width == CSSPixels.nearest_value_for(tab_width - items[5].width.to_double())
 assert items[0].width == CSSPixels.nearest_value_for(f64(a.glyph_run.width()))
 assert items[5].width == CSSPixels.nearest_value_for(f64(c.glyph_run.width()))
}

fn test_inline_spacing_context_refreshes_for_later_iterators_after_style_change() {
 document := dom.Document.create(dom.url_about_blank())
 container, nodes := spacing_context_container(document, ['one two three four'], ['letter-spacing:1px;word-spacing:2px'])
 first := spacing_context_items(container)
 assert spacing_context_check_oracle(first) == 7
 parent := nodes[0].Node.parent() or { panic('parent') }
 mut styled := parent.as_node_with_style() or { panic('style') }
 replacement := spacing_context_style(document, 'display:inline;font:30px/36px SerenitySans;letter-spacing:0.25em;word-spacing:0.5ch')
 styled.set_computed_values(replacement)
 mut text_node := nodes[0]
 text_node.invalidate_text_for_rendering()
 second := spacing_context_items(container)
 assert spacing_context_check_oracle(second) == 7
 assert first[0].width != second[0].width
 assert resolved_text_spacing_for_node(unsafe { &Node(nodes[0]) }, .letter_spacing).to_double() == 7.5
 gc_collect()
 assert first[0].width.to_double() > 0
}
