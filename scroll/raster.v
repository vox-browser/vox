module main

import browsersettings
import layout
import math
import os
import processmetrics

fn C.native_scroll_tile_compositor_enabled(i32)
fn C.native_gpu_tile_compositor_enabled() int
fn C.native_gpu_canvas_can_present() int
fn C.native_begin_scroll_raster(u64, u64, f64, f64, f64, f64, int, &f64, &f64, int, int, i32) int
fn C.native_end_scroll_raster()
fn C.native_discard_scroll_raster()
fn C.native_set_scroll_damage_rects(rects &f32, count i32)
fn C.native_video_backdrop_ready(owner u64, scroll f64, x f64, y f64, width f64, height f64) int
fn C.native_capture_video_backdrop(x f64, y f64, width f64, height f64)
fn C.native_restore_video_backdrop(x f64, y f64, width f64, height f64)
fn C.native_reject_scroll_raster_frame()
fn C.native_discard_video_backdrops()
fn C.native_invalidate_video_backdrop(x f64, y f64, width f64, height f64)

// Same-binary control: repaint everything beneath a video for each new frame.
const disable_video_backdrops = os.getenv('VOX_DISABLE_VIDEO_BACKDROPS') != ''
const bound_pointwise_filter_outputs = os.getenv('VOX_BOUND_POINTWISE_FILTER_OUTPUTS') != ''
// Same-binary control: draw deferred viewport scrollbars through the GPU batch.
const gpu_scrollbar_leaves = os.getenv('VOX_GPU_SCROLLBAR_LEAVES') != ''

fn C.native_set_quartz_scrollbar_leaves(enabled int)

// Same-binary control: repaint the complete viewport on every zoomed frame.
const disable_zoomed_scroll_raster = os.getenv('VOX_DISABLE_ZOOMED_SCROLL_RASTER') != ''

fn C.native_bound_pointwise_filter_output(f64, f64, f64, f64)

fn (app &BrowserApp) pointwise_filter_output_bounds(index int) ?layout.LayoutRect {
	if app.document == unsafe { nil } || app.document.font_rendering_policy() != .chromium
		|| app.page_zoom != 1 || !app.scroll_raster_keys.valid
		|| app.scroll_raster_keys.document != u64(app.document.unique_id().value())
		|| app.scroll_raster_keys.paint_generation != app.paint_generation
		|| app.scroll_raster_keys.scroll != app.scroll_y
		|| app.scroll_raster_keys.width != app.viewport_width
		|| app.scroll_raster_keys.height != app.viewport_height
		|| app.scroll_raster_keys.keys.len != app.paint_commands.len
		|| index < 0 || index >= app.paint_commands.len
		|| !layout.scroll_raster_filter_is_pointwise(&app.paint_commands[index]) { return none }
	key := &app.scroll_raster_keys.keys[index]
	if key.group_end <= index || !key.has_ink || !scroll_raster_rect_valid(key.ink) { return none }
	return key.ink
}

fn (app &BrowserApp) bound_pointwise_filter_output(index int) {
	$if macos {
		if !bound_pointwise_filter_outputs { return }
		ink := app.pointwise_filter_output_bounds(index) or { return }
		C.native_bound_pointwise_filter_output(ink.x, ink.y + app.page_top(), ink.width, ink.height)
	}
}

struct ScrollRasterDamage {
mut:
	reused              bool
	separate_scrollbars bool
	delta               f64
	width               f64
	height              f64
	unoptimized         bool
	// Viewport-space rectangles beyond the exposed strip whose content changed
	// since the retained frame; they are clipped and repainted with the strip.
	rects []layout.LayoutRect
	// Per-command replay decision for the current command list, when reused.
	skip_plan []bool
	// Videos drawn over their retained backdrop instead of repainting beneath,
	// and how many of them replay restored before drawing.
	restores []ScrollRasterVideoRestore
	restored int
	// First command of the trailing viewport scrollbar run, replayed after
	// the ring stores the document pixels. Nested bars before it are content.
	scrollbar_start int
}

