module dom

@[heap]
struct ColorStyleCallbackProbe {
mut:
	ordinary int
	color    int
	retain   bool
}

fn ordinary_color_style_probe(handle voidptr, _ voidptr) {
	mut probe := unsafe { &ColorStyleCallbackProbe(handle) }
	probe.ordinary++
}

fn retained_color_style_probe(handle voidptr, _ voidptr) bool {
	mut probe := unsafe { &ColorStyleCallbackProbe(handle) }
	probe.color++
	return probe.retain
}

fn test_inherited_color_style_callback_preserves_legacy_and_declined_application() {
	mut probe := &ColorStyleCallbackProbe{}
	mut node := &LayoutNode{
		layout_handle: voidptr(probe)
		callbacks_:    &LayoutNodeCallbacks{ apply_style_callback: ordinary_color_style_probe }
	}
	assert !node.apply_inherited_color_style(voidptr(probe))
	assert probe.ordinary == 1
	callbacks := *node.bridge_callbacks()
	node.callbacks_ = &LayoutNodeCallbacks{ ...callbacks, apply_color_style_callback: retained_color_style_probe }
	assert !node.apply_inherited_color_style(voidptr(probe))
	assert probe.ordinary == 2 && probe.color == 1
	probe.retain = true
	assert node.apply_inherited_color_style(voidptr(probe))
	assert probe.ordinary == 2 && probe.color == 2
	assert !node.apply_inherited_color_style(unsafe { nil })
	assert probe.ordinary == 2 && probe.color == 2
}
