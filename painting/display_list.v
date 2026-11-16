module painting

import dom
import math
import platform

pub enum CornerClip {
	inside
	outside
}

pub enum ScalingMode {
	none_
	bilinear
	bilinear_mipmap
	nearest_neighbor
}

pub enum Orientation {
	horizontal
	vertical
}

pub enum TextAlignment {
	center_left
	center
	center_right
}

pub enum WindingRule {
	even_odd
	nonzero
}

pub enum LineCap {
	butt
	round
	square
}

pub enum LineJoin {
	miter
	round
	bevel
}

pub struct DrawGlyphRun {
pub:
	glyph_run_id        string
	glyph_run           ?&platform.GlyphRun
	rect                IntRect
	glyph_bounding_rect IntRect
	translation         Point
	color               Color
	orientation         Orientation
	scale               f64 = 1.0
	font_smoothing      u8
}

pub struct FillRect {
pub:
	rect  IntRect
	color Color
}

pub struct DrawScaledDecodedImageFrame {
pub:
	destination IntRect
	clip_rect   IntRect
	frame       ?&dom.DecodedImageFrame_
	bitmap_id   string
	scaling     ScalingMode
}

pub struct DrawRepeatedDecodedImageFrame {
pub:
	destination IntRect
	clip_rect   IntRect
	frame       ?&dom.DecodedImageFrame_
	bitmap_id   string
	scaling     ScalingMode
	repeat_x    bool
	repeat_y    bool
}

pub struct DrawExternalContent {
pub:
	destination IntRect
	source_id   string
	scaling     ScalingMode
}

pub struct DrawVideoFrameSource {
pub:
	destination IntRect
	source      &VideoFrameSource = unsafe { nil }
	scaling     ScalingMode
}

pub struct Save {}

pub struct SaveLayer {}

pub struct Restore {}

pub struct Translate {
pub:
	delta IntPoint
}

pub struct AddClipRect {
pub:
	rect IntRect
}

pub struct PaintLinearGradient {
pub:
	rect IntRect
	data LinearGradientData
}

pub struct PaintRadialGradient {
pub:
	rect   IntRect
	data   RadialGradientData
	center IntPoint
	size   IntSize
}

pub struct PaintConicGradient {
pub:
	rect     IntRect
	data     ConicGradientData
	position IntPoint
}

pub struct PaintOuterBoxShadow {
pub:
	color                Color
	blur_radius          int
	device_content_rect  IntRect
	content_corner_radii CornerRadii
	shadow_rect          IntRect
	shadow_corner_radii  CornerRadii
}

pub struct PaintInnerBoxShadow {
pub:
	color                     Color
	blur_radius               int
	device_content_rect       IntRect
	content_corner_radii      CornerRadii
	outer_shadow_rect         IntRect
	inner_shadow_rect         IntRect
	inner_shadow_corner_radii CornerRadii
}

pub fn (command PaintOuterBoxShadow) bounding_rect() IntRect {
	distance := command.blur_radius * 2
	return command.shadow_rect.inflated(distance, distance, distance, distance)
}

pub fn (command PaintInnerBoxShadow) bounding_rect() IntRect {
	return command.device_content_rect
}

pub fn (command PaintOuterBoxShadow) dump() string {
	return ' content_rect=${command.device_content_rect} shadow_rect=${command.shadow_rect} blur_radius=${command.blur_radius} color=${command.color}'
}

pub fn (command PaintInnerBoxShadow) dump() string {
	return ' content_rect=${command.device_content_rect} outer_shadow_rect=${command.outer_shadow_rect} inner_shadow_rect=${command.inner_shadow_rect} blur_radius=${command.blur_radius} color=${command.color}'
}

pub struct PaintTextShadow {
pub:
	glyph_run_id         string
	shadow_bounding_rect IntRect
	rect                 IntRect
	translation          Point
	blur_radius          int
	color                Color
	orientation          Orientation
	font_smoothing       u8
}

pub struct FillRoundedRect {
pub:
	rect         IntRect
	color        Color
	corner_radii CornerRadii
}

pub struct FillPath {
pub:
	path_id            string
	path_bounding_rect IntRect
	path               ClipPathVisualData
	opacity            f64 = 1.0
	color              Color
	winding_rule       WindingRule
	anti_alias         bool = true
}