fn (mut app BrowserApp) begin_scroll_raster() ScrollRasterDamage {
	stage := processmetrics.begin_instruction_stage('scroll_raster_probe')
	defer { stage.finish() }
	mut work := app.scroll_raster_keys.storage.begin_frame()
	defer { work.finish() }
	mut damage := ScrollRasterDamage{
		width:       app.viewport_width
		height:      app.viewport_height
		unoptimized: os.getenv('VOX_DISABLE_SCROLL_RASTER_DAMAGE_OPTIMIZATIONS') != ''
	}
	$if macos {
		C.native_scroll_tile_compositor_enabled(i32(!browsersettings.current().disable_gpu_canvas))
		viewport := app.document.viewport_rect()
		// Page zoom projects the CSS-pixel commands at replay. Keys, content
		// damage and the skip plan stay in CSS pixels, exactly as without
		// zoom; only the rectangles handed to the native ring are scaled.
		zoom := app.page_zoom
		css := scroll_raster_css_space(app.scroll_y, damage.width, damage.height, zoom)
		// Keys remove the scroll translation the commands were recorded with,
		// including its f32 rounding under zoom.
		key_scroll := layout.scroll_raster_recorded_viewport_scroll(app.document)
		// Shared SVG pictures finish after the font layer; their deferred
		// pixels must not be captured before that layer has been published.
		// Zoomed frames never use the shared recording.
		eligible := zoom > 0 && (zoom == 1 || !disable_zoomed_scroll_raster)
			&& !app.paint_canvas_culling_disabled
			&& viewport.x == 0 && viewport.y == css.scroll
			&& !(zoom == 1 && chromium_shared_recording_supported(app.paint_commands, app.chromium_raster_plan))
			&& layout.viewport_scroll_raster_reusable(app.document, app.paint_commands,
				css.width, css.height)
		inline_scrollbars := eligible && C.native_gpu_tile_compositor_enabled() != 0
		damage.separate_scrollbars = eligible && !inline_scrollbars
		damage.scrollbar_start = scroll_raster_scrollbar_start(app.paint_commands)
		$if vox_scroll_raster_diagnostics ? {
			marker := os.getenv('VOX_SCROLL_RASTER_INPUT_MARKER')
			input := marker != '' && os.exists(marker)
			eprintln('VOX_SCROLL_RASTER_GATE input=${input} eligible=${eligible} zoom=${app.page_zoom} culling_disabled=${app.paint_canvas_culling_disabled} viewport=${viewport.x},${viewport.y} scroll=${app.scroll_y} shared=${chromium_shared_recording_supported(app.paint_commands, app.chromium_raster_plan)} commands=${app.paint_commands.len}')
		}
		document_id := u64(app.document.unique_id().value())
		revision := app.document.paint_content_revision()
		// Deferred layer pictures publish their leaf rasters after the ring
		// stores this frame, so a deferred frame can neither store nor reuse.
		// The draw loop disables deferral once content is known eligible.
		ring_eligible := eligible && !app.scroll_raster_frame_deferred
		app.scroll_raster_content_eligible = eligible
		mut keys := []ScrollRasterCommandKey{}
		mut rects := []layout.LayoutRect{}
		// Reuse requires the content diff to reconcile this frame with the
		// retained one: it is the only path that repaints content which does
		// not translate with the viewport, such as fixed or sticky boxes.
		mut allow_reuse := 0
		mut stats := ScrollRasterDiffStats{}
		if ring_eligible {
			keys = scroll_raster_frame_keys_with_scrollbars(app.paint_commands, key_scroll,
				app.overlay_scrollbars.paint_opacity, css.width, css.height, inline_scrollbars)
			app.mark_video_backdrop_keys(mut keys)
			app.mark_background_image_keys(mut keys)
			if disable_scroll_raster_content_damage {
				stats.fallback = 'content-damage-disabled'
			} else if content := scroll_raster_content_damage(&app.scroll_raster_keys, keys,
				document_id, key_scroll, css.width, css.height, mut stats)
			{
				rects = content.clone()
				allow_reuse = 1
				for restore in stats.restores {
					document := restore.document
					if C.native_video_backdrop_ready(document_id, app.scroll_y, document.x,
						document.y, document.width, document.height) != 0 {
						damage.restores << restore
					} else {
						rects << restore.rect
					}
				}
			}
		}
		mut clipped := rects.clone()
		for restore in damage.restores { clipped << restore.rect }
		flat := scroll_raster_flatten_rects(scroll_raster_view_rects(clipped, zoom))
		flat_data := if flat.len > 0 { unsafe { &f64(flat.data) } } else { unsafe { &f64(nil) } }
		// The draw loop immediately clears reused damage to opaque white before
		// replay, so retained pixels wholly inside it need not be restored.
		damage.reused = C.native_begin_scroll_raster(document_id, revision, app.scroll_y,
			app.page_top(), damage.width, damage.height, int(ring_eligible), &damage.delta, flat_data,
			clipped.len, allow_reuse, i32(1)) != 0
		if damage.reused {
			// The ring shifts by whole view pixels; the replay decisions below
			// read CSS-pixel commands.
			damage.delta /= zoom
			damage.width = css.width
			damage.height = css.height
			damage.rects = clipped
			mut region := scroll_raster_strip_region(damage.delta, damage.width, damage.height)
			region << rects
			damage.skip_plan = plan_scroll_raster_skips_with_restores(app.paint_commands, keys,
				region, damage.restores, damage.unoptimized)
			// Leaf rasters crop to the clip rectangles they intersect rather
			// than to the bounding box Quartz reports for all of them.
			for restore in damage.restores { region << restore.rect }
			canvas_rects := scroll_raster_canvas_rects(scroll_raster_view_rects(region, zoom),
				app.page_top())
			C.native_set_scroll_damage_rects(unsafe { &f32(canvas_rects.data) }, i32(region.len))
		} else {
			damage.restores = []ScrollRasterVideoRestore{}
			C.native_set_scroll_damage_rects(unsafe { nil }, i32(0))
		}
		if scroll_raster_damage_diagnostics && revision != scroll_raster_dumped_revision {
			scroll_raster_dumped_revision = revision
			mut kinds := []string{cap: app.paint_commands.len}
			for index in 0 .. app.paint_commands.len { kinds << app.paint_commands[index].kind }
			eprintln('VOX_SCROLL_RASTER_KINDS revision=${revision} kinds=${kinds.join(',')}')
		}
		if scroll_raster_damage_diagnostics {
			mut skipped := 0
			for value in damage.skip_plan {
				if value { skipped++ }
			}
			eprintln('VOX_SCROLL_RASTER_DAMAGE eligible=${eligible} deferred=${app.scroll_raster_frame_deferred} reused=${damage.reused} revision=${revision} previous_valid=${app.scroll_raster_keys.valid} delta=${damage.delta} changed=${stats.changed} rects=${rects.len} restores=${damage.restores.len}/${stats.restores.len} skipped=${skipped}/${app.paint_commands.len} fallback=${stats.fallback}')
		}
		// Retain this frame's identities only when its pixels enter the ring:
		// a frame that paints without eligibility leaves no reusable pixels.
		if ring_eligible {
			app.scroll_raster_keys = ScrollRasterKeyFrame{
				...app.scroll_raster_keys
				valid:    true
				document: document_id
				paint_generation: app.paint_generation
				scroll:   key_scroll
				width:    css.width
				height:   css.height
				keys:     keys
			}
		} else {
			app.scroll_raster_keys.valid = false
			app.scroll_raster_keys.keys = []ScrollRasterCommandKey{}
		}
	}
	return damage
}

