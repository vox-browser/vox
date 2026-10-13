module dom

fn mouse_related_target_pointer(value ?&EventTarget) voidptr {
	return voidptr(value or { unsafe { nil } })
}

fn assert_mouse_related_target_agreement(event &Event, expected ?&EventTarget) {
	assert event.interface_ in [.mouse_event, .pointer_event, .wheel_event]
	assert mouse_related_target_pointer(event.related_target()) == mouse_related_target_pointer(expected)
	mouse := unsafe { &MouseEvent(event) }
	assert mouse_related_target_pointer(mouse.related_target()) == mouse_related_target_pointer(expected)
	assert mouse_related_target_pointer(mouse.related_target_mouse()) == mouse_related_target_pointer(expected)
}

struct MouseRelatedTargetTree {
	document &Document
	outer    &Element
	host     &Element
	shadow   &ShadowRoot
	slot     &HTMLSlotElement
	peer     &Element
	light    &Element
	outside  &Element
}

fn mouse_related_target_tree() MouseRelatedTargetTree {
	document := Document.create_for_fragment_parsing()
	outer := document.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	mut host := document.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	outside := document.create_element_ns(namespace_html_uri, 'span') or { panic(err) }
	mut document_node := unsafe { &Node(document) }
	document_node.append_child(outer.as_node()) or { panic(err) }
	mut outer_node := outer.as_node()
	outer_node.append_child(host.as_node()) or { panic(err) }
	outer_node.append_child(outside.as_node()) or { panic(err) }
	shadow := host.attach_shadow(ShadowRootInit{ mode: .closed }) or { panic(err) }
	slot_element := document.create_element_ns(namespace_html_uri, 'slot') or { panic(err) }
	slot := unsafe { &HTMLSlotElement(slot_element) }
	peer := document.create_element_ns(namespace_html_uri, 'span') or { panic(err) }
	mut shadow_node := unsafe { &Node(shadow) }
	shadow_node.append_child(slot_element.as_node()) or { panic(err) }
	shadow_node.append_child(peer.as_node()) or { panic(err) }
	light := document.create_element_ns(namespace_html_uri, 'span') or { panic(err) }
	mut host_node := host.as_node()
	host_node.append_child(light.as_node()) or { panic(err) }
	assert light.as_node().assigned_slot_internal() or { panic('missing native slot assignment') } == slot
	return MouseRelatedTargetTree{
		document: document
		outer:    outer
		host:     host
		shadow:   shadow
		slot:     slot
		peer:     peer
		light:    light
		outside:  outside
	}
}

struct MouseRelatedTargetObservation {
mut:
	labels         []string
	base_related   []voidptr
	mouse_related  []voidptr
	targets        []voidptr
	trusted        []bool
	pointer_events []bool
}

fn (mut observation MouseRelatedTargetObservation) reset() {
	observation.labels.clear()
	observation.base_related.clear()
	observation.mouse_related.clear()
	observation.targets.clear()
	observation.trusted.clear()
	observation.pointer_events.clear()
}

fn observe_mouse_related_target(node &Node, name string, label string, observation &MouseRelatedTargetObservation) {
	callback := &CallbackType{
		handle_event: fn [label, observation] (event &Event, _ ?&EventTarget) JSValue {
			mut result := unsafe { &MouseRelatedTargetObservation(observation) }
			result.labels << label
			result.base_related << mouse_related_target_pointer(event.related_target())
			result.mouse_related << mouse_related_target_pointer(unsafe { &MouseEvent(event) }.related_target())
			result.targets << mouse_related_target_pointer(event.target())
			result.trusted << event.is_trusted()
			result.pointer_events << (event.interface_ == .pointer_event)
			return js_undefined()
		}
	}
	unsafe { &EventTarget(node) }.add_event_listener_without_options(name,
		IDLEventListener.create(callback))
}

