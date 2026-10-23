module layout

import css
import dom
import html
import platform

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn svg_cache_test_path(root &Node) &Node {
	if node := root.dom_node() {
		if element := node.as_element() {
			if element.local_name() == 'path' { return root }
		}
	}
	for child in root.children() {
		if found := svg_cache_test_find_path(child) { return found }
	}
	panic('missing SVG path')
}

fn svg_cache_test_find_path(root &Node) ?&Node {
	if node := root.dom_node() {
		if element := node.as_element() {
			if element.local_name() == 'path' { return root }
		}
	}
	for child in root.children() {
		if found := svg_cache_test_find_path(child) { return found }
	}
	return none
}

fn test_svg_path_geometry_is_shared_across_probes_and_retained_after_collection() {
	document := html.parse_document('<!doctype html><svg><path d="M 5 6 C 15 6 25 26 45 26 L 5 26 Z"/></svg>')
	root := build_layout_tree(document) or { panic('missing layout tree') }
	path_node := svg_cache_test_path(root)
	first := cached_svg_path_geometry(path_node)
	for _ in 0 .. 3 {
		$if gcboehm ? {
			C.GC_gcollect()
		}
		reused := cached_svg_path_geometry(path_node)
		assert voidptr(first) == voidptr(reused)
		assert reused.path.instructions.len == 4
		assert reused.bounds.x == 5
		assert reused.bounds.y == 6
		assert reused.bounds.width == 40
		assert reused.bounds.height == 20
	}
}

fn test_svg_path_geometry_cache_follows_applied_css_and_keeps_old_results_alive() {
	document := html.parse_document('<!doctype html><svg><path d="M 1 2 L 11 12"/></svg>')
	root := build_layout_tree(document) or { panic('missing layout tree') }
	path_node := svg_cache_test_path(root)
	first := cached_svg_path_geometry(path_node)
	mut style := css.ComputedProperties.new()
	style.set_property_without_modifying_flags(.d, &dom.StyleValue{ css_text: 'path("M 20 30 L 50 60")' })
	mut styled := unsafe { &NodeWithStyle(path_node) }
	styled.apply_style(style)
	updated := cached_svg_path_geometry(path_node)
	assert voidptr(first) != voidptr(updated)
	assert updated.path.serialize() == 'M 20 30 L 50 60'
	assert first.path.serialize() == 'M 1 2 L 11 12'
	style.set_property_without_modifying_flags(.d, &dom.StyleValue{ css_text: 'none' })
	styled.apply_style(style)
	empty := cached_svg_path_geometry(path_node)
	assert empty.path.instructions.len == 0
	assert empty.bounds.width == 0
	assert voidptr(empty) == voidptr(cached_svg_path_geometry(path_node))
}

fn test_svg_path_geometry_cache_survives_probe_workspace_retirement() {
	mut owner := platform.new_retained_arena('SVG path cache document')
	mut document_scope := owner.enter()
	document := html.parse_document('<!doctype html><svg><path d="M 1 2 L 11 12"/></svg>')
	root := build_layout_tree(document) or { panic('missing layout tree') }
	path_node := svg_cache_test_path(root)
	mut scratch := platform.new_arena('SVG path cache probe')
	entry := scratch.enter()
	first := cached_svg_path_geometry(path_node)
	$if prealloc {
		assert owner.arena.contains(first)
		assert owner.arena.contains(first.instructions.str)
		assert owner.arena.contains(first.path.instructions.data)
	}
	scratch.leave(entry)
	scratch.reset()
	assert voidptr(first) == voidptr(cached_svg_path_geometry(path_node))
	assert first.path.serialize() == 'M 1 2 L 11 12'
	mut style := css.ComputedProperties.new()
	style.set_property_without_modifying_flags(.d, &dom.StyleValue{ css_text: 'path("M 20 30 L 50 60")' })
	mut styled := unsafe { &NodeWithStyle(path_node) }
	styled.apply_style(style)
	changed_entry := scratch.enter()
	changed := cached_svg_path_geometry(path_node)
	$if prealloc {
		assert owner.arena.contains(changed)
		assert owner.arena.contains(changed.instructions.str)
		assert owner.arena.contains(changed.path.instructions.data)
	}
	scratch.leave(changed_entry)
	scratch.release()
	assert voidptr(first) != voidptr(changed)
	assert voidptr(changed) == voidptr(cached_svg_path_geometry(path_node))
	assert changed.path.serialize() == 'M 20 30 L 50 60'
	assert first.path.serialize() == 'M 1 2 L 11 12'
	document_scope.finish()
	owner.release()
}