// The viewport scroll and size in the CSS pixels of the recorded commands.
struct ScrollRasterCssSpace {
	scroll f64
	width  f64
	height f64
}

// The document viewport origin is the view scroll divided by the zoom, so the
// same division yields an exactly equal CSS scroll offset. Without zoom the
// values pass through unchanged.
fn scroll_raster_css_space(scroll f64, width f64, height f64, zoom f64) ScrollRasterCssSpace {
	if zoom == 1 || !(zoom > 0) { return ScrollRasterCssSpace{scroll, width, height} }
	return ScrollRasterCssSpace{scroll / zoom, width / zoom, height / zoom}
}

// CSS-pixel viewport rectangles as view-pixel rectangles for the native ring,
// widened to whole view pixels: GPU tiles accept only device-aligned damage,
// and widening keeps every partly covered pixel inside the repainted area.
fn scroll_raster_view_rects(rects []layout.LayoutRect, zoom f64) []layout.LayoutRect {
	if zoom == 1 { return rects }
	mut scaled := []layout.LayoutRect{cap: rects.len}
	for rect in rects {
		scaled << scroll_raster_snap_rect(layout.LayoutRect{rect.x * zoom, rect.y * zoom,
			rect.width * zoom, rect.height * zoom})
	}
	return scaled
}

// Whether this frame may draw its repainted area on the GPU canvas. A zoomed
// layout puts most rectangle edges on fractional device pixels, which the
// canvas declines; each decline reads the canvas back and the next GPU leaf
// uploads it again. Within a reused frame that traffic is limited to the
// exposed strip, but a complete zoomed repaint would move the entire viewport
// several times, so it rasterizes directly instead.
fn (damage &ScrollRasterDamage) gpu_canvas_permitted(zoom f64) bool {
	return zoom == 1 || damage.reused
}

