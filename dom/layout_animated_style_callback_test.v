module dom

@[heap]
struct AnimatedStyleCallbackProbe {
mut:
	ordinary int
	compositor int
}

fn ordinary_animated_style_probe(handle voidptr, _ voidptr) {
	mut probe := unsafe { &AnimatedStyleCallbackProbe(handle) }
	probe.ordinary++
}

fn compositor_animated_style_probe(handle voidptr, _ voidptr) {
	mut probe := unsafe { &AnimatedStyleCallbackProbe(handle) }
	probe.compositor++
}

fn test_sampled_style_callback_is_optional_and_uses_ordinary_fallback() {
	probe := &AnimatedStyleCallbackProbe{}
	mut placeholder := &LayoutNode{
		layout_handle: voidptr(probe)
		apply_style_callback: ordinary_animated_style_probe
	}
	placeholder.apply_animated_style(voidptr(probe), true)
	assert probe.ordinary == 1
	assert probe.compositor == 0
	placeholder.apply_animated_style_callback = compositor_animated_style_probe
	placeholder.apply_animated_style(voidptr(probe), false)
	assert probe.ordinary == 2
	assert probe.compositor == 0
	placeholder.apply_animated_style(voidptr(probe), true)
	assert probe.ordinary == 2
	assert probe.compositor == 1
}