fn test_mouse_family_constructors_share_related_target_with_base_event() {
	related := EventTarget.new()
	focus := FocusEvent.construct_impl('focusout', FocusEventInit{ related_target: related })!
	assert mouse_related_target_pointer(focus.related_target()) == voidptr(related)
	assert mouse_related_target_pointer(unsafe { &Event(focus) }.related_target()) == voidptr(related)
	init := MouseEventInit{
		related_target: related
		client_x:       3.25
	}
	events := [unsafe { &Event(MouseEvent.create('mouseover', init)) }, unsafe { &Event(MouseEvent.construct_impl('mouseover', init)!) },
		unsafe { &Event(PointerEvent.create('pointerover', PointerEventInit{ MouseEventInit: init })) },
		unsafe {
			&Event(PointerEvent.construct_impl('pointerover', PointerEventInit{
				MouseEventInit: init
			})!)
		},
		unsafe { &Event(WheelEvent.create('wheel', WheelEventInit{ MouseEventInit: init })) },
		unsafe { &Event(WheelEvent.construct_impl('wheel', WheelEventInit{ MouseEventInit: init })!) }]
	for index, event in events {
		assert_mouse_related_target_agreement(event, related)
		assert event.is_trusted() == (index % 2 == 0)
	}
	for event in [unsafe { &Event(MouseEvent.create('mouseover', MouseEventInit{})) }, unsafe { &Event(PointerEvent.create('pointerover', PointerEventInit{})) },
		unsafe { &Event(WheelEvent.create('wheel', WheelEventInit{})) }] {
		assert_mouse_related_target_agreement(event, none)
	}
}

fn test_mouse_legacy_initialization_and_clones_use_current_base_related_target() {
	first := EventTarget.new()
	second := EventTarget.new()
	mut mouse := MouseEvent.create('mouseout', MouseEventInit{
		related_target: first
		button:         2
		client_x:       5.25
	})
	mut base := unsafe { &Event(mouse) }
	base.set_related_target(second)
	assert_mouse_related_target_agreement(base, second)
	for cloned in [mouse.clone(), MouseEvent.create_from_mouse_event(mouse, 42)] {
		assert_mouse_related_target_agreement(unsafe { &Event(cloned) }, second)
		assert !cloned.is_trusted() && cloned.button() == 2
	}
	mouse.init_mouse_event('legacy', true, false, unsafe { nil }, 7, 11, 12, 13, 14, true, false,
		true, false, 1, first)
	assert_mouse_related_target_agreement(base, first)
	assert mouse.type_name() == 'legacy' && mouse.detail() == 7 && mouse.client_x() == 13
	assert !mouse.is_trusted()
	base.set_dispatched(true)
	mouse.init_mouse_event('ignored', false, true, unsafe { nil }, 0, 0, 0, 0, 0, false, false,
		false, false, 0, second)
	assert_mouse_related_target_agreement(base, first)
	assert mouse.type_name() == 'legacy' && mouse.detail() == 7
	base.set_dispatched(false)
	base.set_related_target(none)
	assert_mouse_related_target_agreement(base, none)
	assert_mouse_related_target_agreement(unsafe { &Event(mouse.clone()) }, none)

	mut pointer := PointerEvent.create('pointerout', PointerEventInit{
		MouseEventInit: MouseEventInit{
			related_target: first
		}
		pointer_id:     19
	})
	mut pointer_base := unsafe { &Event(pointer) }
	pointer_base.set_related_target(second)
	assert_mouse_related_target_agreement(pointer_base, second)
	pointer_clone := pointer.clone()
	assert_mouse_related_target_agreement(unsafe { &Event(pointer_clone) }, second)
	assert pointer_clone.pointer_id() == 19 && !pointer_clone.is_trusted()
	mut pointer_mouse := unsafe { &MouseEvent(pointer) }
	pointer_mouse.init_mouse_event('pointerlegacy', false, false, unsafe { nil }, 0, 0, 0, 0, 0,
		false, false, false, false, 0, none)
	assert_mouse_related_target_agreement(pointer_base, none)
	assert_mouse_related_target_agreement(unsafe { &Event(pointer.clone()) }, none)
}

