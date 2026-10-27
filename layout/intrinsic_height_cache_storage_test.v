module layout

import css
import dom
import html as html_parser

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

fn intrinsic_height_test_box() &Box {
	document := dom.Document.create(dom.url_about_blank())
	return Box.new(document, none, css.ComputedProperties.new())
}

fn test_intrinsic_width_cache_keeps_both_height_axes_absent_without_allocating_reads() {
	mut box := intrinsic_height_test_box()
	mut cache := box.cached_intrinsic_sizes()
	cache.min_content_width = CSSPixels.new(0)
	cache.max_content_width = CSSPixels.new(128)
	assert cache.min_content_height_ == unsafe { nil }
	assert cache.max_content_height_ == unsafe { nil }
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	mut misses := 0
	for _ in 0 .. 1024 {
		if !cache.has_cached_content_height(true, 0) { misses++ }
		if cache.cached_content_height(true, 0) == none { misses++ }
		if !cache.has_cached_content_height(false, -7) { misses++ }
		if cache.cached_content_height(false, -7) == none { misses++ }
	}
	mut allocated := uint(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert misses == 4096
	assert allocated == 0
	assert cache.min_content_height_ == unsafe { nil }
	assert cache.max_content_height_ == unsafe { nil }
	assert (cache.min_content_width or { panic('missing min width') }).raw_value() == 0
	assert (cache.max_content_width or { panic('missing max width') }).to_double() == 128
}

fn test_intrinsic_first_height_slot_preserves_none_zero_and_independent_axes() {
	mut box := intrinsic_height_test_box()
	mut cache := box.cached_intrinsic_sizes()
	cache.cache_content_height(true, 0, none)
	assert cache.has_cached_content_height(true, 0)
	assert cache.cached_content_height(true, 0) == none
	assert !cache.has_cached_content_height(true, 7)
	assert cache.cached_content_height(true, 7) == none
	first := voidptr(cache.min_content_height_)
	assert first != unsafe { nil }
	assert cache.min_content_height_.overflow == unsafe { nil }
	assert cache.max_content_height_ == unsafe { nil }
	cache.cache_content_height(true, 0, CSSPixels.new(0))
	cache.cache_content_height(false, -31, CSSPixels.new(19))
	gc_collect()
	assert voidptr(cache.min_content_height_) == first
	assert voidptr(cache.max_content_height_) != first
	assert cache.min_content_height_.overflow == unsafe { nil }
	assert cache.max_content_height_.overflow == unsafe { nil }
	assert (cache.cached_content_height(true, 0) or { panic('zero was lost') }).raw_value() == 0
	assert (cache.cached_content_height(false, -31) or { panic('max height missing') }).to_double() == 19
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	for _ in 0 .. 1024 { cache.cache_content_height(true, 0, CSSPixels.new(0)) }
	mut allocated := uint(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert allocated == 0
	assert voidptr(cache.min_content_height_) == first
	assert cache.min_content_height_.overflow == unsafe { nil }
}

fn test_intrinsic_height_overflow_preserves_distinct_widths_optional_values_and_first_identity() {
	mut box := intrinsic_height_test_box()
	mut cache := box.cached_intrinsic_sizes()
	cache.cache_content_height(false, -8, CSSPixels.new(12))
	first := voidptr(cache.max_content_height_)
	cache.cache_content_height(false, 0, none)
	overflow := voidptr(cache.max_content_height_.overflow)
	assert overflow != unsafe { nil }
	cache.cache_content_height(false, 9, CSSPixels.new(0))
	assert cache.max_content_height_.overflow.values.len == 2
	assert cache.has_cached_content_height(false, -8)
	assert cache.has_cached_content_height(false, 0)
	assert cache.has_cached_content_height(false, 9)
	assert !cache.has_cached_content_height(false, 10)
	assert cache.cached_content_height(false, 0) == none
	assert cache.cached_content_height(false, 10) == none
	assert (cache.cached_content_height(false, 9) or { panic('overflow zero missing') }).raw_value() == 0
	cache.cache_content_height(false, -8, none)
	cache.cache_content_height(false, 0, CSSPixels.new(21))
	gc_collect()
	assert voidptr(cache.max_content_height_) == first
	assert voidptr(cache.max_content_height_.overflow) == overflow
	assert cache.max_content_height_.overflow.values.len == 2
	assert cache.has_cached_content_height(false, -8)
	assert cache.cached_content_height(false, -8) == none
	assert (cache.cached_content_height(false, 0) or { panic('overflow replacement lost') }).to_double() == 21
	assert cache.min_content_height_ == unsafe { nil }
}

fn test_intrinsic_height_reset_replaces_owner_and_keeps_retained_old_snapshot_after_gc() {
	mut box := intrinsic_height_test_box()
	mut other := intrinsic_height_test_box()
	mut old := box.cached_intrinsic_sizes()
	old.min_content_width = CSSPixels.new(16)
	old.cache_content_height(true, 10, CSSPixels.new(25))
	old.cache_content_height(true, 20, none)
	other_cache := other.cached_intrinsic_sizes()
	assert voidptr(old) != voidptr(other_cache)
	box.reset_cached_intrinsic_sizes()
	mut fresh := box.cached_intrinsic_sizes()
	assert voidptr(fresh) != voidptr(old)
	assert fresh.min_content_width == none
	assert fresh.min_content_height_ == unsafe { nil }
	assert fresh.max_content_height_ == unsafe { nil }
	fresh.cache_content_height(true, 10, CSSPixels.new(37))
	gc_collect()
	assert (old.min_content_width or { panic('old width missing') }).to_double() == 16
	assert (old.cached_content_height(true, 10) or { panic('old height missing') }).to_double() == 25
	assert old.has_cached_content_height(true, 20)
	assert old.cached_content_height(true, 20) == none
	assert (fresh.cached_content_height(true, 10) or { panic('fresh height missing') }).to_double() == 37
	assert other_cache.min_content_height_ == unsafe { nil }
	assert other_cache.max_content_height_ == unsafe { nil }
}

fn intrinsic_height_find_box(root &Node, id string) ?&Box {
	if source := root.dom_node() {
		if element := source.as_element() {
			if element.get_attribute_value('id') == id { return root.as_box() }
		}
	}
	for child in root.children() {
		if found := intrinsic_height_find_box(child, id) { return found }
	}
	return none
}

fn test_intrinsic_height_measurement_uses_cached_zero_and_recomputes_stored_none() {
	document := html_parser.parse_document('<!doctype html><style>body{margin:0}#outer{width:120px}#child{height:37px}</style><div id="outer"><div id="child"></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	mut box := intrinsic_height_find_box(result.root, 'outer') or { panic('missing outer box') }
	assert unsafe { &Node(box) }.has_children()
	box.reset_cached_intrinsic_sizes()
	mut state := result.state
	width := CSSPixels.new(120)
	assert calculate_max_content_height(mut state, box, width).to_double() == 37
	mut cache := box.cached_intrinsic_sizes()
	assert cache.min_content_height_ == unsafe { nil }
	assert cache.max_content_height_ != unsafe { nil }
	assert cache.max_content_height_.overflow == unsafe { nil }
	cache.cache_content_height(false, width.raw_value(), CSSPixels.new(0))
	assert calculate_max_content_height(mut state, box, width).raw_value() == 0
	cache.cache_content_height(false, width.raw_value(), none)
	assert cache.has_cached_content_height(false, width.raw_value())
	assert calculate_max_content_height(mut state, box, width).to_double() == 37
	assert cache.max_content_height_.overflow == unsafe { nil }
	assert (cache.cached_content_height(false, width.raw_value()) or { panic('recomputed height missing') }).to_double() == 37
}
