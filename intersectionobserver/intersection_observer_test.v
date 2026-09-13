@[has_globals]
module intersectionobserver

import dom
import geometry
import html
import layout
import math
import page

__global (
	intersection_observer_callback_count  int
	intersection_observer_entry_count     int
	intersection_observer_entry_time      f64
	intersection_observer_is_intersecting bool
	intersection_observer_ratio           f64
)

fn discard_entries(_ []&IntersectionObserverEntry, _ &IntersectionObserver) {}

fn record_delivered_entries(entries []&IntersectionObserverEntry, _ &IntersectionObserver) {
	unsafe {
		intersection_observer_callback_count++
		intersection_observer_entry_count = entries.len
		if entries.len > 0 {
			intersection_observer_entry_time = entries[0].time()
			intersection_observer_is_intersecting = entries[0].is_intersecting()
			intersection_observer_ratio = entries[0].intersection_ratio()
		}
	}
}

fn reset_recorded_entries() {
	unsafe {
		intersection_observer_callback_count = 0
		intersection_observer_entry_count = 0
		intersection_observer_entry_time = 0
		intersection_observer_is_intersecting = false
		intersection_observer_ratio = 0
	}
}

fn deliver_intersection_observer_tasks() {
	mut event_loop := html.main_thread_event_loop()
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
	}
}

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
	assert registered_a.has_registered_intersection_observer(voidptr(observer))
	assert registered_b.has_registered_intersection_observer(voidptr(observer))
	observer.unobserve(target_a)
	assert observer.observation_targets() == [target_b]
	assert !registered_a.has_registered_intersection_observer(voidptr(observer))
	assert registered_b.has_registered_intersection_observer(voidptr(observer))
	observer.disconnect()
	assert observer.observation_targets().len == 0
	assert !registered_b.has_registered_intersection_observer(voidptr(observer))

	entry := IntersectionObserverEntry.construct(IntersectionObserverEntryInit{
		target: target_a
	}) or { panic(err) }
	observer.queue_entry(entry)
	assert observer.take_records() == [entry]
	assert observer.take_records().len == 0
}

fn test_document_queues_one_task_constructs_entries_and_notifies_registered_observer() {
	reset_recorded_entries()
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_window(&dom.Window{})
	_ = html.WindowModel.create_top_level(document, none, 'intersection-observer-test') or {
		panic(err)
	}
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	assert document.is_fully_active()
	mut observer := IntersectionObserver.construct(record_delivered_entries, IntersectionObserverInit{
		relevant_document: document
	}) or { panic(err) }
	assert document.registered_intersection_observer_count() == 1
	target := document.create_element('div') or { panic(err) }
	registration := observer.document_registration_ or { panic('observer was not registered') }

	document.queue_an_intersection_observer_entry(registration, 42.5, dom.Rect{1, 2, 3, 4}, dom.Rect{5, 6, 7, 8}, dom.Rect{9, 10, 11, 12}, true, 0.75, target)
	document.queue_an_intersection_observer_entry(registration, 43.5, dom.Rect{}, dom.Rect{}, dom.Rect{}, false, 0.0, target)
	assert intersection_observer_callback_count == 0

	mut event_loop := html.main_thread_event_loop()
	for event_loop.task_queue().has_runnable_tasks() && intersection_observer_callback_count == 0 {
		event_loop.process()
	}
	assert intersection_observer_callback_count == 1
	assert intersection_observer_entry_count == 2
	assert intersection_observer_entry_time == 42.5
	assert observer.take_records().len == 0

	observer.finalize()
	assert document.registered_intersection_observer_count() == 0
}