pub struct StrokePath {
pub:
	path_id            string
	path_bounding_rect IntRect
	cap_style          LineCap
	join_style         LineJoin
	miter_limit        f64
	dash_array         []f64
	dash_offset        f64
	opacity            f64 = 1.0
	color              Color
	thickness          f64
	anti_alias         bool = true
}

pub struct DrawEllipse {
pub:
	rect      IntRect
	color     Color
	thickness int
}

pub struct FillEllipse {
pub:
	rect  IntRect
	color Color
}

pub struct DrawLine {
pub:
	from            IntPoint
	to              IntPoint
	color           Color
	thickness       int = 1
	line_style      LineStyle
	alternate_color Color
}

pub struct ApplyBackdropFilter {
pub:
	backdrop_region IntRect
	corner_radii    CornerRadii
	filter          ?GfxFilter
}

pub struct DrawRect {
pub:
	rect  IntRect
	color Color
	rough bool
}

pub struct AddRoundedRectClip {
pub:
	corner_radii CornerRadii
	border_rect  IntRect
	corner_clip  CornerClip
}

pub struct PaintNestedDisplayList {
pub:
	display_list_id string
	rect            IntRect
}

pub struct PaintScrollbar {
pub:
	scroll_frame_index int
	gutter_rect        IntRect
	thumb_rect         IntRect
	scroll_size        f64
	thumb_color        Color
	track_color        Color
	vertical           bool
}

pub enum MaskKind {
	alpha
	luminance
}

pub struct ApplyEffects {
pub:
	opacity   f64 = 1.0
	operator  CompositingAndBlendingOperator
	filter    ?GfxFilter
	mask_kind ?MaskKind
}

pub fn (command DrawGlyphRun) bounding_rect() IntRect {
	return command.glyph_bounding_rect
}

pub fn (command DrawGlyphRun) dump() string {
	return ' rect=${command.rect} glyph_bounding_rect=${command.glyph_bounding_rect} translation=${command.translation} color=${command.color}'
}

pub fn glyph_run_device_bounding_rect(glyph_run &platform.GlyphRun, baseline_start Point,
	scale f64) IntRect {
	bounds := glyph_run.bounding_box()
	return IntRect{
		x: int(math.round_to_even(f64(bounds.x) * scale + baseline_start.x))
		y: int(math.round_to_even(f64(bounds.y) * scale + baseline_start.y))
		width: int(math.round_to_even(f64(bounds.width) * scale))
		height: int(math.round_to_even(f64(bounds.height) * scale))
	}
}

// The player shifts the horizontal run right by the fragment's width and
// rotates it clockwise around the fragment's top-left corner.
fn vertical_glyph_bounds(horizontal_bounds IntRect, fragment_rect IntRect) IntRect {
	return IntRect{
		x: fragment_rect.x + fragment_rect.width
			- (horizontal_bounds.y + horizontal_bounds.height - fragment_rect.y)
		y: fragment_rect.y + horizontal_bounds.x - fragment_rect.x
		width: horizontal_bounds.height
		height: horizontal_bounds.width
	}
}

pub fn (command FillRect) bounding_rect() IntRect {
	return command.rect
}

pub fn (command FillRect) dump() string {
	return ' rect=${command.rect} color=${command.color}'
}

pub fn (command DrawScaledDecodedImageFrame) bounding_rect() IntRect {
	return command.clip_rect
}

pub fn (command DrawScaledDecodedImageFrame) dump() string {
	return ' dst_rect=${command.destination} clip_rect=${command.clip_rect}'
}

pub fn (command DrawRepeatedDecodedImageFrame) bounding_rect() IntRect {
	return command.clip_rect
}

pub fn (command DrawRepeatedDecodedImageFrame) dump() string {
	return ' dst_rect=${command.destination} clip_rect=${command.clip_rect}'
}

pub fn (command DrawExternalContent) bounding_rect() IntRect {
	return command.destination
}

pub fn (command DrawExternalContent) dump() string {
	return ' dst_rect=${command.destination}'
}

pub fn (command DrawVideoFrameSource) bounding_rect() IntRect {
	return command.destination
}

pub fn (command DrawVideoFrameSource) dump() string {
	return ' dst_rect=${command.destination}'
}

pub fn (_ Save) dump() string {
	return ''
}

pub fn (_ SaveLayer) dump() string {
	return ''
}

pub fn (_ Restore) dump() string {
	return ''
}

pub fn (command Translate) dump() string {
	return ' delta=${command.delta}'
}

pub fn (command AddClipRect) bounding_rect() IntRect {
	return command.rect
}

