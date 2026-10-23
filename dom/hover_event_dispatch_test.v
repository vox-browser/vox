module dom

struct HoverBatchObservation {
mut:
	events  []string
	related []voidptr
	offsets []f64
	trusted []bool
}

struct HoverGeometryFixture {
mut:
	shift f64
}

fn hover_geometry_inverse(target voidptr, _ voidptr, point CSSPixelPoint_) CSSPixelPoint_ {
	state := unsafe { &HoverGeometryFixture(target) }
	return CSSPixelPoint_{point.x() - state.shift, point.y()}
}

fn observe_hover_events(node &Node, label string, state &HoverBatchObservation) {
	for name in ['pointerout', 'mouseout', 'pointerleave', 'mouseleave', 'pointerover', 'mouseover',
		'pointerenter', 'mouseenter'] {
		callback := &CallbackType{
			handle_event: fn [label, state] (event &Event, current ?&EventTarget) JSValue {
				if voidptr(event.target() or { return js_undefined() }) != voidptr(current or { return js_undefined() }) {
					return js_undefined()
				}
				mut observed := unsafe { &HoverBatchObservation(state) }
				observed.events << '${label}:${event.type_}'
				observed.related << voidptr(event.related_target_ or { unsafe { nil } })
				observed.trusted << event.is_trusted()
				observed.offsets << unsafe { &MouseEvent(event) }.offset_x()
				return js_undefined()
			}
		}
		mut target := unsafe { &EventTarget(node) }
		target.add_event_listener_without_options(name, IDLEventListener.create(callback))
	}
}

fn test_hover_batch_stops_leaves_and_enters_at_the_common_ancestor() {
	mut document := Document.create_for_fragment_parsing()
	parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	left := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	right := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut root := unsafe { &Node(document) }
	root.append_child(parent.as_node())!
	mut parent_node := parent.as_node()
	parent_node.append_child(left.as_node())!
	parent_node.append_child(right.as_node())!
	state := &HoverBatchObservation{}
	observe_hover_events(parent.as_node(), 'parent', state)
	observe_hover_events(left.as_node(), 'left', state)
	observe_hover_events(right.as_node(), 'right', state)
	document.set_hovered_node(left.as_node())
	mut observation := unsafe { &HoverBatchObservation(state) }
	observation.events.clear()
	observation.related.clear()
	observation.offsets.clear()
	observation.trusted.clear()
	document.set_hovered_node_with_data(right.as_node(), HoverEventData{
		page_offset:       CSSPixelPoint_{30, 40}
		viewport_position: CSSPixelPoint_{10, 20}
	})
	assert state.events == ['left:pointerout', 'left:mouseout', 'left:pointerleave', 'left:mouseleave',
		'right:pointerover', 'right:mouseover', 'right:pointerenter', 'right:mouseenter']
	assert state.related[..4].all(it == voidptr(right.as_node()))
	assert state.related[4..].all(it == voidptr(left.as_node()))
	assert state.trusted.all(it)
	assert state.offsets.all(it == 10)
	document.set_hovered_node_with_data(right.as_node(), HoverEventData{})
	assert state.events.len == 8
	document.set_hovered_node(none)
	assert !state.trusted.last()
}

fn test_hover_batch_freezes_all_offsets_before_an_earlier_listener_changes_geometry() {
	mut document := Document.create_for_fragment_parsing()
	parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	left := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	right := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut root := unsafe { &Node(document) }
	root.append_child(parent.as_node())!
	mut parent_node := parent.as_node()
	parent_node.append_child(left.as_node())!
	parent_node.append_child(right.as_node())!
	geometry := &HoverGeometryFixture{ shift: 5 }
	for element in [parent, left, right] {
		mut node := element.as_node()
		paintable := &Paintable{
			repaint_callback_target:          voidptr(geometry)
			callbacks: &PaintableCallbacks{ inverse_transform_point_callback: hover_geometry_inverse }
		}
		node.set_layout_node(&LayoutNode{ paintables_: [paintable] })
		node.set_paintable(paintable)
	}
	state := &HoverBatchObservation{}
	observe_hover_events(left.as_node(), 'left', state)
	observe_hover_events(right.as_node(), 'right', state)
	document.set_hovered_node(left.as_node())
	mut observation := unsafe { &HoverBatchObservation(state) }
	observation.offsets.clear()
	callback := &CallbackType{
		handle_event: fn [geometry] (_ &Event, _ ?&EventTarget) JSValue {
			mut state := unsafe { &HoverGeometryFixture(geometry) }
			state.shift = 50
			return js_undefined()
		}
	}
	mut target := unsafe { &EventTarget(left.as_node()) }
	target.add_event_listener_without_options('pointerout', IDLEventListener.create(callback))
	document.set_hovered_node_with_data(right.as_node(), HoverEventData{
		page_offset:       CSSPixelPoint_{30, 40}
		viewport_position: CSSPixelPoint_{10, 20}
	})
	assert geometry.shift == 50
	assert state.offsets.len == 8
	assert state.offsets.all(it == 25)
}
