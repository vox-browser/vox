module painting

pub enum CornerClip {
	inside
	outside
}

pub enum ScalingMode {
	nearest_neighbor
	bilinear
	smooth_pixels
}

pub enum Orientation {
	horizontal
	vertical
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
	glyph_run_id string
	rect         IntRect
	translation  Point
	color        Color
	orientation  Orientation
}

pub struct FillRect {
pub:
	rect  IntRect
	color Color
}

pub struct DrawScaledBitmap {
pub:
	destination IntRect
	clip_rect   IntRect
	bitmap_id   string
	scaling     ScalingMode
}

pub struct DrawRepeatedBitmap {
pub:
	destination IntRect
	clip_rect   IntRect
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

pub struct PaintTextShadow {
pub:
	glyph_run_id         string
	shadow_bounding_rect IntRect
	text_rect            IntRect
	draw_location        Point
	blur_radius          int
	color                Color
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

pub type DisplayListCommand = AddClipRect
	| AddRoundedRectClip
	| ApplyBackdropFilter
	| ApplyEffects
	| DrawEllipse
	| DrawExternalContent
	| DrawGlyphRun
	| DrawLine
	| DrawRect
	| DrawRepeatedBitmap
	| DrawScaledBitmap
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
		DrawRepeatedBitmap { 'DrawRepeatedImmutableBitmap' }
		DrawScaledBitmap { 'DrawScaledImmutableBitmap' }
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

pub fn command_bounding_rect(command DisplayListCommand) ?IntRect {
	return match command {
		AddClipRect {
			command.rect
		}
		AddRoundedRectClip {
			command.border_rect
		}
		ApplyBackdropFilter {
			command.backdrop_region
		}
		DrawEllipse {
			command.rect
		}
		DrawExternalContent {
			command.destination
		}
		DrawGlyphRun {
			command.rect.translated(IntPoint{int(command.translation.x), int(command.translation.y)})
		}
		DrawLine {
			int_rect_from_two_points(command.from, command.to).inflated(command.thickness,
				command.thickness, command.thickness, command.thickness)
		}
		DrawRect {
			command.rect
		}
		DrawRepeatedBitmap {
			command.clip_rect
		}
		DrawScaledBitmap {
			command.clip_rect
		}
		FillEllipse {
			command.rect
		}
		FillPath {
			command.path_bounding_rect
		}
		FillRect {
			command.rect
		}
		FillRoundedRect {
			command.rect
		}
		PaintConicGradient {
			command.rect
		}
		PaintInnerBoxShadow {
			command.device_content_rect
		}
		PaintLinearGradient {
			command.rect
		}
		PaintNestedDisplayList {
			command.rect
		}
		PaintOuterBoxShadow {
			command.shadow_rect.inflated(command.blur_radius * 2, command.blur_radius * 2,
				command.blur_radius * 2, command.blur_radius * 2)
		}
		PaintRadialGradient {
			command.rect
		}
		PaintTextShadow {
			IntRect{int(command.draw_location.x), int(command.draw_location.y), command.shadow_bounding_rect.width, command.shadow_bounding_rect.height}
		}
		StrokePath {
			command.path_bounding_rect
		}
		else {
			none
		}
	}
}

pub fn command_is_clip(command DisplayListCommand) bool {
	return command is AddClipRect || command is AddRoundedRectClip
}

pub fn command_nesting_change(command DisplayListCommand) int {
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
		&& list.visual_context_tree.nodes[context_index].has_empty_effective_clip {
		return false
	}
	list.commands << DisplayListItem{context_index, command}
	return true
}

pub struct DisplayListRecorder {
pub mut:
	display_list              DisplayList
	accumulated_context_index int
	save_nesting_level        int
	is_capturing              bool
	captured_commands         []DisplayListCommand
}

pub fn new_display_list_recorder(tree AccumulatedVisualContextTree) DisplayListRecorder {
	return DisplayListRecorder{
		display_list: DisplayList{
			visual_context_tree: tree
		}
	}
}

pub fn (mut recorder DisplayListRecorder) append(command DisplayListCommand) bool {
	nesting_change := command_nesting_change(command)
	if recorder.save_nesting_level + nesting_change < 0 {
		return false
	}
	recorder.save_nesting_level += nesting_change
	added := recorder.display_list.append(command, recorder.accumulated_context_index)
	if added && recorder.is_capturing {
		recorder.captured_commands << command
	}
	return added
}

pub fn (mut recorder DisplayListRecorder) begin_capture() bool {
	if recorder.is_capturing {
		return false
	}
	recorder.is_capturing = true
	recorder.captured_commands.clear()
	return true
}

pub fn (mut recorder DisplayListRecorder) take_capture() []DisplayListCommand {
	if !recorder.is_capturing {
		return []
	}
	recorder.is_capturing = false
	commands := recorder.captured_commands.clone()
	recorder.captured_commands.clear()
	return commands
}

pub fn (mut recorder DisplayListRecorder) replay_cached(commands []DisplayListCommand) {
	for command in commands {
		recorder.append(command)
	}
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

pub fn (mut recorder DisplayListRecorder) paint_linear_gradient(command PaintLinearGradient) bool {
	return if command.rect.is_empty() { false } else { recorder.append(command) }
}

pub fn (mut recorder DisplayListRecorder) paint_radial_gradient(command PaintRadialGradient) bool {
	return if command.rect.is_empty() { false } else { recorder.append(command) }
}

pub fn (mut recorder DisplayListRecorder) paint_conic_gradient(command PaintConicGradient) bool {
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

pub fn (mut recorder DisplayListRecorder) draw_scaled_bitmap(command DrawScaledBitmap) bool {
	return if command.destination.is_empty() { false } else { recorder.append(command) }
}

pub fn (mut recorder DisplayListRecorder) draw_repeated_bitmap(command DrawRepeatedBitmap) bool {
	return recorder.append(command)
}

pub fn (mut recorder DisplayListRecorder) draw_line(command DrawLine) bool {
	if command.color.a == 0 || command.thickness == 0 {
		return false
	}
	return recorder.append(command)
}

pub fn (mut recorder DisplayListRecorder) fill_rounded_rect(command FillRoundedRect) bool {
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
		recorder.append(PaintNestedDisplayList{mask.display_list_id, mask.rect})
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
	node := planner.tree.nodes[index]
	kind := match node.data {
		EffectsVisualData { 'ApplyEffects' }
		PerspectiveVisualData { 'ApplyPerspective' }
		ScrollVisualData { 'ApplyScroll' }
		TransformVisualData { 'ApplyTransform' }
		ClipVisualData { 'ApplyClip' }
		ClipPathVisualData { 'ApplyClipPath' }
	}
	delta := match node.data {
		ScrollVisualData {
			offset := planner.snapshot.device_offset_for_index(node.data.scroll_frame_index)
			IntPoint{int(offset.x), int(offset.y)}
		}
		else {
			IntPoint{}
		}
	}
	planner.actions << PlaybackAction{
		kind:          kind
		context_index: index
		delta:         delta
	}
}

fn (mut planner PlaybackPlanner) switch_to_context(target int) {
	if planner.applied_context == target {
		return
	}
	common := planner.tree.find_common_ancestor(planner.applied_context, target)
	common_depth := if common > 0 { planner.tree.nodes[common].depth } else { 0 }
	for planner.applied_depth > common_depth {
		planner.actions << PlaybackAction{
			kind: 'RestoreContext'
		}
		planner.applied_depth--
	}
	chain := planner.tree.ancestor_chain(target)
	for reverse_index := chain.len - 1; reverse_index >= 0; reverse_index-- {
		index := chain[reverse_index]
		if index == common || planner.tree.nodes[index].depth <= common_depth {
			continue
		}
		planner.apply_context(index)
		planner.applied_depth++
	}
	planner.applied_context = target
}

pub fn (list DisplayList) playback_plan(snapshot ScrollStateSnapshot, visible_clip IntRect) []PlaybackAction {
	mut planner := PlaybackPlanner{
		tree:     list.visual_context_tree
		snapshot: snapshot
		clip:     visible_clip
	}
	for item in list.commands {
		bounds := command_bounding_rect(item.command)
		if item.context_index > 0 && planner.applied_context != item.context_index
			&& planner.tree.is_effect(item.context_index) {
			if bound := bounds {
				planner.switch_to_context(planner.tree.nodes[item.context_index].parent_index)
				if bound.is_empty() || !bound.intersects(visible_clip) {
					continue
				}
			}
		}
		planner.switch_to_context(item.context_index)
		if bound := bounds {
			if bound.is_empty() || !bound.intersects(visible_clip) {
				if command_is_clip(item.command) {
					planner.actions << PlaybackAction{
						kind:          'AddClipRect'
						context_index: item.context_index
						rect:          bound
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
				kind:          command_name(item.command)
				context_index: item.context_index
				delta:         delta
			}
			continue
		}
		planner.actions << PlaybackAction{
			kind:          command_name(item.command)
			context_index: item.context_index
			rect:          bounds
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

// ExternalContentSource is the renderer-thread handoff. The translation keeps
// immutable bitmap identity and replacement semantics without binding to Skia.
pub struct ExternalContentSource {
pub mut:
	bitmap_id ?string
}

pub fn (mut source ExternalContentSource) update(bitmap_id string) {
	source.bitmap_id = bitmap_id
}

pub fn (mut source ExternalContentSource) clear() {
	source.bitmap_id = none
}
