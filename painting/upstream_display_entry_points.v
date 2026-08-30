module painting

// DisplayListRecordingContext owns the conversion and recorder state that the
// C++ implementation keeps beside its native painter. Backend handles remain
// opaque, while all geometry and command ordering stays executable in V.
pub struct DisplayListRecordingContext {
pub mut:
	recorder                       DisplayListRecorder = new_display_list_recorder(new_accumulated_visual_context_tree())
	css_viewport                   Rect
	device_viewport                IntRect
	device_scale                   f64 = 1.0
	show_line_box_borders          bool
	paint_overlay                  bool
	svg_matrix                     Affine = Affine{}
	draw_svg_geometry_for_clip     bool
	current_paint_generation_id    u64
}

pub fn DisplayListRecordingContext.create(device_scale f64, viewport Rect) !DisplayListRecordingContext {
	converter := new_device_pixel_converter(device_scale)!
	return DisplayListRecordingContext{
		css_viewport: viewport
		device_viewport: converter.enclosing_device_rect(viewport)
		device_scale: device_scale
	}
}

pub fn (context DisplayListRecordingContext) display_list_recorder() DisplayListRecorder { return context.recorder }
pub fn (context DisplayListRecordingContext) palette() string { return 'default' }
pub fn (context DisplayListRecordingContext) should_show_line_box_borders() bool { return context.show_line_box_borders }
pub fn (mut context DisplayListRecordingContext) set_should_show_line_box_borders(value bool) { context.show_line_box_borders = value }
pub fn (context DisplayListRecordingContext) should_paint_overlay() bool { return context.paint_overlay }
pub fn (mut context DisplayListRecordingContext) set_should_paint_overlay(value bool) { context.paint_overlay = value }
pub fn (context DisplayListRecordingContext) device_viewport_rect() IntRect { return context.device_viewport }
pub fn (mut context DisplayListRecordingContext) set_device_viewport_rect(rect IntRect) { context.device_viewport = rect }
pub fn (mut context DisplayListRecordingContext) set_svg_transform(transform Affine) { context.svg_matrix = transform }
pub fn (context DisplayListRecordingContext) svg_transform() Affine { return context.svg_matrix }
pub fn (context DisplayListRecordingContext) draw_svg_geometry_for_clip_path() bool { return context.draw_svg_geometry_for_clip }
pub fn (mut context DisplayListRecordingContext) set_draw_svg_geometry_for_clip_path(value bool) { context.draw_svg_geometry_for_clip = value }
pub fn (context DisplayListRecordingContext) clone() DisplayListRecordingContext { return context }
pub fn (context DisplayListRecordingContext) css_viewport_rect() Rect { return context.css_viewport }
pub fn (context DisplayListRecordingContext) device_pixel_converter() DevicePixelConverter { return DevicePixelConverter{device_pixels_per_css_pixel: context.device_scale} }
pub fn (context DisplayListRecordingContext) device_pixels_per_css_pixel() f64 { return context.device_scale }
pub fn (context DisplayListRecordingContext) chrome_metrics() ChromeMetrics { return new_chrome_metrics(context.device_scale) or { ChromeMetrics{} } }
pub fn (context DisplayListRecordingContext) paint_generation_id() u64 { return context.current_paint_generation_id }
pub fn (context DisplayListRecordingContext) rounded_device_pixels(value f64) int { return context.device_pixel_converter().rounded_device_pixels(value) }
pub fn (context DisplayListRecordingContext) enclosing_device_pixels(value f64) int { return context.device_pixel_converter().enclosing_device_pixels(value) }
pub fn (context DisplayListRecordingContext) floored_device_pixels(value f64) int { return context.device_pixel_converter().floored_device_pixels(value) }
pub fn (context DisplayListRecordingContext) rounded_device_point(point Point) IntPoint { return context.device_pixel_converter().rounded_device_point(point) }
pub fn (context DisplayListRecordingContext) floored_device_point(point Point) IntPoint { return context.device_pixel_converter().floored_device_point(point) }
pub fn (context DisplayListRecordingContext) enclosing_device_rect(rect Rect) IntRect { return context.device_pixel_converter().enclosing_device_rect(rect) }
pub fn (context DisplayListRecordingContext) rounded_device_rect(rect Rect) IntRect { return context.device_pixel_converter().rounded_device_rect(rect) }
pub fn (context DisplayListRecordingContext) enclosing_device_size(size Size) IntSize { return context.device_pixel_converter().enclosing_device_size(size) }
pub fn (context DisplayListRecordingContext) rounded_device_size(size Size) IntSize { return context.device_pixel_converter().rounded_device_size(size) }
pub fn (context DisplayListRecordingContext) scale_to_css_pixels(value int) f64 { return context.device_pixel_converter().scale_to_css_pixels(value) }
pub fn (context DisplayListRecordingContext) scale_to_css_point(point IntPoint) Point { return context.device_pixel_converter().scale_to_css_point(point) }
pub fn (context DisplayListRecordingContext) scale_to_css_size(size IntSize) Size { return Size{context.scale_to_css_pixels(size.width), context.scale_to_css_pixels(size.height)} }
pub fn (context DisplayListRecordingContext) scale_to_css_rect(rect IntRect) Rect { return context.device_pixel_converter().scale_to_css_rect(rect) }