fn (damage &ScrollRasterDamage) skips(command &layout.PaintCommand) bool {
	if !damage.reused { return false }
	// Checkbox fills can defer their pixels to the following border draw.
	// Keep both operations so culling cannot pair an underlay with a later box.
	if command.underlays_next || command.kind == 'stroke_rounded_rect' { return false }
	// Use retained image/clip geometry below, before decoding or uploading an
	// image whose pixels already came from the scroll cache.
	if damage.unoptimized && command.kind in ['draw_replaced_image', 'draw_background_image'] {
		return false
	}
	if damage.rects.len > 0 {
		if ink := layout.scroll_raster_leaf_ink_bounds(command) {
			if scroll_raster_ink_touches(ink, damage.rects) { return false }
		} else {
			return false
		}
	}
	if damage.delta == 0 { return true }
	top := if damage.delta < 0 {
		0.0
	} else {
		damage.height - math.min(damage.height, damage.delta)
	}
	return layout.paint_leaf_is_outside_canvas(command, 0, -top,
		damage.width, math.min(damage.height, math.abs(damage.delta)))
}

// Replay decision for one command index of a reused frame: the group-aware
// plan when it exists for this command list, otherwise the strip test.
fn (damage &ScrollRasterDamage) skips_index(commands []layout.PaintCommand, index int) bool {
	if !damage.reused { return false }
	if damage.skip_plan.len == commands.len { return damage.skip_plan[index] }
	return damage.skips(&commands[index])
}

// A video can be composited over its retained backdrop when it is outside
// every effect group, its raster layer draws immediately, and nothing later
// in paint order touches its damage rectangle.
fn (app &BrowserApp) mark_video_backdrop_keys(mut keys []ScrollRasterCommandKey) {
	// Backdrops are captured in view pixels from projected commands; zoomed
	// frames repaint a changed video frame as ordinary damage instead.
	if disable_video_backdrops || app.page_zoom != 1 || keys.len != app.paint_commands.len { return }
	mut depth := 0
	for index in 0 .. app.paint_commands.len {
		command := unsafe { &app.paint_commands[index] }
		if command.kind.starts_with('begin_') {
			depth++
			continue
		}
		if command.kind.starts_with('end_') {
			depth = math.max(depth - 1, 0)
			continue
		}
		if command.kind == 'draw_video' && scroll_raster_damage_diagnostics {
			owner := if index < app.chromium_raster_plan.command_layers.len { app.chromium_raster_plan.command_layers[index] } else { -1 }
			mut blocker := -1
			if keys[index].has_ink && scroll_raster_rect_valid(keys[index].ink) {
				area := [scroll_raster_snap_rect(scroll_raster_inflate(keys[index].ink, scroll_raster_damage_fringe))]
				for later in index + 1 .. keys.len {
					key := keys[later]
					if key.skip_diff || key.kind.starts_with('end_') { continue }
					if !key.has_ink || scroll_raster_ink_touches(key.ink, area) { blocker = later; break }
				}
            }
            eprintln('VOX_VIDEO_BACKDROP_GATE index=${index} depth=${depth} owner=${owner} source=${command.video_frame_source != none} ink=${keys[index].has_ink} blocker=${blocker}')
        }
		if command.kind != 'draw_video' || depth != 0 || command.video_frame_source == none
			|| !keys[index].has_ink || !scroll_raster_rect_valid(keys[index].ink)
			|| index >= app.chromium_raster_plan.command_layers.len {
			continue
		}
		layer := app.chromium_raster_plan.command_layers[index]
		if layer < 0 || chromium_shared_recording_layer_supported(app.paint_commands,
			app.chromium_raster_plan, layer)
			|| chromium_direct_image_layer_supported(app.paint_commands, app.chromium_raster_plan, layer) {
			continue
		}
		keys[index].video_backdrop = scroll_raster_nothing_above(keys, index)
	}
}

