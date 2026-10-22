module dom

@[heap]
struct AnimatedStyleCallbackProbe {
mut:
	ordinary   int
	compositor int
}

fn ordinary_animated_style_probe(handle voidptr, _ voidptr) {
	mut probe := unsafe { &AnimatedStyleCallbackProbe(handle) }
	probe.ordinary++
}

fn compositor_animated_style_probe(handle voidptr, _ voidptr) bool {
	mut probe := unsafe { &AnimatedStyleCallbackProbe(handle) }
	probe.compositor++
	return probe.compositor % 2 == 1
}

fn test_sampled_style_callback_is_optional_and_uses_ordinary_fallback() {
	probe := &AnimatedStyleCallbackProbe{}
	mut placeholder := &LayoutNode{
		layout_handle: voidptr(probe)
		callbacks_:    &LayoutNodeCallbacks{ apply_style_callback: ordinary_animated_style_probe }
	}
	assert !placeholder.apply_animated_style(voidptr(probe), true)
	assert probe.ordinary == 1
	assert probe.compositor == 0
	callbacks := *placeholder.bridge_callbacks()
	placeholder.callbacks_ = &LayoutNodeCallbacks{ ...callbacks, apply_animated_style_callback: compositor_animated_style_probe }
	assert !placeholder.apply_animated_style(voidptr(probe), false)
	assert probe.ordinary == 2
	assert probe.compositor == 0
	// The embedder's own result reports whether it retained the sample.
	assert placeholder.apply_animated_style(voidptr(probe), true)
	assert probe.ordinary == 2
	assert probe.compositor == 1
	assert !placeholder.apply_animated_style(voidptr(probe), true)
	assert probe.compositor == 2
}