pub fn (command AddClipRect) dump() string {
	return ' rect=${command.rect}'
}

pub fn (command AddClipRect) is_clip() bool {
	return true
}

pub fn (command PaintLinearGradient) bounding_rect() IntRect {
	return command.rect
}

pub fn (command PaintLinearGradient) dump() string {
	return ' rect=${command.rect}'
}

pub fn (command PaintRadialGradient) bounding_rect() IntRect {
	return command.rect
}

pub fn (command PaintRadialGradient) dump() string {
	return ' rect=${command.rect} center=${command.center} size=${command.size}'
}

pub fn (command PaintConicGradient) bounding_rect() IntRect {
	return command.rect
}

pub fn (command PaintConicGradient) dump() string {
	return ' rect=${command.rect} position=${command.position} angle=${command.data.start_angle}'
}

pub fn (command PaintTextShadow) bounding_rect() IntRect {
	return command.shadow_bounding_rect
}

pub fn (command PaintTextShadow) dump() string {
	return ' shadow_rect=${command.shadow_bounding_rect} rect=${command.rect} translation=${command.translation} blur_radius=${command.blur_radius} color=${command.color} orientation=${command.orientation}'
}

pub fn (command FillRoundedRect) bounding_rect() IntRect {
	return command.rect
}

pub fn (command FillRoundedRect) dump() string {
	return ' rect=${command.rect} color=${command.color}'
}

pub fn (command FillPath) bounding_rect() IntRect {
	return command.path_bounding_rect
}

pub fn (command FillPath) dump() string {
	return ' path_bounding_rect=${command.path_bounding_rect}'
}

pub fn (command StrokePath) bounding_rect() IntRect {
	return command.path_bounding_rect
}

pub fn (_ StrokePath) dump() string {
	return ''
}

pub fn (command DrawEllipse) dump() string {
	return ' rect=${command.rect} color=${command.color} thickness=${command.thickness}'
}

pub fn (command DrawEllipse) bounding_rect() IntRect {
	return command.rect
}

pub fn (command FillEllipse) bounding_rect() IntRect {
	return command.rect
}

pub fn (command FillEllipse) dump() string {
	return ' rect=${command.rect} color=${command.color}'
}

pub fn (command DrawLine) bounding_rect() IntRect {
	return int_rect_from_two_points(command.from, command.to).inflated(command.thickness, command.thickness, command.thickness, command.thickness)
}

pub fn (command DrawLine) dump() string {
	return ' from=${command.from} to=${command.to} color=${command.color} thickness=${command.thickness}'
}

pub fn (command ApplyBackdropFilter) bounding_rect() IntRect {
	return command.backdrop_region
}

pub fn (command ApplyBackdropFilter) dump() string {
	return ' backdrop_region=${command.backdrop_region}'
}

pub fn (command DrawRect) bounding_rect() IntRect {
	return command.rect
}

pub fn (command DrawRect) dump() string {
	return ' rect=${command.rect} color=${command.color} rough=${command.rough}'
}

pub fn (command AddRoundedRectClip) bounding_rect() IntRect {
	return command.border_rect
}

pub fn (command AddRoundedRectClip) dump() string {
	return ' rect=${command.border_rect}'
}

pub fn (command AddRoundedRectClip) is_clip() bool {
	return true
}

pub fn (command PaintNestedDisplayList) bounding_rect() IntRect {
	return command.rect
}

pub fn (command PaintNestedDisplayList) dump() string {
	return ' rect=${command.rect}'
}

pub fn (_ PaintScrollbar) dump() string {
	return ''
}

pub fn (command ApplyEffects) dump() string {
	return ' opacity=${command.opacity} has_filter=${command.filter != none}'
}

pub type DisplayListCommand = AddClipRect
	| AddRoundedRectClip
	| ApplyBackdropFilter
	| ApplyEffects
	| DrawEllipse
	| DrawExternalContent
	| DrawGlyphRun
	| DrawLine
	| DrawRect
	| DrawRepeatedDecodedImageFrame
	| DrawScaledDecodedImageFrame
	| DrawVideoFrameSource
	| FillEllipse
	| FillPath
	| FillRect
	| FillRoundedRect
	| PaintConicGradient
	| PaintInnerBoxShadow
	| PaintLinearGradient
	| PaintNestedDisplayList
	| PaintOuterBoxShadow
	| PaintRadialGradient
	| PaintScrollbar
	| PaintTextShadow
	| Restore
	| Save
	| SaveLayer
	| StrokePath
	| Translate