pub fn (converter DevicePixelConverter) device_pixels_per_css_pixel() f64 { return converter.device_pixels_per_css_pixel }

pub struct CommandCapture {
pub mut:
	commands []DisplayListCommand
}

pub fn (mut capture CommandCapture) take() []DisplayListCommand {
	result := capture.commands.clone()
	capture.commands.clear()
	return result
}

pub fn (mut recorder DisplayListRecorder) begin_command_capture() bool { return recorder.begin_capture() }
pub fn (mut recorder DisplayListRecorder) end_capture() []DisplayListCommand { return recorder.take_capture() }
pub fn (recorder DisplayListRecorder) accumulated_visual_context() int { return recorder.accumulated_context_index }
pub fn (mut recorder DisplayListRecorder) set_accumulated_visual_context(index int) { recorder.accumulated_context_index = index }
pub fn (mut recorder DisplayListRecorder) replay_cached_commands(commands []DisplayListCommand) { recorder.replay_cached(commands) }
pub fn (mut recorder DisplayListRecorder) paint_nested_display_list(id string, rect IntRect) bool { return recorder.append(PaintNestedDisplayList{id, rect}) }
pub fn (mut recorder DisplayListRecorder) fill_rect_with_linear_gradient(command PaintLinearGradient) bool { return recorder.paint_linear_gradient(command) }
pub fn (mut recorder DisplayListRecorder) fill_rect_with_conic_gradient(command PaintConicGradient) bool { return recorder.paint_conic_gradient(command) }
pub fn (mut recorder DisplayListRecorder) fill_rect_with_radial_gradient(command PaintRadialGradient) bool { return recorder.paint_radial_gradient(command) }
pub fn (mut recorder DisplayListRecorder) draw_scaled_immutable_bitmap(command DrawScaledBitmap) bool { return recorder.draw_scaled_bitmap(command) }
pub fn (mut recorder DisplayListRecorder) draw_repeated_immutable_bitmap(command DrawRepeatedBitmap) bool { return recorder.draw_repeated_bitmap(command) }
pub fn (mut recorder DisplayListRecorder) draw_text(id string, rect IntRect, color Color) bool { return recorder.draw_glyph_run(DrawGlyphRun{id, rect, Point{}, color, .horizontal}) }
pub fn (mut recorder DisplayListRecorder) draw_glyph_run(command DrawGlyphRun) bool { return if command.rect.is_empty() || command.color.a == 0 { false } else { recorder.append(command) } }
pub fn (mut recorder DisplayListRecorder) fill_rect_with_rounded_corners(command FillRoundedRect) bool { return recorder.fill_rounded_rect(command) }

pub fn DisplayList.create(tree AccumulatedVisualContextTree) DisplayList { return DisplayList{visual_context_tree: tree} }
pub fn (list DisplayList) surface() string { return 'display-list' }
pub fn (list DisplayList) visual_context_tree() AccumulatedVisualContextTree { return list.visual_context_tree }
pub fn (list DisplayList) commands() []DisplayListItem { return list.commands.clone() }

// DisplayListPlayer is the deterministic side of DisplayListPlayerSkia. It
// records the exact dispatch order; rasterization is intentionally the native
// backend boundary.
pub struct DisplayListPlayer {
pub mut:
	operations []string
	save_depth int
	translation IntPoint
	clip ?IntRect
}

