module dom

@[heap]
struct LayoutStyleUpdateProbe {
mut:
	document      &Document
	style_passes  int
	notifications int
}

fn layout_style_update_probe_regular(target voidptr) RequiredInvalidationAfterStyleChange {
	mut probe := unsafe { &LayoutStyleUpdateProbe(target) }
	probe.style_passes++
	mut node := unsafe { &Node(probe.document) }
	node.set_needs_style_update(false)
	node.set_child_needs_style_update(false)
	return RequiredInvalidationAfterStyleChange{}
}

fn layout_style_update_probe_animated(target voidptr) {
	mut probe := unsafe { &LayoutStyleUpdateProbe(target) }
	probe.style_passes++
}

fn layout_style_update_probe_notify(target voidptr, document &Document) {
	mut probe := unsafe { &LayoutStyleUpdateProbe(target) }
	assert voidptr(document) == voidptr(probe.document)
	assert probe.style_passes > probe.notifications
	assert !document.needs_full_style_update
	assert !document.needs_animated_style_update
	probe.notifications++
}

fn test_layout_style_hook_observes_completed_regular_pass_and_skips_clean_updates() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&BrowsingContext{})
	mut probe := &LayoutStyleUpdateProbe{
		document: document
	}
	document.set_layout_update_hook(DocumentLayoutUpdateHook{
		target:           probe
		style_did_update: layout_style_update_probe_notify
	})
	document.set_style_update_hook(DocumentStyleUpdateHook{
		target:   probe
		callback: layout_style_update_probe_regular
	})
	document.set_needs_full_style_update(true)
	document.update_style()
	assert probe.style_passes == 1 && probe.notifications == 1
	document.update_style()
	assert probe.style_passes == 1 && probe.notifications == 1
	document.set_needs_full_style_update(true)
	document.update_style()
	assert probe.style_passes == 2 && probe.notifications == 2
}

fn test_layout_style_hook_observes_completed_animation_and_accepts_legacy_hook() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut probe := &LayoutStyleUpdateProbe{
		document: document
	}
	document.needs_full_style_update = false
	document.style_computer = &StyleComputer{
		css_handle:                     probe
		update_animated_style_callback: layout_style_update_probe_animated
	}
	document.set_layout_update_hook(DocumentLayoutUpdateHook{
		target:           probe
		style_did_update: layout_style_update_probe_notify
	})
	document.set_needs_animated_style_update()
	document.update_animated_style_if_needed()
	assert probe.style_passes == 1 && probe.notifications == 1
	document.update_animated_style_if_needed()
	assert probe.style_passes == 1 && probe.notifications == 1
	document.set_layout_update_hook(DocumentLayoutUpdateHook{})
	document.set_needs_animated_style_update()
	document.update_animated_style_if_needed()
	assert probe.style_passes == 2 && probe.notifications == 1
	document.set_layout_update_hook(DocumentLayoutUpdateHook{
		target: probe
		style_did_update: layout_style_update_probe_notify
	})
	document.style_computer = unsafe { nil }
	document.set_needs_animated_style_update()
	document.update_animated_style_if_needed()
	assert probe.style_passes == 2 && probe.notifications == 1
	assert !document.needs_animated_style_update
}
