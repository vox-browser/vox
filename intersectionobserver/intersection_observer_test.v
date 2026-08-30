module intersectionobserver

import dom
import geometry
import math

fn discard_entries(_ []&IntersectionObserverEntry, _ &IntersectionObserver) {}

fn default_observer() &IntersectionObserver {
	return IntersectionObserver.construct(discard_entries, IntersectionObserverInit{}) or {
		panic(err)
	}
}

fn test_margin_parser_expands_css_shorthand_and_serializes_resolved_lengths() {
	empty := IntersectionObserver.parse_a_margin('') or { panic('empty margin must parse') }
	assert empty.len == 4
	assert empty.map(it.serialize()) == ['0px', '0px', '0px', '0px']

	two := parse_a_margin('10px 25%') or { panic('two-value margin must parse') }
	assert two.map(it.serialize()) == ['10px', '25%', '10px', '25%']
	three := parse_a_margin('-1px 2px 3px') or { panic('three-value margin must parse') }
	assert three.map(it.serialize()) == ['-1px', '2px', '3px', '2px']
	absolute := parse_a_margin('2.54cm') or { panic('absolute units must parse') }
	assert math.abs(absolute[0].value - 96.0) < 0.000001
}

fn test_margin_parser_rejects_unsupported_syntax() {
	assert parse_a_margin('1px 2px 3px 4px 5px') == none
	assert parse_a_margin('1em') == none
	assert parse_a_margin('0') == none
	assert parse_a_margin('auto') == none
}

fn test_constructor_sorts_thresholds_applies_defaults_and_visibility_delay_floor() {
	document := dom.Document.create(dom.url_about_blank())
	observer := IntersectionObserver.construct_impl(discard_entries, IntersectionObserverInit{
		relevant_document: document
		root_margin: '1px 2% 3px 4%'
		scroll_margin: '5px'
		thresholds: [0.75, 0.0, 0.5, 0.5]
		delay: 5
		track_visibility: true
	}) or { panic(err) }
	assert observer.thresholds() == [0.0, 0.5, 0.5, 0.75]
	assert observer.root_margin() == '1px 2% 3px 4%'
	assert observer.scroll_margin() == '5px 5px 5px 5px'
	assert observer.delay() == 100
	assert observer.track_visibility()
	assert observer.is_implicit_root()
	assert observer.intersection_root().document? == document
	assert observer.intersection_root_node()? == unsafe { &dom.Node(document) }

	empty := IntersectionObserver.construct(discard_entries, IntersectionObserverInit{
		thresholds: []
		delay: -10
	}) or { panic(err) }
	assert empty.thresholds() == [0.0]
	assert empty.delay() == -10
}

fn test_constructor_reports_margin_and_threshold_errors() {
	if _ := IntersectionObserver.construct(discard_entries, IntersectionObserverInit{
		root_margin: '1em'
	}) {
		assert false
	} else {
		assert err.msg().contains('root margin')
	}
	if _ := IntersectionObserver.construct(discard_entries, IntersectionObserverInit{
		scroll_margin: 'auto'
	}) {
		assert false
	} else {
		assert err.msg().contains('scroll margin')
	}
	for threshold in [-0.01, 1.01] {
		if _ := IntersectionObserver.construct(discard_entries, IntersectionObserverInit{
			thresholds: [threshold]
		}) {
			assert false
		}
	}
	with_nan := IntersectionObserver.construct(discard_entries, IntersectionObserverInit{
		thresholds: [math.nan()]
	}) or { panic('comparison-only C++ check admits NaN') }
	assert math.is_nan(with_nan.thresholds()[0])
}

fn test_observe_unobserve_disconnect_and_take_records() {
	mut observer := default_observer()
	document := dom.Document.create(dom.url_about_blank())
	target_a := document.create_element('div') or { panic(err) }
	target_b := document.create_element('span') or { panic(err) }
	observer.observe(target_a)
	observer.observe(target_a)
	observer.observe(target_b)
	assert observer.observation_targets().len == 2
	mut registered_a := target_a
	mut registered_b := target_b
	assert registered_a.get_intersection_observer_registration(voidptr(observer)) != none
	assert registered_b.get_intersection_observer_registration(voidptr(observer)) != none
	observer.unobserve(target_a)
	assert observer.observation_targets() == [target_b]
	assert registered_a.get_intersection_observer_registration(voidptr(observer)) == none
	assert registered_b.get_intersection_observer_registration(voidptr(observer)) != none
	observer.disconnect()
	assert observer.observation_targets().len == 0
	assert registered_b.get_intersection_observer_registration(voidptr(observer)) == none

	entry := IntersectionObserverEntry.construct(IntersectionObserverEntryInit{
		target: target_a
	}) or { panic(err) }
	observer.queue_entry(entry)
	assert observer.take_records() == [entry]
	assert observer.take_records().len == 0
}

fn test_observe_uses_dom_object_identity_for_equivalent_elements() {
	mut observer := default_observer()
	// Bare Elements have equal field values but represent distinct DOM objects.
	target_a := &dom.Element{}
	target_b := &dom.Element{}
	assert target_a == target_b
	observer.observe(target_a)
	observer.observe(target_b)
	assert observer.observation_targets().len == 2
	observer.unobserve(target_a)
	assert observer.observation_targets().len == 1
	assert voidptr(observer.observation_targets()[0]) == voidptr(target_b)
}

fn test_root_intersection_rectangle_expands_only_same_origin_layout_roots() {
	observer := IntersectionObserver.construct(discard_entries, IntersectionObserverInit{
		root_margin: '10% 5px 20% 2px'
	}) or { panic(err) }
	base := geometry.DOMRectInit{10, 20, 200, 100}
	expanded := observer.root_intersection_rectangle(RootGeometry{ rect: base })
	assert expanded == geometry.DOMRectInit{8, 10, 207, 130}
	assert observer.root_intersection_rectangle(RootGeometry{
		rect: base
		same_origin: false
	}) == base
	assert observer.root_intersection_rectangle(RootGeometry{
		rect: base
		has_layout_box: false
	}) == base
}