pub fn DisplayListPlayer.create() DisplayListPlayer { return DisplayListPlayer{} }
pub fn (player DisplayListPlayer) surface() string { return 'native-surface' }
pub fn (mut player DisplayListPlayer) record(name string) { player.operations << name }
pub fn (mut player DisplayListPlayer) flush() { player.record('flush') }
pub fn (mut player DisplayListPlayer) draw_glyph_run(command DrawGlyphRun) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) fill_rect(command FillRect) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) draw_external_content(command DrawExternalContent) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) draw_scaled_immutable_bitmap(command DrawScaledBitmap) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) draw_repeated_immutable_bitmap(command DrawRepeatedBitmap) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) add_clip_rect(command AddClipRect) { player.clip = command.rect; player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) save() { player.save_depth++; player.record('Save') }
pub fn (mut player DisplayListPlayer) save_layer() { player.save_depth++; player.record('SaveLayer') }
pub fn (mut player DisplayListPlayer) restore() { if player.save_depth > 0 { player.save_depth-- }; player.record('Restore') }
pub fn (mut player DisplayListPlayer) translate(delta IntPoint) { player.translation = IntPoint{player.translation.x + delta.x, player.translation.y + delta.y}; player.record('Translate') }
pub fn (mut player DisplayListPlayer) paint_linear_gradient(command PaintLinearGradient) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) paint_outer_box_shadow(command PaintOuterBoxShadow) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) paint_inner_box_shadow(command PaintInnerBoxShadow) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) paint_text_shadow(command PaintTextShadow) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) fill_rect_with_rounded_corners(command FillRoundedRect) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) fill_path(command FillPath) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) stroke_path(command StrokePath) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) draw_ellipse(command DrawEllipse) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) fill_ellipse(command FillEllipse) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) draw_line(command DrawLine) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) apply_backdrop_filter(command ApplyBackdropFilter) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) draw_rect(command DrawRect) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) paint_radial_gradient(command PaintRadialGradient) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) paint_conic_gradient(command PaintConicGradient) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) add_rounded_rect_clip(command AddRoundedRectClip) { player.clip = command.border_rect; player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) paint_nested_display_list(command PaintNestedDisplayList) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) paint_scrollbar(command PaintScrollbar) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) apply_effects(command ApplyEffects) { player.record(command.dump()) }
pub fn (mut player DisplayListPlayer) apply_transform(transform Affine) { _ = transform; player.record('ApplyTransform') }
pub fn (mut player DisplayListPlayer) add_clip_path(path ClipPathVisualData) { player.clip = path.bounding_rect; player.record('AddClipPath') }
pub fn (player DisplayListPlayer) would_be_fully_clipped_by_painter(rect IntRect) bool { return if clip := player.clip { !clip.intersects(rect) } else { false } }
pub fn (mut player DisplayListPlayer) execute(list DisplayList, snapshot ScrollStateSnapshot, clip IntRect) []PlaybackAction { return player.execute_impl(list, snapshot, clip) }
pub fn (mut player DisplayListPlayer) execute_display_list_into_surface(list DisplayList, snapshot ScrollStateSnapshot, clip IntRect) []PlaybackAction { return player.execute_impl(list, snapshot, clip) }
pub fn (mut player DisplayListPlayer) execute_impl(list DisplayList, snapshot ScrollStateSnapshot, clip IntRect) []PlaybackAction {
	actions := list.playback_plan(snapshot, clip)
	for action in actions { player.record(action.kind) }
	return actions
}