pub fn command_name(command DisplayListCommand) string {
	return match command {
		AddClipRect { 'AddClipRect' }
		AddRoundedRectClip { 'AddRoundedRectClip' }
		ApplyBackdropFilter { 'ApplyBackdropFilter' }
		ApplyEffects { 'ApplyEffects' }
		DrawEllipse { 'DrawEllipse' }
		DrawExternalContent { 'DrawExternalContent' }
		DrawGlyphRun { 'DrawGlyphRun' }
		DrawLine { 'DrawLine' }
		DrawRect { 'DrawRect' }
		DrawRepeatedDecodedImageFrame { 'DrawRepeatedDecodedImageFrame' }
		DrawScaledDecodedImageFrame { 'DrawScaledDecodedImageFrame' }
		DrawVideoFrameSource { 'DrawVideoFrameSource' }
		FillEllipse { 'FillEllipse' }
		FillPath { 'FillPath' }
		FillRect { 'FillRect' }
		FillRoundedRect { 'FillRectWithRoundedCorners' }
		PaintConicGradient { 'PaintConicGradient' }
		PaintInnerBoxShadow { 'PaintInnerBoxShadow' }
		PaintLinearGradient { 'PaintLinearGradient' }
		PaintNestedDisplayList { 'PaintNestedDisplayList' }
		PaintOuterBoxShadow { 'PaintOuterBoxShadow' }
		PaintRadialGradient { 'PaintRadialGradient' }
		PaintScrollbar { 'PaintScrollBar' }
		PaintTextShadow { 'PaintTextShadow' }
		Restore { 'Restore' }
		Save { 'Save' }
		SaveLayer { 'SaveLayer' }
		StrokePath { 'StrokePath' }
		Translate { 'Translate' }
	}
}

pub fn command_dump(command DisplayListCommand) string {
	return match command {
		AddClipRect { command.dump() }
		AddRoundedRectClip { command.dump() }
		ApplyBackdropFilter { command.dump() }
		ApplyEffects { command.dump() }
		DrawEllipse { command.dump() }
		DrawExternalContent { command.dump() }
		DrawGlyphRun { command.dump() }
		DrawLine { command.dump() }
		DrawRect { command.dump() }
		DrawRepeatedDecodedImageFrame { command.dump() }
		DrawScaledDecodedImageFrame { command.dump() }
		DrawVideoFrameSource { command.dump() }
		FillEllipse { command.dump() }
		FillPath { command.dump() }
		FillRect { command.dump() }
		FillRoundedRect { command.dump() }
		PaintConicGradient { command.dump() }
		PaintInnerBoxShadow { command.dump() }
		PaintLinearGradient { command.dump() }
		PaintNestedDisplayList { command.dump() }
		PaintOuterBoxShadow { command.dump() }
		PaintRadialGradient { command.dump() }
		PaintScrollbar { command.dump() }
		PaintTextShadow { command.dump() }
		Restore { command.dump() }
		Save { command.dump() }
		SaveLayer { command.dump() }
		StrokePath { command.dump() }
		Translate { command.dump() }
	}
}

pub fn command_bounding_rect(command DisplayListCommand) ?IntRect {
	return match command {
		AddClipRect {
			command.bounding_rect()
		}
		AddRoundedRectClip {
			command.bounding_rect()
		}
		ApplyBackdropFilter {
			command.bounding_rect()
		}
		DrawEllipse {
			command.bounding_rect()
		}
		DrawExternalContent {
			command.bounding_rect()
		}
		DrawGlyphRun {
			command.bounding_rect()
		}
		DrawLine {
			command.bounding_rect()
		}
		DrawRect {
			command.bounding_rect()
		}
		DrawRepeatedDecodedImageFrame {
			command.bounding_rect()
		}
		DrawScaledDecodedImageFrame {
			command.bounding_rect()
		}
		DrawVideoFrameSource {
			command.bounding_rect()
		}
		FillEllipse {
			command.bounding_rect()
		}
		FillPath {
			command.bounding_rect()
		}
		FillRect {
			command.bounding_rect()
		}
		FillRoundedRect {
			command.bounding_rect()
		}
		PaintConicGradient {
			command.bounding_rect()
		}
		PaintInnerBoxShadow {
			command.bounding_rect()
		}
		PaintLinearGradient {
			command.bounding_rect()
		}
		PaintNestedDisplayList {
			command.bounding_rect()
		}
		PaintOuterBoxShadow {
			command.bounding_rect()
		}
		PaintRadialGradient {
			command.bounding_rect()
		}
		PaintTextShadow {
			command.bounding_rect()
		}
		StrokePath {
			command.bounding_rect()
		}
		else {
			none
		}
	}
}

