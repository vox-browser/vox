module intersectionobserver

import dom
import geometry

fn test_entry_constructs_read_only_rectangles_and_exposes_idl_attributes() {
	target := &dom.Element{}
	entry := IntersectionObserverEntry.construct_impl(IntersectionObserverEntryInit{
		time: 12.5
		root_bounds: geometry.DOMRectInit{1, 2, 300, 200}
		bounding_client_rect: geometry.DOMRectInit{3, 4, 50, 60}
		intersection_rect: geometry.DOMRectInit{5, 6, 20, 30}
		is_intersecting: true
		intersection_ratio: 0.4
		target: target
	}) or { panic(err) }
	assert entry.time() == 12.5
	root := entry.root_bounds() or { panic('root bounds should be present') }
	assert root.x() == 1
	assert root.height() == 200
	assert entry.bounding_client_rect().width() == 50
	assert entry.intersection_rect().height() == 30
	assert entry.is_intersecting()
	assert entry.intersection_ratio() == 0.4
	assert entry.target() == target
}

fn test_entry_allows_null_root_bounds_but_requires_target() {
	target := &dom.Element{}
	entry := IntersectionObserverEntry.construct(IntersectionObserverEntryInit{
		target: target
	}) or { panic(err) }
	assert entry.root_bounds() == none
	if _ := IntersectionObserverEntry.construct(IntersectionObserverEntryInit{}) {
		assert false
	} else {
		assert err.msg().contains('target is required')
	}
}

fn test_entry_factory_and_binding_offsets() {
	target := &dom.Element{}
	bounding := geometry.DOMRectReadOnly.from_rect(geometry.DOMRectInit{1, 2, 3, 4})
	intersection := geometry.DOMRectReadOnly.from_rect(geometry.DOMRectInit{2, 3, 1, 1})
	entry := IntersectionObserverEntry.create(7, none, bounding, intersection, true, 0.25, target)
	assert entry.target() == target
	assert entry.time() == 7
	assert IntersectionObserverEntry.root_bounds_offset() > 0
	assert IntersectionObserverEntry.bounding_client_rect_offset() > 0
	assert IntersectionObserverEntry.intersection_rect_offset() > 0
	assert IntersectionObserverEntry.target_offset() > 0
}
