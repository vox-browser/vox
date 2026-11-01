// vfmt off
@[has_globals]
module ui2

$if (linux || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
	import gg
	import time
	import sokol.sapp

	__global embedded_context = []Element{}
	__global embedded_elements = []Element{}
	__global embedded_wheel_handler = fn (_ f64, _ f64, _ f64, _ f64) bool { return false }
	__global embedded_image_paths = map[string]bool{}
	__global embedded_readonly = map[string]bool{}

	pub fn install_embedded_wheel(handler fn (f64, f64, f64, f64) bool) { embedded_wheel_handler = handler }
	pub fn copy_embedded_text(value string) { sapp.set_clipboard_string(value.str) }

	pub fn select_embedded_textbox() {
		focus('address')
		mut editor := g_text_editors['address'] or { text_editor(text('address').clone()) }
		editor.select_all()
		replace_text_editor('address', editor)
	}
	pub fn blur_embedded_textbox() { g_focused_field = '' }
	fn collect_embedded_readonly(elements []Element) {
		for element in elements {
			if element.kind in [.text_field, .text_area] { embedded_readonly[element.id] = element.readonly }
			collect_embedded_readonly(element.children)
		}
	}
	// Draw into Vox's existing pass. Images have already been decoded by Vox,
	// so no texture is allocated while its render pass is active.
	pub fn draw_embedded_elements(ctx &gg.Context, elements []Element, images map[string]int, handler EventFn) {
		g_gg_app.ctx = ctx
		g_event_handler = handler
		embedded_elements = elements.clone()
		embedded_readonly.clear()
		collect_embedded_readonly(elements)
		if elements.len == 0 { embedded_context.clear() }
		g_hit_targets.clear()
		g_tooltip_targets.clear()
		g_tooltip_owners = 0
		reset_scroll_frame()
		g_active_scrolls.clear()
		g_active_fields.clear()
		g_active_checkboxes.clear()
		g_active_sliders.clear()
		g_active_switches.clear()
		g_active_toggles.clear()
		g_active_images.clear()
		// Texture ownership stays with the embedding browser. Forget stale routes
		// without destroying its cache entries, and protect current borrowed images
		// from UI2's ordinary unmount cleanup.
		for path, _ in embedded_image_paths { if path !in images { g_image_ids.delete(path) } }
		embedded_image_paths.clear()
		for path, id in images { g_image_ids[path] = id; embedded_image_paths[path] = true }
		clip := rect(0, 0, f64(ctx.width), f64(ctx.height))
		for element in elements { render_element(ctx, element, 0, 0, clip, '') }
		for element in embedded_context { render_element(ctx, element, 0, 0, clip, '') }
		for path, _ in images { g_active_images[path] = true }
		prune_unmounted_state()
		update_tooltip(time.ticks())
		draw_tooltip(ctx)
		apply_clip(ctx, clip)
	}

	fn embedded_context_target(elements []Element, x f64, y f64, off_x f64, off_y f64) []MenuEntry {
		for i := elements.len - 1; i >= 0; i-- {
			el := elements[i]
			left := off_x + el.frame.x
			top := off_y + el.frame.y
			if el.hidden || x < left || y < top || x >= left + el.frame.width || y >= top + el.frame.height { continue }
			child_left := if el.kind == .scroll { left - (g_scroll_offsets_x[el.id] or { 0.0 }) } else { left }
			child_top := if el.kind == .scroll { top - (g_scroll_offsets[el.id] or { 0.0 }) } else { top }
			children := embedded_context_target(el.children, x, y, child_left, child_top)
			if children.len > 0 { return children }
			if el.enabled && el.menu.len > 0 { return el.menu }
		}
		return []MenuEntry{}
	}

	// Consume only UI2 targets or an active pointer capture. The document keeps
	// its keyboard and pointer dispatch when the pointer is outside this tree.
	pub fn embedded_elements_event(event &gg.Event) bool {
		if g_gg_app.ctx == unsafe { nil } { return false }
		if event.typ in [.key_down, .char] {
			if event.typ == .key_down && dispatch_key_event(event) { return true }
			if g_focused_field == '' { return false }
			if embedded_readonly[g_focused_field] or { false } {
				if event.typ == .char || event.key_code in [.backspace, .delete, .enter] || ((event.modifiers & 10) != 0 && event.key_code in [.x, .v, .z]) { return true }
			}
			on_event(event, g_gg_app)
			return true
		}
		x := f64(event.mouse_x)
		y := f64(event.mouse_y)
		if event.typ == .key_down && event.key_code == .escape && embedded_context.len > 0 {
			embedded_context.clear()
			return true
		}
		if event.typ == .mouse_down && event.mouse_button == .right {
			menu := embedded_context_target(embedded_elements, x, y, 0, 0)
			if menu.len == 0 { return false }
			ctx := g_gg_app.ctx
			width := f64(180)
			left := if x + width > ctx.width { f64(ctx.width) - width } else { x }
			height := f64(menu.len) * 28
			top := if y + height > ctx.height { f64(ctx.height) - height } else { y }
			mut rows := []Element{}
			for i, entry in menu {
				rows << button(entry.id, entry.title, rect(0, f64(i) * 28, width, 28), BoxStyle{ bg: 0xf7f7f7 }, TextStyle{ size: 12 })
			}
			embedded_context = [
				button('ui2-context-dismiss', '', rect(0, 0, f64(ctx.width), f64(ctx.height)), BoxStyle{ transparent: true }, TextStyle{}),
				view('ui2-context-menu', rect(left, top, width, height), BoxStyle{ bg: 0xf7f7f7 }, rows),
			]
			return true
		}
		if event.typ == .mouse_scroll && embedded_wheel_handler(x, y, f64(event.scroll_x), f64(event.scroll_y)) { return true }
		captured := g_touch.down
		target := hit_test(x, y)
		if event.typ in [.mouse_down, .mouse_up, .mouse_move, .mouse_scroll] {
			if target.action_id == '' && !captured && embedded_context.len == 0 {
				if event.typ == .mouse_move { on_event(event, g_gg_app) }
				return false
			}
			if event.typ == .mouse_down && event.mouse_button == .middle {
				g_event_handler(pointer_event_id('middle', target.action_id, x, y))
				return true
			}
			if event.typ in [.mouse_down, .mouse_up] && event.mouse_button != .left { return true }
			on_event(event, g_gg_app)
			if event.typ == .mouse_up { embedded_context.clear() }
			return true
		}
		if event.typ in [.mouse_leave, .unfocused, .suspended] {
			on_event(event, g_gg_app)
			if event.typ != .mouse_leave { embedded_context.clear() }
		}
		return false
	}
}