pub fn command_is_clip(command DisplayListCommand) bool {
	return match command {
		AddClipRect { command.is_clip() }
		AddRoundedRectClip { command.is_clip() }
		else { false }
	}
}

pub fn command_nesting_level_change(command DisplayListCommand) int {
	return match command {
		Save, SaveLayer, ApplyEffects { 1 }
		Restore { -1 }
		else { 0 }
	}
}

pub struct DisplayListItem {
pub:
	context_index int
	command       DisplayListCommand
}

pub struct DisplayList {
pub mut:
	visual_context_tree AccumulatedVisualContextTree = new_accumulated_visual_context_tree()
	commands            []DisplayListItem
}

pub fn (mut list DisplayList) append(command DisplayListCommand, context_index int) bool {
	if context_index > 0 && context_index < list.visual_context_tree.nodes.len
		&& list.visual_context_tree.has_empty_effective_clip(context_index) {
		return false
	}
	list.commands << DisplayListItem{context_index, command}
	return true
}

pub struct DisplayListRecorder {
pub mut:
	display_list                     DisplayList
	accumulated_visual_context_index int
	save_nesting_level               int
	is_capturing                     bool
	captured_commands                []DisplayListCommand
}

// V has no move-only RAII value matching C++ CommandCapture, so callers close
// this token explicitly with take() or end(). The token still owns the right to
// finish exactly one capture and retains the source's move-out behavior.
pub struct CommandCapture {
mut:
	active bool = true
}

pub fn (mut capture CommandCapture) take(mut recorder DisplayListRecorder) []DisplayListCommand {
	assert capture.active && recorder.is_capturing
	commands := recorder.captured_commands
	recorder.captured_commands = []DisplayListCommand{}
	recorder.is_capturing = false
	capture.active = false
	return commands
}

pub fn (mut capture CommandCapture) end(mut recorder DisplayListRecorder) {
	if !capture.active {
		return
	}
	assert recorder.is_capturing
	recorder.end_capture()
	capture.active = false
}

pub fn new_display_list_recorder(tree AccumulatedVisualContextTree) DisplayListRecorder {
	return DisplayListRecorder{
		display_list: DisplayList{
			visual_context_tree: tree
		}
	}
}

pub fn (mut recorder DisplayListRecorder) append(command DisplayListCommand) bool {
	recorder.save_nesting_level += command_nesting_level_change(command)
	added := recorder.display_list.append(command, recorder.accumulated_visual_context_index)
	if added && recorder.is_capturing {
		recorder.captured_commands << command
	}
	return added
}

pub fn (mut recorder DisplayListRecorder) begin_command_capture() CommandCapture {
	assert !recorder.is_capturing
	recorder.is_capturing = true
	recorder.captured_commands.clear()
	return CommandCapture{}
}

fn (mut recorder DisplayListRecorder) end_capture() {
	recorder.is_capturing = false
	recorder.captured_commands.clear()
}

pub fn (mut recorder DisplayListRecorder) replay_cached_commands(commands []DisplayListCommand) {
	for command in commands {
		recorder.save_nesting_level += command_nesting_level_change(command)
		// Deliberately bypass append(): cached commands are replayed into the
		// display list but are not part of an active command capture upstream.
		recorder.display_list.append(command, recorder.accumulated_visual_context_index)
	}
}

pub fn (mut recorder DisplayListRecorder) paint_nested_display_list(command PaintNestedDisplayList) bool {
	return recorder.append(command)
}

pub fn (mut recorder DisplayListRecorder) set_accumulated_visual_context(index int) {
	recorder.accumulated_visual_context_index = index
}

pub fn (recorder DisplayListRecorder) accumulated_visual_context() int {
	return recorder.accumulated_visual_context_index
}

pub fn (mut recorder DisplayListRecorder) fill_rect(rect IntRect, color Color) bool {
	if rect.is_empty() || color.a == 0 {
		return false
	}
	return recorder.append(FillRect{rect, color})
}