// A background image draws whatever the resource cache holds at replay time,
// so its command is identical before and after the image arrives. Mix the
// resource state into its key, and into every group around it whose output
// can spread beyond its ink, so an arrival damages pixels retained without it.
fn (app &BrowserApp) mark_background_image_keys(mut keys []ScrollRasterCommandKey) {
	if keys.len != app.paint_commands.len { return }
	mut begins := []int{}
	for index in 0 .. app.paint_commands.len {
		for begins.len > 0 && index > keys[begins.last()].group_end { begins.pop() }
		command := unsafe { &app.paint_commands[index] }
		if layout.scroll_raster_group_begin(command.kind) && keys[index].group_end > index {
			begins << index
			continue
		}
		if command.image_data == unsafe { nil } { continue }
		data := command.image_data
		if command.kind == 'draw_background_image' {
			if data.background_svg_document != none || data.background_static_svg_resource != none {
				continue
			}
		} else if command.kind == 'draw_replaced_image' {
			// A replaced image recorded before its request completed carries no
			// request pixels; replay resolves it by URL from the resource cache
			// like a background, so its arrival must damage the retained rows.
			native := app.ctx != unsafe { nil } && app.ctx.native_rendering
			if replaced_image_bitmap_for_renderer(command, native) != none { continue }
		} else {
			continue
		}
		token := app.background_image_resource_token(data.image_url)
		keys[index].hash = srk_mix(keys[index].hash, token)
		for begin in begins { keys[begin].hash = srk_mix(keys[begin].hash, token) }
	}
}

// Network images are fetched on first draw; until the response arrives the
// draw paints nothing. Local and data images decode synchronously.
fn (app &BrowserApp) background_image_resource_token(url string) u64 {
	if !url.starts_with('http://') && !url.starts_with('https://') { return 1 }
	resource := app.resource_cache[url] or { return 2 }
	if resource.error != '' { return 3 }
	return srk_int(srk_bool(4, resource.adblock_replacement), resource.body.len)
}

fn scroll_raster_nothing_above(keys []ScrollRasterCommandKey, index int) bool {
	area := [scroll_raster_snap_rect(scroll_raster_inflate(keys[index].ink, scroll_raster_damage_fringe))]
	for later in index + 1 .. keys.len {
		key := keys[later]
		if key.skip_diff || key.kind.starts_with('end_') { continue }
		if !key.has_ink || scroll_raster_ink_touches(key.ink, area) { return false }
	}
	return true
}

// A culled video paints no pixels, but underlying damage must still retire
// stale rows before a later visible frame can restore this backdrop.
fn (app &BrowserApp) invalidate_culled_video_backdrop(command &layout.PaintCommand) {
	$if macos {
		ink := scroll_raster_key_ink(command) or {
			C.native_discard_video_backdrops()
			return
		}
		whole := scroll_raster_snap_rect(scroll_raster_inflate(ink, scroll_raster_damage_fringe))
		// Updating validity reads no canvas pixels and creates no GPU barrier.
		C.native_invalidate_video_backdrop(whole.x, whole.y + app.scroll_y, whole.width, whole.height)
	}
}

// Just before a video draws: restore its backdrop when this frame planned
// that, otherwise capture the freshly painted pixels beneath it. A frame with
// restores does not capture: pixels under a restored rectangle are incomplete
// until its backdrop is copied in. Without a capture, rows repainted beneath
// the video may have changed, so they lose their validity.
fn (mut app BrowserApp) step_video_backdrop(index int, command &layout.PaintCommand,
	mut damage ScrollRasterDamage, page_y f32, window_height int) {
	$if macos {
		if !app.scroll_raster_keys.valid || index >= app.scroll_raster_keys.keys.len {
			return
		}
		ink := scroll_raster_key_ink(command) or {
			C.native_discard_video_backdrops()
			return
		}
		whole := scroll_raster_snap_rect(scroll_raster_inflate(ink, scroll_raster_damage_fringe))
		x, y := whole.x, whole.y + app.scroll_y
		if !app.scroll_raster_keys.keys[index].video_backdrop {
			C.native_invalidate_video_backdrop(x, y, whole.width, whole.height)
			return
		}
		app.flush_rounded_rect_underlay(0, page_y, window_height)
		if damage.reused && damage.restores.any(it.index == index) {
			// Planning verified every row. If the copy still fails, this frame
			// is not stored, so the next one repaints the viewport completely.
			C.native_restore_video_backdrop(x, y, whole.width, whole.height)
			damage.restored++
		} else if damage.restores.len == 0 {
			C.native_capture_video_backdrop(x, y, whole.width, whole.height)
		} else {
			C.native_invalidate_video_backdrop(x, y, whole.width, whole.height)
		}
	}
}

