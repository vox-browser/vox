module layout

import css
import dom
import platform

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

fn lazy_invisible_font_test_text() &TextNode {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('style', 'font-family:SerenitySans;font-size:16.5px')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	parent := BlockContainer.new(document, none, style)
	text := TextNode.new(document, document.create_text_node('Hello Wikipedia').as_node(), 'Hello Wikipedia')
	mut parent_node := unsafe { &Node(parent) }
	parent_node.append_child(unsafe { &Node(text) })
	return text
}

fn test_visible_text_and_absent_invisible_cache_reads_keep_storage_absent() {
	text := lazy_invisible_font_test_text()
	mut iterator := TextNodeChunkIterator.new(text, true, false)
	selected := iterator.font_for_code_point(u32(`H`))
	assert !selected.is_invisible
	assert iterator.selected_font_storage_ == unsafe { nil }
	key := 'unseen|font|key'
	mut misses := 0
	mut before := uint(0)
	$if gcboehm ? {
		before = C.GC_get_total_bytes()
	}
	for _ in 0 .. 1024 {
		if iterator.cached_invisible_font(key) == none { misses++ }
	}
	mut allocated := uint(0)
	$if gcboehm ? {
		allocated = C.GC_get_total_bytes() - before
	}
	assert misses == 1024
	assert allocated == 0
	assert iterator.selected_font_storage_ == unsafe { nil }
	second := TextNodeChunkIterator.new(text, false, false)
	assert second.selected_font_storage_ == unsafe { nil }
}

fn test_invisible_cache_is_independent_and_preserves_keys_identity_and_retention() {
	text := lazy_invisible_font_test_text()
	mut iterator := TextNodeChunkIterator.new(text, true, false)
	selected := &platform.Font{ family: 'SerenitySans', point_size: 16.5 }
	first := iterator.invisible_font_for(selected)
	assert first.is_invisible
	assert !selected.is_invisible
	assert first.point_size == selected.point_size
	assert iterator.selected_font_storage_.values.len == 1
	matching := &platform.Font{ family: 'SerenitySans', point_size: 16.5 }
	assert voidptr(iterator.invisible_font_for(matching)) == voidptr(first)
	assert iterator.cached_invisible_font('missing-in-populated-map') == none
	larger := iterator.invisible_font_for(&platform.Font{ family: 'SerenitySans', point_size: 24 })
	bold := iterator.invisible_font_for(&platform.Font{ family: 'SerenitySans', point_size: 16.5, weight: 700 })
	assert voidptr(larger) != voidptr(first)
	assert voidptr(bold) != voidptr(first)
	assert iterator.selected_font_storage_.values.len == 3
	mut other := TextNodeChunkIterator.new(text, true, false)
	assert other.selected_font_storage_ == unsafe { nil }
	other_first := other.invisible_font_for(selected)
	assert voidptr(other.selected_font_storage_) != voidptr(iterator.selected_font_storage_)
	assert voidptr(other_first) != voidptr(first)
	gc_collect()
	assert voidptr(iterator.invisible_font_for(matching)) == voidptr(first)
	assert first.family == 'SerenitySans'
	assert first.point_size == 16.5
	assert larger.point_size == 24
	assert bold.weight == 700
	assert other.selected_font_storage_.values.len == 1
}

fn test_cascade_reinstallation_retains_invisible_cache_and_old_font_snapshots() {
	text := lazy_invisible_font_test_text()
	mut iterator := TextNodeChunkIterator.new(text, true, false)
	first_selected := iterator.font_cascade_fonts[0]
	first := iterator.invisible_font_for(first_selected)
	storage := iterator.selected_font_storage_
	iterator.install_font_cascade(text.font_list())
	assert voidptr(iterator.selected_font_storage_) == voidptr(storage)
	assert voidptr(iterator.invisible_font_for(iterator.font_cascade_fonts[0])) == voidptr(first)
	mut replacement_cascade := css.FontCascadeList.create()
	replacement_cascade.add(css.PlatformFont{
		typeface:   &css.PlatformTypeface{ family_name: 'SerenitySans' }
		point_size: 18
	}, [])
	iterator.install_font_cascade(replacement_cascade)
	replacement := iterator.invisible_font_for(iterator.font_cascade_fonts[0])
	assert voidptr(iterator.selected_font_storage_) == voidptr(storage)
	assert voidptr(replacement) != voidptr(first)
	assert replacement.point_size == 24
	assert first.point_size == first_selected.point_size
	assert iterator.selected_font_storage_.values.len == 2
	gc_collect()
	assert first.is_invisible
	assert replacement.is_invisible
	assert !first_selected.is_invisible
	assert first.point_size == 16.5
}