pub fn (mut recorder DisplayListRecorder) fill_rect_transparent(rect IntRect) bool {
	if rect.is_empty() {
		return false
	}
	return recorder.append(FillRect{rect, transparent})
}

pub fn (mut recorder DisplayListRecorder) fill_path(command FillPath) bool {
	if command.path_bounding_rect.is_empty() || command.color.a == 0 {
		return false
	}
	return recorder.append(command)
}

pub fn (mut recorder DisplayListRecorder) stroke_path(command StrokePath) bool {
	if command.path_bounding_rect.is_empty() || command.color.a == 0 || command.thickness == 0 {
		return false
	}
	return recorder.append(command)
}

pub fn (mut recorder DisplayListRecorder) draw_ellipse(command DrawEllipse) bool {
	if command.rect.is_empty() || command.color.a == 0 || command.thickness == 0 {
		return false
	}
	return recorder.append(command)
}

pub fn (mut recorder DisplayListRecorder) fill_ellipse(command FillEllipse) bool {
	if command.rect.is_empty() || command.color.a == 0 {
		return false
	}
	return recorder.append(command)
}

pub fn (mut recorder DisplayListRecorder) fill_rect_with_linear_gradient(command PaintLinearGradient) bool {
	return if command.rect.is_empty() { false } else { recorder.append(command) }
}

pub fn (mut recorder DisplayListRecorder) fill_rect_with_radial_gradient(command PaintRadialGradient) bool {
	return if command.rect.is_empty() { false } else { recorder.append(command) }
}

pub fn (mut recorder DisplayListRecorder) fill_rect_with_conic_gradient(command PaintConicGradient) bool {
	return if command.rect.is_empty() { false } else { recorder.append(command) }
}

pub fn (mut recorder DisplayListRecorder) draw_rect(command DrawRect) bool {
	if command.rect.is_empty() || command.color.a == 0 {
		return false
	}
	return recorder.append(command)
}

pub fn (mut recorder DisplayListRecorder) draw_external_content(command DrawExternalContent) bool {
	return if command.destination.is_empty() { false } else { recorder.append(command) }
}

pub fn (mut recorder DisplayListRecorder) draw_video_frame_source(command DrawVideoFrameSource) bool {
	return if command.destination.is_empty() { false } else { recorder.append(command) }
}

pub fn (mut recorder DisplayListRecorder) draw_scaled_decoded_image_frame(command DrawScaledDecodedImageFrame) bool {
	return if command.destination.is_empty() { false } else { recorder.append(command) }
}

pub fn (mut recorder DisplayListRecorder) draw_repeated_decoded_image_frame(command DrawRepeatedDecodedImageFrame) bool {
	return recorder.append(command)
}

pub fn (mut recorder DisplayListRecorder) draw_line(command DrawLine) bool {
	if command.color.a == 0 || command.thickness == 0 {
		return false
	}
	return recorder.append(command)
}

pub fn (mut recorder DisplayListRecorder) draw_text(rect IntRect, text string,
	font &platform.Font, alignment TextAlignment, color Color) bool {
	if rect.is_empty() || color.a == 0 {
		return false
	}
	glyph_run := platform.shape_text(0, 0, text, font, .ltr)
	baseline_x := match alignment {
		.center_left { f32(rect.x) }
		.center { f32(rect.x) + (f32(rect.width) - glyph_run.width()) / 2.0 }
		.center_right { f32(rect.right()) - glyph_run.width() }
	}
	metrics := font.pixel_metrics()
	baseline_y := f32(rect.y) + metrics.ascent + (f32(rect.height) - (metrics.ascent + metrics.descent)) / 2.0
	return recorder.draw_glyph_run(Point{f64(baseline_x), f64(baseline_y)}, glyph_run, color, rect, 1.0, .horizontal, 0)
}

pub fn (mut recorder DisplayListRecorder) draw_glyph_run(baseline_start Point,
	glyph_run &platform.GlyphRun, color Color, rect IntRect, scale f64,
	orientation Orientation, font_smoothing u8) bool {
	if color.a == 0 {
		return false
	}
	horizontal_bounds := glyph_run_device_bounding_rect(glyph_run, baseline_start, scale)
	return recorder.append(DrawGlyphRun{
		glyph_run_id: u64(voidptr(glyph_run)).str()
		glyph_run: glyph_run
		rect: rect
		glyph_bounding_rect: if orientation == .vertical {
			vertical_glyph_bounds(horizontal_bounds, rect)
		} else { horizontal_bounds }
		translation: baseline_start
		color: color
		orientation: orientation
		scale: scale
		font_smoothing: font_smoothing
	})
}