pub fn (command AddClipRect) bounding_rect() ?IntRect { return command.rect }
pub fn (command AddRoundedRectClip) bounding_rect() ?IntRect { return command.border_rect }
pub fn (command PaintOuterBoxShadow) bounding_rect() ?IntRect { return command_bounding_rect(command) }
pub fn (command PaintInnerBoxShadow) bounding_rect() ?IntRect { return command_bounding_rect(command) }
pub fn (command DrawGlyphRun) bounding_rect() ?IntRect { return command_bounding_rect(command) }
pub fn (command FillRect) bounding_rect() ?IntRect { return command.rect }
pub fn (command DrawScaledBitmap) bounding_rect() ?IntRect { return command.clip_rect }
pub fn (command DrawRepeatedBitmap) bounding_rect() ?IntRect { return command.clip_rect }
pub fn (command DrawExternalContent) bounding_rect() ?IntRect { return command.destination }
pub fn (command PaintLinearGradient) bounding_rect() ?IntRect { return command.rect }
pub fn (command PaintRadialGradient) bounding_rect() ?IntRect { return command.rect }
pub fn (command PaintConicGradient) bounding_rect() ?IntRect { return command.rect }
pub fn (command PaintTextShadow) bounding_rect() ?IntRect { return command_bounding_rect(command) }
pub fn (command FillRoundedRect) bounding_rect() ?IntRect { return command.rect }
pub fn (command FillPath) bounding_rect() ?IntRect { return command.path_bounding_rect }
pub fn (command StrokePath) bounding_rect() ?IntRect { return command.path_bounding_rect }
pub fn (command DrawEllipse) bounding_rect() ?IntRect { return command.rect }
pub fn (command FillEllipse) bounding_rect() ?IntRect { return command.rect }
pub fn (command DrawLine) bounding_rect() ?IntRect { return command_bounding_rect(command) }
pub fn (command ApplyBackdropFilter) bounding_rect() ?IntRect { return command.backdrop_region }
pub fn (command DrawRect) bounding_rect() ?IntRect { return command.rect }
pub fn (command PaintNestedDisplayList) bounding_rect() ?IntRect { return command.rect }
pub fn (command AddClipRect) is_clip() bool { return true }
pub fn (command AddRoundedRectClip) is_clip() bool { return true }

pub fn (command AddClipRect) dump() string { return 'AddClipRect ${command.rect}' }
pub fn (command AddRoundedRectClip) dump() string { return 'AddRoundedRectClip ${command.border_rect}' }
pub fn (command PaintOuterBoxShadow) dump() string { return 'PaintOuterBoxShadow ${command.shadow_rect}' }
pub fn (command PaintInnerBoxShadow) dump() string { return 'PaintInnerBoxShadow ${command.device_content_rect}' }
pub fn (command DrawGlyphRun) dump() string { return 'DrawGlyphRun ${command.rect}' }
pub fn (command FillRect) dump() string { return 'FillRect ${command.rect}' }
pub fn (command DrawScaledBitmap) dump() string { return 'DrawScaledImmutableBitmap ${command.destination}' }
pub fn (command DrawRepeatedBitmap) dump() string { return 'DrawRepeatedImmutableBitmap ${command.destination}' }
pub fn (command DrawExternalContent) dump() string { return 'DrawExternalContent ${command.destination}' }
pub fn (command Save) dump() string { return 'Save' }
pub fn (command SaveLayer) dump() string { return 'SaveLayer' }
pub fn (command Restore) dump() string { return 'Restore' }
pub fn (command Translate) dump() string { return 'Translate ${command.delta}' }
pub fn (command PaintLinearGradient) dump() string { return 'PaintLinearGradient ${command.rect}' }
pub fn (command PaintRadialGradient) dump() string { return 'PaintRadialGradient ${command.rect}' }
pub fn (command PaintConicGradient) dump() string { return 'PaintConicGradient ${command.rect}' }
pub fn (command PaintTextShadow) dump() string { return 'PaintTextShadow ${command.shadow_bounding_rect}' }
pub fn (command FillRoundedRect) dump() string { return 'FillRectWithRoundedCorners ${command.rect}' }
pub fn (command FillPath) dump() string { return 'FillPath ${command.path_bounding_rect}' }
pub fn (command StrokePath) dump() string { return 'StrokePath ${command.path_bounding_rect}' }
pub fn (command DrawEllipse) dump() string { return 'DrawEllipse ${command.rect}' }
pub fn (command FillEllipse) dump() string { return 'FillEllipse ${command.rect}' }
pub fn (command DrawLine) dump() string { return 'DrawLine ${command.from} ${command.to}' }
pub fn (command ApplyBackdropFilter) dump() string { return 'ApplyBackdropFilter ${command.backdrop_region}' }
pub fn (command DrawRect) dump() string { return 'DrawRect ${command.rect}' }
pub fn (command PaintNestedDisplayList) dump() string { return 'PaintNestedDisplayList ${command.rect}' }
pub fn (command PaintScrollbar) dump() string { return 'PaintScrollBar ${command.thumb_rect}' }
pub fn (command ApplyEffects) dump() string { return 'ApplyEffects opacity=${command.opacity}' }

pub fn ExternalContentSource.create(bitmap_id ?string) ExternalContentSource { return ExternalContentSource{bitmap_id: bitmap_id} }
pub fn (source ExternalContentSource) current_bitmap() ?string { return source.bitmap_id }
