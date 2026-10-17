module dom

// Chromium matches :focus, :focus-within and :focus-visible, and paints the
// caret, only in a focused and active frame (SelectorChecker::IsFrameFocused
// and FrameSelection::FrameIsFocusedAndActive). The embedder reports whether
// the window that shows the top-level document is active; a background or
// headless window is not. LibWeb's policy keeps showing the focused area.
pub fn (d &Document) shows_focus_state() bool {
	if d.font_rendering_policy_ != .chromium {
		return true
	}
	if navigable := d.navigable() {
		if traversable := navigable.traversable_navigable() {
			if top := traversable.active_document() {
				return !top.embedder_window_inactive_
			}
		}
	}
	return !d.embedder_window_inactive_
}

pub fn (mut d Document) set_embedder_window_active(active bool) {
	if d.embedder_window_inactive_ == !active {
		return
	}
	d.embedder_window_inactive_ = !active
	if d.font_rendering_policy_ != .chromium {
		return
	}
	if focused := d.focused_area() {
		for pseudo_class in [PseudoClass.focus, .focus_within, .focus_visible] {
			d.invalidate_style_for_elements_affected_by_pseudo_class_change(pseudo_class,
				focused.root(), focused)
		}
	}
	d.set_needs_repaint()
}