pub fn (mut recorder DisplayListRecorder) fill_rect_with_rounded_corners(command FillRoundedRect) bool {
	if command.rect.is_empty() || command.color.a == 0 {
		return false
	}
	if !command.corner_radii.has_any_radius() {
		return recorder.fill_rect(command.rect, command.color)
	}
	return recorder.append(command)
}

pub fn (mut recorder DisplayListRecorder) add_clip_rect(rect IntRect) bool {
	return recorder.append(AddClipRect{rect})
}

pub fn (mut recorder DisplayListRecorder) add_rounded_rect_clip(radii CornerRadii,
	rect IntRect, corner_clip CornerClip) bool {
	return recorder.append(AddRoundedRectClip{radii, rect, corner_clip})
}

pub fn (mut recorder DisplayListRecorder) save() bool {
	return recorder.append(Save{})
}

pub fn (mut recorder DisplayListRecorder) save_layer() bool {
	return recorder.append(SaveLayer{})
}

pub fn (mut recorder DisplayListRecorder) restore() bool {
	return recorder.append(Restore{})
}

pub fn (mut recorder DisplayListRecorder) translate(delta IntPoint) bool {
	return recorder.append(Translate{delta})
}

pub fn (mut recorder DisplayListRecorder) apply_effects(opacity f64,
	operator CompositingAndBlendingOperator, filter ?GfxFilter, mask_kind ?MaskKind) bool {
	return recorder.append(ApplyEffects{opacity, operator, filter, mask_kind})
}

pub struct MaskInfo {
pub:
	display_list_id string
	rect            IntRect
	kind            MaskKind
}

pub fn (mut recorder DisplayListRecorder) begin_masks(masks []MaskInfo) {
	for mask in masks {
		recorder.save()
		recorder.add_clip_rect(mask.rect)
		recorder.save_layer()
	}
}

pub fn (mut recorder DisplayListRecorder) end_masks(masks []MaskInfo) {
	for index := masks.len - 1; index >= 0; index-- {
		mask := masks[index]
		mask_kind := if mask.kind == .luminance {
			?MaskKind(MaskKind.luminance)
		} else {
			?MaskKind(none)
		}
		recorder.apply_effects(1, .destination_in, none, mask_kind)
		recorder.paint_nested_display_list(PaintNestedDisplayList{mask.display_list_id, mask.rect})
		recorder.restore()
		recorder.restore()
		recorder.restore()
	}
}

pub fn (mut recorder DisplayListRecorder) apply_backdrop_filter(command ApplyBackdropFilter) bool {
	return if command.backdrop_region.is_empty() { false } else { recorder.append(command) }
}

pub fn (mut recorder DisplayListRecorder) paint_outer_box_shadow(command PaintOuterBoxShadow) bool {
	return recorder.append(command)
}

pub fn (mut recorder DisplayListRecorder) paint_inner_box_shadow(command PaintInnerBoxShadow) bool {
	return recorder.append(command)
}

pub fn (mut recorder DisplayListRecorder) paint_text_shadow(command PaintTextShadow) bool {
	return recorder.append(command)
}

pub fn (mut recorder DisplayListRecorder) paint_scrollbar(command PaintScrollbar) bool {
	return recorder.append(command)
}

pub struct PlaybackAction {
pub:
	kind          string
	context_index int
	rect          ?IntRect
	delta         IntPoint
}

struct PlaybackPlanner {
	tree     AccumulatedVisualContextTree
	snapshot ScrollStateSnapshot
	clip     IntRect
mut:
	applied_context int
	applied_depth   int
	actions         []PlaybackAction
}

fn (mut planner PlaybackPlanner) apply_context(index int) {
	node := planner.tree.node_at(index)
	kind := match node.data {
		EffectsVisualData { 'ApplyEffects' }
		PerspectiveVisualData { 'ApplyPerspective' }
		BackfaceVisibilityVisualData { 'ApplyBackfaceVisibility' }
		ScrollCompensationVisualData { 'ApplyScrollCompensation' }
		ScrollVisualData { 'ApplyScroll' }
		TransformVisualData { 'ApplyTransform' }
		ClipVisualData { 'ApplyClip' }
		ClipPathVisualData { 'ApplyClipPath' }
		SVGClipVisualData { 'ApplySVGClipMask' }
		SVGMaskVisualData { 'ApplySVGMask' }
	}
	delta := match node.data {
		ScrollVisualData {
			offset := planner.snapshot.device_offset_for_index(node.data.scroll_frame_index)
			IntPoint{int(offset.x), int(offset.y)}
		}
		ScrollCompensationVisualData {
			offset := planner.snapshot.device_offset_for_index(node.data.scroll_frame_index)
			IntPoint{int(-offset.x), int(-offset.y)}
		}
		else {
			IntPoint{}
		}
	}
	planner.actions << PlaybackAction{
		kind: kind
		context_index: index
		delta: delta
	}
}