fn test_document_update_intersection_observations_uses_layout_geometry_and_threshold_state() {
	reset_recorded_entries()
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_window(&dom.Window{})
	document.set_browsing_context(&dom.BrowsingContext{})
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	_ = html.WindowModel.create_top_level(document, none, 'intersection-observer-layout-test') or {
		panic(err)
	}
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)

	mut html_element := document.create_element('html') or { panic(err) }
	mut target := document.create_element('div') or { panic(err) }
	target.set_attribute_value('style', 'position: absolute; left: 10px; top: 20px; width: 100px; height: 50px')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html_element.as_node()) or { panic(err) }
	mut html_node := html_element.as_node()
	html_node.append_child(target.as_node()) or { panic(err) }
	layout.install_document_layout_hook(document)
	document.needs_full_layout_tree_update = true
	document.update_layout(.debugging)
	assert target.el_layout_node() != none
	assert document.layout_is_up_to_date()

	// Internal IntersectionObserver geometry reads use the retained layout
	// directly and must not flush a newly dirtied document per target.
	target.set_attribute_value('style', 'position: absolute; left: 11px; top: 20px; width: 100px; height: 50px')
	mut dirty_target_node := target.as_node()
	dirty_target_node.set_needs_layout_tree_update(true, .style_change)
	assert !document.layout_is_up_to_date()
	stale_rect := target.bounding_client_rect_assuming_layout_clean()
	assert stale_rect.x == 10
	assert !document.layout_is_up_to_date()
	document.update_layout(.debugging)
	assert target.bounding_client_rect_assuming_layout_clean().x == 11

	mut observer := IntersectionObserver.construct(record_delivered_entries, IntersectionObserverInit{
		relevant_document: document
		thresholds: [0.0, 0.5, 1.0]
	}) or { panic(err) }
	observer.observe(target)
	document.run_the_update_intersection_observations_steps(100)
	deliver_intersection_observer_tasks()
	assert intersection_observer_callback_count == 1
	assert intersection_observer_entry_count == 1
	assert intersection_observer_entry_time == 100
	assert intersection_observer_is_intersecting
	assert math.abs(intersection_observer_ratio - 1.0) < 0.000001

	// The retained registration suppresses delivery while threshold index and
	// intersection state remain unchanged.
	document.run_the_update_intersection_observations_steps(101)
	deliver_intersection_observer_tasks()
	assert intersection_observer_callback_count == 1

	// Moving the same observed target outside the viewport crosses every
	// threshold and queues one new entry with the updated state.
	target.set_attribute_value('style', 'position: absolute; left: 900px; top: 20px; width: 100px; height: 50px')
	document.update_layout(.debugging)
	document.run_the_update_intersection_observations_steps(102)
	deliver_intersection_observer_tasks()
	assert intersection_observer_callback_count == 2
	assert intersection_observer_entry_count == 1
	assert intersection_observer_entry_time == 102
	assert !intersection_observer_is_intersecting
	assert intersection_observer_ratio == 0.0

	observer.finalize()

	// Current Ladybird reports geometry below the first threshold as not
	// intersecting, while retaining the measured ratio.
	reset_recorded_entries()
	target.set_attribute_value('style', 'position: absolute; left: 750px; top: 20px; width: 100px; height: 50px')
	document.update_layout(.debugging)
	mut threshold_observer := IntersectionObserver.construct(record_delivered_entries,
		IntersectionObserverInit{
		relevant_document: document
		thresholds: [0.75]
	}) or { panic(err) }
	threshold_observer.observe(target)
	document.run_the_update_intersection_observations_steps(103)
	deliver_intersection_observer_tasks()
	assert intersection_observer_callback_count == 1
	assert math.abs(intersection_observer_ratio - 0.5) < 0.000001
	assert !intersection_observer_is_intersecting
	threshold_observer.finalize()
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

fn test_root_intersection_rectangle_expands_same_origin_roots_without_requiring_a_layout_box() {
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
	}) == expanded
}

fn test_scroll_margin_expands_scrollable_root_and_callback_factories() {
	reset_recorded_entries()
	document := dom.Document.create(dom.url_about_blank())
	mut observer := IntersectionObserver.create_for_constructor(record_delivered_entries, IntersectionObserverInit{
		root_margin: '10px'
		scroll_margin: '5% 2px'
	}, document)!
	base := geometry.DOMRectInit{10, 20, 200, 100}
	expanded := observer.root_intersection_rectangle(RootGeometry{
		rect: base
		is_scrollable: true
	})
	assert expanded == geometry.DOMRectInit{-2, 0, 224, 140}
	callback := create_lazy_load_intersection_observer_callback(record_delivered_entries)
	callback([], observer)
	assert intersection_observer_callback_count == 1
	invoke_intersection_observer_callback(observer, [])
	assert intersection_observer_callback_count == 2
	observer.finalize()
}

fn test_observe_requests_a_frame_for_the_initial_intersection_update() {
	mut page_model := page.Page.create(1.0)!
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_page(unsafe { &dom.Page(page_model) })
	mut client := page_model.client()
	client.events.clear()

	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	mut observer := IntersectionObserver.create_for_constructor(discard_entries, IntersectionObserverInit{}, document)!
	observer.observe(target)
	assert client.events.map(it.name) == ['request-frame']

	// Observing the same target again is a no-op and must not schedule another frame.
	observer.observe(target)
	assert client.events.map(it.name) == ['request-frame']
	observer.finalize()
}
