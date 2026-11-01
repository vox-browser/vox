module layout

import css
import dom
import platform

fn shape_order_expected_positions(node &TextNode, text string) []int {
	mut expected := []int{}
	for index, cached in node.cached_intrinsic_text_shapes_ {
		if cached.text == text { expected << index }
	}
	return expected
}

fn shape_order_actual_positions(node &TextNode, text string) []int {
	start, end := intrinsic_shape_cache_range(node, text)
	mut actual := []int{}
	for position := start; position < end; position++ {
		index := intrinsic_shape_cache_entry_index(node, position)
		if node.cached_intrinsic_text_shapes_[index].text == text { actual << index }
	}
	return actual
}

fn test_intrinsic_shape_order_matches_linear_search_and_keeps_equal_keys_stable() {
	mut node := &TextNode{}
	keys := ['', ' ', 'alpha', 'zeta', 'אבג', '😀', 'á', 'alpha suffix']
	for count in 0 .. 97 {
		for key in keys {
			assert shape_order_actual_positions(node, key) == shape_order_expected_positions(node, key)
		}
		assert shape_order_actual_positions(node, 'missing') == []int{}
		assert (node.cached_intrinsic_shape_order_ == unsafe { nil }) == (count < 16)
		key := keys[(count * 5 + 3) % keys.len]
		node.cached_intrinsic_text_shapes_ << IntrinsicTextShapeCacheEntry{text: key, initial_x: f32(count)}
		append_intrinsic_shape_cache_order(mut node)
		assert node.cached_intrinsic_text_shapes_.last().initial_x == f32(count)
		for index, entry in node.cached_intrinsic_text_shapes_ { assert entry.initial_x == f32(index) }
	}
}

fn test_intrinsic_shape_order_handles_clearing_and_rebuilding_the_same_size() {
	mut node := &TextNode{}
	for cycle in 0 .. 4 {
		node.cached_intrinsic_text_shapes_.clear()
		for index in 0 .. 48 {
			key := '${cycle}:${47 - index}'
			assert shape_order_actual_positions(node, key) == []int{}
			node.cached_intrinsic_text_shapes_ << IntrinsicTextShapeCacheEntry{text: key}
			append_intrinsic_shape_cache_order(mut node)
			assert shape_order_actual_positions(node, key) == [index]
		}
		for index in 0 .. 48 {
			assert shape_order_actual_positions(node, '${cycle}:${47 - index}') == [index]
		}
		assert shape_order_actual_positions(node, '${cycle - 1}:0') == []int{}
		node.cached_intrinsic_text_shapes_ << IntrinsicTextShapeCacheEntry{text: 'uncatalogued'}
		assert shape_order_actual_positions(node, 'uncatalogued') == [48]
		assert node.cached_intrinsic_shape_order_ == unsafe { nil }
	}
}

fn shape_order_node() &TextNode {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('div') }
	element.set_attribute_value('style', 'display:block;font:16px/20px SerenitySans;width:180px')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	mut container := BlockContainer.new(document, none, style)
	text := document.create_text_node('cache owner')
	mut node := TextNode.new(document, text.as_node(), 'cache owner')
	container.append_child(unsafe { &Node(node) })
	return node
}

fn shape_order_fingerprint(run &platform.GlyphRun) string {
	// The run retains this exact font. Formatting Font recursively serializes
	// its decoded TTF caches on every comparison and exhausts no-GC test memory.
	return '${u64(voidptr(run.font()))} ${run.text_type()} ${run.face()} ${run.width()} ${run.space_width} ${run.glyphs()} ${run.glyph_indices()} ${run.glyph_positions()} ${run.bounding_box()}'
}

fn test_intrinsic_shape_order_preserves_every_shape_key_and_forks_owners() {
	mut node := shape_order_node()
	font := node.font_for_rendering()
	intrinsic := &InlineLevelIterator{layout_mode: .intrinsic_sizing}
	normal := &InlineLevelIterator{layout_mode: .normal}
	mut owners := []&platform.GlyphRun{}
	mut expected := []string{}
	for index in 0 .. 24 {
		text := if index % 3 == 0 { 'אבג ${index} ' } else { 'word${index} 😀 á ' }
		for variation in 0 .. 4 {
			x := f32(variation)
			letter := f32(variation % 2) * 1.25
			word := f32(variation / 2) * 2
			direction := if variation % 2 == 0 { platform.GlyphRunTextType.ltr } else { platform.GlyphRunTextType.rtl }
			shaped := intrinsic.shape_text_for_layout(node, x, letter, word, text, font, direction)
			oracle := platform.shape_text_with_spacing(x, letter, word, text, font, direction)
			fingerprint := shape_order_fingerprint(oracle.glyph_run)
			assert shape_order_fingerprint(shaped.glyph_run) == fingerprint
			assert shaped.trailing_whitespace == oracle.trailing_whitespace
			cached := node.cached_intrinsic_text_shapes_.last().glyph_run
			assert voidptr(cached) != voidptr(shaped.glyph_run)
			owners << cached
			expected << fingerprint
			mut consumer := shaped.glyph_run
			consumer.invalidate_replay_data()
			consumer.glyphs_[0].position.x += 9
			consumer.refresh_replay_data()
			assert shape_order_fingerprint(cached) == fingerprint
			hit := normal.shape_text_for_layout(node, x, letter, word, text, font, direction)
			assert shape_order_fingerprint(hit.glyph_run) == fingerprint
			assert hit.trailing_whitespace == oracle.trailing_whitespace
			assert voidptr(hit.glyph_run) != voidptr(cached)
		}
	}
	assert node.cached_intrinsic_text_shapes_.len == 96
	assert node.cached_intrinsic_shape_order_ != unsafe { nil }
	node.invalidate_text_for_rendering()
	assert node.cached_intrinsic_text_shapes_.len == 0
	assert shape_order_actual_positions(node, 'word1 😀 á ') == []int{}
	assert node.cached_intrinsic_shape_order_ == unsafe { nil }
	gc_collect()
	for index, owner in owners { assert shape_order_fingerprint(owner) == expected[index] }
}

fn test_intrinsic_shape_order_normal_misses_do_not_populate_cache() {
	node := shape_order_node()
	font := node.font_for_rendering()
	normal := &InlineLevelIterator{layout_mode: .normal}
	for index in 0 .. 24 {
		text := 'fresh${index} '
		shaped := normal.shape_text_for_layout(node, 0, 0, 0, text, font, .ltr)
		oracle := platform.shape_text_with_spacing(0, 0, 0, text, font, .ltr)
		assert shape_order_fingerprint(shaped.glyph_run) == shape_order_fingerprint(oracle.glyph_run)
		assert shaped.trailing_whitespace == oracle.trailing_whitespace
	}
	assert node.cached_intrinsic_text_shapes_.len == 0
	assert node.cached_intrinsic_shape_order_ == unsafe { nil }
}