fn (mut planner PlaybackPlanner) apply_contexts_from_common_ancestor(common int, target int,
	bounds ?IntRect) bool {
	if target <= 0 || target == common {
		return false
	}
	if planner.apply_contexts_from_common_ancestor(common, planner.tree.node_at(target).parent_index, bounds) {
		return true
	}
	node := planner.tree.node_at(target)
	if node.data is EffectsVisualData {
		if bound := bounds {
			if bound.is_empty() || !bound.intersects(planner.clip) {
				return true
			}
		}
	}
	planner.apply_context(target)
	planner.applied_depth++
	return false
}

enum ContextSwitchResult {
	switched
	culled_by_effect
}

fn (mut planner PlaybackPlanner) switch_to_context(target int, bounds ?IntRect) ContextSwitchResult {
	if planner.applied_context == target {
		return .switched
	}
	common := planner.tree.find_common_ancestor(planner.applied_context, target)
	common_depth := if common > 0 { planner.tree.node_at(common).depth } else { 0 }
	for planner.applied_depth > common_depth {
		planner.actions << PlaybackAction{
			kind: 'RestoreContext'
		}
		planner.applied_depth--
	}
	// DisplayListPlayer::execute_impl() recursively visits the path from the
	// common ancestor to the target. Do the same instead of allocating and
	// reversing an ancestor vector for every display-list context switch.
	if planner.apply_contexts_from_common_ancestor(common, target, bounds) {
		return .culled_by_effect
	}
	planner.applied_context = target
	return .switched
}

pub fn (list DisplayList) playback_plan(snapshot ScrollStateSnapshot, visible_clip IntRect) []PlaybackAction {
	mut planner := PlaybackPlanner{
		tree: list.visual_context_tree
		snapshot: snapshot
		clip: visible_clip
	}
	for item in list.commands {
		bounds := command_bounding_rect(item.command)
		if planner.switch_to_context(item.context_index, bounds) == .culled_by_effect {
			continue
		}
		if list.visual_context_tree.context_is_backface_culled(item.context_index, snapshot) {
			continue
		}
		if bound := bounds {
			if bound.is_empty() || !bound.intersects(visible_clip) {
				if command_is_clip(item.command) {
					planner.actions << PlaybackAction{
						kind: 'AddClipRect'
						context_index: item.context_index
						rect: bound
					}
				}
				continue
			}
		}
		if item.command is PaintScrollbar {
			scrollbar := item.command
			offset := snapshot.device_offset_for_index(scrollbar.scroll_frame_index)
			delta := if scrollbar.vertical {
				IntPoint{0, int(-offset.y * scrollbar.scroll_size)}
			} else {
				IntPoint{int(-offset.x * scrollbar.scroll_size), 0}
			}
			planner.actions << PlaybackAction{
				kind: command_name(item.command)
				context_index: item.context_index
				delta: delta
			}
			continue
		}
		planner.actions << PlaybackAction{
			kind: command_name(item.command)
			context_index: item.context_index
			rect: bounds
		}
	}
	for planner.applied_depth > 0 {
		planner.actions << PlaybackAction{
			kind: 'RestoreContext'
		}
		planner.applied_depth--
	}
	return planner.actions
}

// ExternalContentSource is the renderer-thread handoff. Decoded frames keep
// the source pixels and color-space metadata alive until playback.
pub struct ExternalContentSource {
pub mut:
	frame ?&dom.DecodedImageFrame_
}

pub fn (mut source ExternalContentSource) update(frame ?&dom.DecodedImageFrame_) {
	source.frame = frame
}

pub fn (mut source ExternalContentSource) clear() {
	source.frame = none
}

pub fn (source &ExternalContentSource) current_frame() ?&dom.DecodedImageFrame_ {
	return source.frame
}