fn test_mouse_related_target_is_retargeted_for_each_shadow_listener_and_cleared_after_dispatch() {
	tree := mouse_related_target_tree()
	mut observed := &MouseRelatedTargetObservation{}
	for label, node in {
		'light': tree.light.as_node()
		'slot':  unsafe { &Node(tree.slot) }
		'host':  tree.host.as_node()
		'outer': tree.outer.as_node()
	} {
		observe_mouse_related_target(node, 'mouseover', label, observed)
	}
	init := MouseEventInit{
		EventModifierInit: EventModifierInit{
			UIEventInit: UIEventInit{
				EventInit: EventInit{
					bubbles:  true
					composed: true
				}
			}
		}
		related_target:    unsafe { &EventTarget(tree.peer.as_node()) }
	}
	// A light target assigned to a slot crosses the shadow boundary without the
	// target itself retargeting to the host. The related target changes by listener.
	for event in [unsafe { &Event(MouseEvent.create('mouseover', init)) }, unsafe {
		&Event(PointerEvent.create('mouseover', PointerEventInit{
			MouseEventInit: init
		}))
	}] {
		observed.reset()
		assert event_target_dispatch_event(unsafe { &EventTarget(tree.light.as_node()) }, event)
		assert observed.labels == ['light', 'slot', 'host', 'outer']
		expected := [voidptr(tree.host.as_node()), voidptr(tree.peer.as_node()),
			voidptr(tree.host.as_node()), voidptr(tree.host.as_node())]
		assert observed.base_related == expected
		assert observed.mouse_related == expected
		assert observed.targets.all(it == voidptr(tree.light.as_node()))
		assert_mouse_related_target_agreement(event, unsafe { &EventTarget(tree.host.as_node()) })
		assert event.current_target() == none && !event.dispatched() && event.path().len == 0
	}
	observe_mouse_related_target(tree.peer.as_node(), 'clear-related', 'peer', observed)
	observe_mouse_related_target(unsafe { &Node(tree.shadow) }, 'clear-related', 'shadow', observed)
	observe_mouse_related_target(tree.host.as_node(), 'clear-related', 'host', observed)
	observed.reset()
	event := MouseEvent.create('clear-related', MouseEventInit{
		EventModifierInit: EventModifierInit{
			UIEventInit: UIEventInit{
				EventInit: EventInit{
					bubbles: true
				}
			}
		}
		related_target:    unsafe { &EventTarget(tree.slot) }
	})
	assert event_target_dispatch_event(unsafe { &EventTarget(tree.peer.as_node()) },
		unsafe { &Event(event) })
	assert observed.labels == ['peer', 'shadow']
	assert observed.base_related.all(it == voidptr(tree.slot))
	assert observed.mouse_related == observed.base_related
	assert_mouse_related_target_agreement(unsafe { &Event(event) }, none)
	assert event.target() == none && event.current_target() == none && event.path().len == 0
}

fn test_mouse_related_retarget_suppression_and_trusted_hover_pairs_share_canonical_state() {
	tree := mouse_related_target_tree()
	mut observed := &MouseRelatedTargetObservation{}
	observe_mouse_related_target(tree.host.as_node(), 'mouseover', 'host', observed)
	observe_mouse_related_target(tree.outer.as_node(), 'mouseover', 'outer', observed)
	init := MouseEventInit{
		EventModifierInit: EventModifierInit{
			UIEventInit: UIEventInit{
				EventInit: EventInit{
					bubbles:  true
					composed: true
				}
			}
		}
		related_target:    unsafe { &EventTarget(tree.peer.as_node()) }
	}
	suppressed := MouseEvent.create('mouseover', init)
	assert event_target_dispatch_event(unsafe { &EventTarget(tree.host.as_node()) },
		unsafe { &Event(suppressed) })
	assert observed.labels.len == 0
	assert_mouse_related_target_agreement(unsafe { &Event(suppressed) },
		unsafe { &EventTarget(tree.peer.as_node()) })
	// The dispatch algorithm permits an original related target equal to target;
	// suppression above arises only after a distinct shadow descendant retargets.
	self_related := MouseEvent.create('mouseover', MouseEventInit{
		EventModifierInit: init.EventModifierInit
		related_target:    unsafe { &EventTarget(tree.host.as_node()) }
	})
	assert event_target_dispatch_event(unsafe { &EventTarget(tree.host.as_node()) },
		unsafe { &Event(self_related) })
	assert observed.labels == ['host', 'outer']
	assert observed.base_related.all(it == voidptr(tree.host.as_node()))
	assert observed.mouse_related == observed.base_related

	for name in ['pointerover', 'mouseover'] {
		observe_mouse_related_target(tree.outside.as_node(), name, name, observed)
	}
	mut document := unsafe { &Document(tree.document) }
	document.set_hovered_node(tree.peer.as_node())
	observed.reset()
	document.set_hovered_node_with_data(tree.outside.as_node(), HoverEventData{
		viewport_position: CSSPixelPoint_{9.25, 4.5}
		page_offset:       CSSPixelPoint_{9.25, 4.5}
	})
	assert observed.labels == ['pointerover', 'mouseover', 'outer']
	assert observed.pointer_events == [true, false, false]
	assert observed.trusted.all(it)
	assert observed.base_related.all(it == voidptr(tree.host.as_node()))
	assert observed.mouse_related == observed.base_related
	assert observed.targets.all(it == voidptr(tree.outside.as_node()))
}