// Raster eligibility defers only the trailing viewport scrollbars. Find that
// suffix without walking the document commands again after painting it.
// Viewport rectangles as x, y, width, height in top-left canvas points.
fn scroll_raster_canvas_rects(region []layout.LayoutRect, page_top f64) []f32 {
	mut values := []f32{cap: region.len * 4}
	for rect in region {
		values << f32(rect.x)
		values << f32(page_top + rect.y)
		values << f32(rect.width)
		values << f32(rect.height)
	}
	return values
}

fn scroll_raster_scrollbar_start(commands []layout.PaintCommand) int {
	return layout.scroll_raster_trailing_scrollbar_start(commands)
}

fn (mut app BrowserApp) draw_scroll_raster_scrollbars(page_y f32, window_height int) {
	start := if os.getenv('VOX_DISABLE_SCROLLBAR_TAIL_REPLAY') != '' {
		0
	} else {
		scroll_raster_scrollbar_start(app.paint_commands)
	}
	// The document replay projected the bars by the page zoom; draw them at
	// the same place and size.
	mut indices := []int{}
	mut commands := []layout.PaintCommand{}
	for index in start .. app.paint_commands.len {
		if app.paint_commands[index].scrollbar_axis == '' { continue }
		indices << index
		commands << app.zoomed_paint_command(app.paint_commands[index])
	}
	mut gpu_overlay := false
	mut quartz := false
	$if macos {
		// Quartz fills these few pixels without a GPU round trip. The GPU
		// batch remains for leaves Quartz does not handle, and as a control.
		quartz = app.ctx.native_rendering && !gpu_scrollbar_leaves
			&& scrollbar_leaves_quartz_drawable(commands)
		if quartz {
			C.native_set_quartz_scrollbar_leaves(1)
		} else if app.ctx.native_rendering && gpu_scrollbar_batch_enabled {
			gpu_overlay = gpu_canvas_overlay_begin(scrollbar_gpu_damage_rects(commands, 0, page_y))
		}
	}
	defer {
		$if macos {
			if gpu_overlay { C.native_gpu_canvas_end() }
			if quartz { C.native_set_quartz_scrollbar_leaves(0) }
		}
	}
	for position, command in commands {
		index := indices[position]
		if index < app.chromium_raster_plan.command_layers.len {
			app.select_chromium_raster_layer(app.chromium_raster_plan.command_layers[index])
		}
		if gpu_overlay { gpu_canvas_command_supported(&command) }
		app.draw_command(command, 0, page_y, window_height)
	}
}

// Rectangles, rounded rectangles and their outlines, which the native rounded
// rectangle and solid fill draw with Quartz paths.
fn scrollbar_leaves_quartz_drawable(commands []layout.PaintCommand) bool {
	return commands.len > 0
		&& commands.all(it.kind in ['fill_rect', 'fill_rounded_rect', 'stroke_rounded_rect'])
}

// Only the late scrollbar leaves enter this pass. Their conservative visual
// extents include stroke fringes; merge overlaps to keep the native tile count
// bounded. The document ring has already stored pixels without these overlays.
fn scrollbar_gpu_damage_rects(commands []layout.PaintCommand, start int, page_y f32) []f32 {
	mut regions := []layout.LayoutRect{}
	for index in start .. commands.len {
		command := &commands[index]
		if command.scrollbar_axis == '' { continue }
		if command.kind !in ['fill_rect', 'fill_rounded_rect', 'stroke_rounded_rect'] { return []f32{} }
		ink := layout.scroll_raster_leaf_ink_bounds(command) or { return []f32{} }
		mut rect := layout.LayoutRect{ink.x - 2, ink.y + page_y - 2, ink.width + 4, ink.height + 4}
		for region_index := 0; region_index < regions.len; {
			other := regions[region_index]
			if rect.x <= other.x + other.width && rect.x + rect.width >= other.x
				&& rect.y <= other.y + other.height && rect.y + rect.height >= other.y {
				left := math.min(rect.x, other.x)
				top := math.min(rect.y, other.y)
				right := math.max(rect.x + rect.width, other.x + other.width)
				bottom := math.max(rect.y + rect.height, other.y + other.height)
				rect = layout.LayoutRect{left, top, right - left, bottom - top}
				regions.delete(region_index)
				region_index = 0
			} else { region_index++ }
		}
		regions << rect
		if regions.len > 8 { return []f32{} }
	}
	mut rects := []f32{cap: regions.len * 4}
	for rect in regions { rects << [f32(rect.x), f32(rect.y), f32(rect.width), f32(rect.height)] }
	return rects
}
