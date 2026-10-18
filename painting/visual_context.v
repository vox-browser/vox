module painting

import css

pub struct ScrollVisualData {
pub:
	scroll_frame_index int
	is_sticky          bool
}

// Negates a scroll frame's offset during display-list replay so content such as a fixed background
// remains stationary relative to the viewport.
pub struct ScrollCompensationVisualData {
pub:
	scroll_frame_index int
}

pub struct ClipVisualData {
pub:
	rect         IntRect
	corner_radii CornerRadii
}

pub fn (clip ClipVisualData) contains(point IntPoint) bool {
	return clip.corner_radii.contains(point, clip.rect)
}

pub struct TransformVisualData {
pub:
	origin                  Point
	matrix                  Affine
	matrix_4x4              css.FloatMatrix4x4
	uses_matrix_4x4         bool
	resets_backface_culling bool
}

pub struct PerspectiveVisualData {
pub:
	matrix          Affine
	matrix_4x4      css.FloatMatrix4x4
	uses_matrix_4x4 bool
}

pub struct BackfaceVisibilityVisualData {
pub:
	plane_root_index int
}

pub enum ClipPathSegmentKind {
	move_to
	line_to
	quadratic_bezier_curve_to
	cubic_bezier_curve_to
	elliptical_arc_to
	close_path
}

// Gfx::Path segment data retained by ClipPathData. Curves remain exact for
// display-list replay; `polygons` below is the one-time flattened counterpart
// used by the compact software hit-test backend.
pub struct ClipPathSegment {
pub:
	kind            ClipPathSegmentKind
	point           Point
	control_point_0 Point
	control_point_1 Point
	radii           Size
	rotation        f64
	large_arc       bool
	sweep           bool
}

pub struct ClipPathVisualData {
pub:
	bounding_rect IntRect
	segments      []ClipPathSegment
	polygons      [][]Point
	// Retained for callers which construct the earlier single-contour form.
	polygon   []Point
	fill_rule WindingRule = .nonzero
}

// SVGMaskable paints a referenced <clipPath> into an alpha mask around the
// target stacking context. Unlike a CSS basic-shape clip this deliberately is
// not consulted by hit testing, matching StackingContext::hit_test(). Each
// resource geometry keeps its own clip-rule and SVG transform; painting unions
// the components in the alpha mask instead of intersecting their paths.
pub struct SVGClipPathComponent {
pub:
	path      ClipPathVisualData
	transform Affine
}

pub struct SVGClipVisualData {
pub:
	bounding_rect IntRect
	components    []SVGClipPathComponent
	cache_key     u64
	scope_id      u64
}

pub enum SVGMaskPaintOperationKind {
	begin_filter
	begin_opacity
	end_filter
	end_opacity
	image
	path
}

// The nested display list produced by SVGMaskable is retained as an ordered
// operation stream. Opacity boundaries cannot be multiplied into each leaf:
// a group's children must be composited before the group opacity is applied.
pub struct SVGMaskPaintOperation {
pub:
	kind                   SVGMaskPaintOperationKind
	filter                 ?GfxFilter
	opacity                f64 = 1.0
	image_url              string
	image_rect             Rect
	image_position_x       string = '50%'
	image_position_y       string = '50%'
	image_rendering        css.ImageRendering
	image_paintable        ?ImagePaintable
	path                   ClipPathVisualData
	transform              Affine
	fill_linear_gradient   ?SVGLinearGradientPaintStyle
	stroke_linear_gradient ?SVGLinearGradientPaintStyle
	fill_radial_gradient   ?SVGRadialGradientPaintStyle
	stroke_radial_gradient ?SVGRadialGradientPaintStyle
	fill_pattern           ?&SVGPatternPaintStyle
	stroke_pattern         ?&SVGPatternPaintStyle
	fill_color             Color
	stroke_color           Color
	has_fill               bool
	has_stroke             bool
	stroke_first           bool
	fill_opacity           f64 = 1.0
	stroke_opacity         f64 = 1.0
	stroke_width           f64
	stroke_linecap         LineCap
	stroke_linejoin        LineJoin
	stroke_miter_limit     f64 = 4.0
}

// Kept behind a pointer in SVGPatternPaintStyle so nested pattern paints have
// the same reference graph as C++ PaintStyle without forming a recursive V
// value type.
pub struct SVGPatternDisplayList {
pub:
	operations []SVGMaskPaintOperation
}

pub struct SVGMaskVisualData {
pub:
	bounding_rect IntRect
	mask_type     SVGMaskType
	operations    []SVGMaskPaintOperation
	cache_key     u64
	scope_id      u64
}

fn edge_side(start Point, end Point, point Point) f64 {
	return (end.x - start.x) * (point.y - start.y) - (point.x - start.x) * (end.y - start.y)
}

fn polygon_crossings_and_winding(polygon []Point, point Point) (int, int) {
	mut crossings := 0
	mut winding := 0
	if polygon.len < 3 {
		return crossings, winding
	}
	mut previous := polygon.len - 1
	for current := 0; current < polygon.len; current++ {
		first := polygon[previous]
		second := polygon[current]
		if (first.y > point.y) != (second.y > point.y)
			&& point.x < (second.x - first.x) * (point.y - first.y) / (second.y - first.y) + first.x {
			crossings++
		}
		if first.y <= point.y {
			if second.y > point.y && edge_side(first, second, point) > 0 {
				winding++
			}
		} else if second.y <= point.y && edge_side(first, second, point) < 0 {
			winding--
		}
		previous = current
	}
	return crossings, winding
}

pub fn polygon_contains_with_rule(polygon []Point, point Point, rule WindingRule) bool {
	crossings, winding := polygon_crossings_and_winding(polygon, point)
	return if rule == .even_odd { crossings % 2 == 1 } else { winding != 0 }
}

pub fn polygons_contain_with_rule(polygons [][]Point, point Point, rule WindingRule) bool {
	mut crossings := 0
	mut winding := 0
	for polygon in polygons {
		polygon_crossings, polygon_winding := polygon_crossings_and_winding(polygon, point)
		crossings += polygon_crossings
		winding += polygon_winding
	}
	return if rule == .even_odd { crossings % 2 == 1 } else { winding != 0 }
}

pub fn (clip ClipPathVisualData) contains(point Point) bool {
	if !clip.bounding_rect.contains(IntPoint{int(point.x), int(point.y)}) {
		return false
	}
	if clip.polygons.len > 0 {
		return polygons_contain_with_rule(clip.polygons, point, clip.fill_rule)
	}
	return polygon_contains_with_rule(clip.polygon, point, clip.fill_rule)
}

pub struct EffectsVisualData {
pub:
	opacity    f64 = 1.0
	blend_mode CompositingAndBlendingOperator
	filter     ?GfxFilter
}

pub fn (effects EffectsVisualData) needs_layer() bool {
	return effects.opacity < 1 || effects.blend_mode != .normal || effects.filter != none
}

pub type VisualContextData = ClipPathVisualData
	| ClipVisualData
	| EffectsVisualData
	| PerspectiveVisualData
	| BackfaceVisibilityVisualData
	| ScrollCompensationVisualData
	| ScrollVisualData
	| SVGClipVisualData
	| SVGMaskVisualData
	| TransformVisualData

pub struct AccumulatedVisualContextNode {
pub:
	data                     VisualContextData
	parent_index             int
	depth                    int
	has_empty_effective_clip bool
	has_backface_visibility bool
}

pub struct AccumulatedVisualContextTree {
pub mut:
	nodes []AccumulatedVisualContextNode
}

pub fn AccumulatedVisualContextTree.create() AccumulatedVisualContextTree {
	return AccumulatedVisualContextTree{
		nodes: [AccumulatedVisualContextNode{ data: ScrollVisualData{} }]
	}
}

pub fn new_accumulated_visual_context_tree() AccumulatedVisualContextTree {
	return AccumulatedVisualContextTree.create()
}

pub fn (tree &AccumulatedVisualContextTree) node_at(index int) &AccumulatedVisualContextNode {
	return &tree.nodes[index]
}

pub fn (tree &AccumulatedVisualContextTree) has_empty_effective_clip(index int) bool {
	return tree.nodes[index].has_empty_effective_clip
}

pub fn (mut tree AccumulatedVisualContextTree) append(data VisualContextData, parent int) int {
	depth := if parent > 0 && parent < tree.nodes.len { tree.nodes[parent].depth + 1 } else { 1 }
	mut empty_clip := parent > 0 && parent < tree.nodes.len
		&& tree.nodes[parent].has_empty_effective_clip
	if !empty_clip {
		empty_clip = match data {
			ClipVisualData { data.rect.is_empty() }
			ClipPathVisualData {
				data.bounding_rect.is_empty()
					|| (data.polygons.all(it.len < 3) && data.polygon.len < 3)
			}
			SVGClipVisualData {
				data.bounding_rect.is_empty() || data.components.len == 0
			}
			SVGMaskVisualData {
				data.bounding_rect.is_empty()
					|| data.operations.all(it.kind != .path && it.kind != .image)
			}
			else { false }
		}
	}
	index := tree.nodes.len
	has_backface_visibility := data is BackfaceVisibilityVisualData
		|| (parent > 0 && parent < tree.nodes.len && tree.nodes[parent].has_backface_visibility)
	tree.nodes << AccumulatedVisualContextNode{
		data: data
		parent_index: parent
		depth: depth
		has_empty_effective_clip: empty_clip
		has_backface_visibility: has_backface_visibility
	}
	return index
}

// Replace the values of an existing transform or effects node. Its depth,
// empty-clip and backface flags depend only on clips and the tree structure.
// Compositor samples rewrite an existing node's values in place. Recorded
// display lists copy these values rather than referencing the node, so no
// published list observes the change, and no new node data is allocated.
pub fn (mut tree AccumulatedVisualContextTree) set_compositor_transform(index int, matrix Affine,
	matrix_4x4 css.FloatMatrix4x4, uses_matrix_4x4 bool) bool {
	if index <= 0 || index >= tree.nodes.len {
		return false
	}
	data := tree.nodes[index].data
	if data is TransformVisualData {
		unsafe {
			mut target := &TransformVisualData(&data)
			*target = TransformVisualData{
				...*target
				matrix:          matrix
				matrix_4x4:      matrix_4x4
				uses_matrix_4x4: uses_matrix_4x4
			}
		}
		return true
	}
	return false
}

pub fn (mut tree AccumulatedVisualContextTree) set_compositor_opacity(index int, opacity f64) bool {
	if index <= 0 || index >= tree.nodes.len {
		return false
	}
	data := tree.nodes[index].data
	if data is EffectsVisualData {
		unsafe {
			mut target := &EffectsVisualData(&data)
			*target = EffectsVisualData{
				...*target
				opacity: opacity
			}
		}
		return true
	}
	return false
}

pub fn (mut tree AccumulatedVisualContextTree) replace_compositor_values(index int,
	data VisualContextData) bool {
	if index <= 0 || index >= tree.nodes.len {
		return false
	}
	existing := tree.nodes[index]
	same_kind := match data {
		TransformVisualData { existing.data is TransformVisualData }
		EffectsVisualData { existing.data is EffectsVisualData }
		else { false }
	}
	if !same_kind {
		return false
	}
	tree.nodes[index] = AccumulatedVisualContextNode{
		...existing
		data: data
	}
	return true
}

pub fn (tree &AccumulatedVisualContextTree) find_common_ancestor(first int, second int) int {
	if first <= 0 || second <= 0 || first >= tree.nodes.len || second >= tree.nodes.len {
		return 0
	}
	mut a := first
	mut b := second
	for tree.nodes[a].depth > tree.nodes[b].depth {
		a = tree.nodes[a].parent_index
	}
	for tree.nodes[b].depth > tree.nodes[a].depth {
		b = tree.nodes[b].parent_index
	}
	for a != b {
		a = tree.nodes[a].parent_index
		b = tree.nodes[b].parent_index
	}
	return a
}

fn (tree &AccumulatedVisualContextTree) build_ancestor_chain(index int) []int {
	if index <= 0 || index >= tree.nodes.len {
		return []
	}
	mut chain := []int{cap: tree.nodes[index].depth}
	mut current := index
	for current > 0 {
		chain << current
		current = tree.nodes[current].parent_index
	}
	return chain
}

fn inverse_map_about_origin(point Point, matrix Affine, origin Point) ?Point {
	inverse := matrix.inverse() or { return none }
	return inverse.map_point(point.subtract(origin)).add(origin)
}

fn affine_matrix_4x4(matrix Affine) css.FloatMatrix4x4 {
	return css.FloatMatrix4x4.from_values(matrix.a, matrix.c, 0, matrix.e, matrix.b, matrix.d, 0, matrix.f, 0, 0, 1, 0, 0, 0, 0, 1)
}

pub fn (transform TransformVisualData) matrix_including_origin_4x4() css.FloatMatrix4x4 {
	matrix := if transform.uses_matrix_4x4 {
		transform.matrix_4x4
	} else {
		affine_matrix_4x4(transform.matrix)
	}
	return css.translation_matrix_4x4(transform.origin.x, transform.origin.y, 0).multiply(matrix).multiply(css.translation_matrix_4x4(-transform.origin.x, -transform.origin.y, 0))
}

fn (perspective PerspectiveVisualData) resolved_matrix_4x4() css.FloatMatrix4x4 {
	return if perspective.uses_matrix_4x4 {
		perspective.matrix_4x4
	} else {
		affine_matrix_4x4(perspective.matrix)
	}
}

pub fn should_cull_back_face(accumulated_matrix css.FloatMatrix4x4,
	plane_root_matrix css.FloatMatrix4x4) bool {
	inverse_plane_root := plane_root_matrix.inverse() or { return false }
	return css.is_back_face_visible(inverse_plane_root.multiply(accumulated_matrix))
}

fn visual_context_local_matrix(node AccumulatedVisualContextNode,
	snapshot ScrollStateSnapshot) css.FloatMatrix4x4 {
	return match node.data {
		TransformVisualData { node.data.matrix_including_origin_4x4() }
		PerspectiveVisualData { node.data.resolved_matrix_4x4() }
		ScrollVisualData {
			offset := snapshot.device_offset_for_index(node.data.scroll_frame_index)
			css.translation_matrix_4x4(offset.x, offset.y, 0)
		}
		ScrollCompensationVisualData {
			offset := snapshot.device_offset_for_index(node.data.scroll_frame_index)
			css.translation_matrix_4x4(-offset.x, -offset.y, 0)
		}
		else { css.FloatMatrix4x4.identity() }
	}
}

pub fn (tree &AccumulatedVisualContextTree) context_is_backface_culled(index int,
	snapshot ScrollStateSnapshot) bool {
	if index <= 0 || index >= tree.nodes.len {
		return false
	}
	// Ordinary 2D contexts have no hidden-backface plane. Avoid allocating an
	// ancestor chain and matrix map for every hit-test candidate in that case.
	if !tree.nodes[index].has_backface_visibility {
		return false
	}
	if tree.nodes[index].depth <= inline_backface_chain_capacity {
		return tree.inline_context_is_backface_culled(index, snapshot)
	}
	return tree.context_is_backface_culled_with_depth_fallback(index, snapshot)
}

const inline_backface_chain_capacity = 32

// Same walk as the general path, with the chain and its accumulated matrices in
// fixed storage. Hit testing asks this for every candidate below a hidden
// backface, so the map and chain allocations dominated its cost.
fn (tree &AccumulatedVisualContextTree) inline_context_is_backface_culled(index int,
	snapshot ScrollStateSnapshot) bool {
	mut chain := [inline_backface_chain_capacity]int{}
	mut matrices := [inline_backface_chain_capacity]css.FloatMatrix4x4{}
	mut count := 0
	mut current := index
	for current > 0 {
		if count == inline_backface_chain_capacity {
			return tree.context_is_backface_culled_with_depth_fallback(index, snapshot)
		}
		chain[count] = current
		count++
		current = tree.nodes[current].parent_index
	}
	mut accumulated := css.FloatMatrix4x4.identity()
	mut culled := false
	for reverse_index := count - 1; reverse_index >= 0; reverse_index-- {
		node_index := chain[reverse_index]
		node := tree.nodes[node_index]
		accumulated = accumulated.multiply(visual_context_local_matrix(node, snapshot))
		matrices[reverse_index] = accumulated
		if node.data is TransformVisualData && node.data.resets_backface_culling {
			culled = false
		}
		if node.data is BackfaceVisibilityVisualData {
			// The general walk records index 0 and every processed node, including
			// this one, before consulting its plane root.
			mut plane_root := css.FloatMatrix4x4.identity()
			for position := reverse_index; position < count; position++ {
				if chain[position] == node.data.plane_root_index {
					plane_root = matrices[position]
					break
				}
			}
			if !culled && should_cull_back_face(accumulated, plane_root) {
				culled = true
			}
		}
	}
	return culled
}

// Deep chains (or inconsistent depth metadata) keep the map-based walk.
fn (tree &AccumulatedVisualContextTree) context_is_backface_culled_with_depth_fallback(index int,
	snapshot ScrollStateSnapshot) bool {
	chain := tree.build_ancestor_chain(index)
	mut accumulated := css.FloatMatrix4x4.identity()
	mut matrices := map[int]css.FloatMatrix4x4{}
	mut culled := false
	matrices[0] = accumulated
	for reverse_index := chain.len - 1; reverse_index >= 0; reverse_index-- {
		node_index := chain[reverse_index]
		node := tree.nodes[node_index]
		accumulated = accumulated.multiply(visual_context_local_matrix(node, snapshot))
		matrices[node_index] = accumulated
		if node.data is TransformVisualData && node.data.resets_backface_culling {
			culled = false
		}
		if node.data is BackfaceVisibilityVisualData {
			plane_root := matrices[node.data.plane_root_index] or {
				css.FloatMatrix4x4.identity()
			}
			if !culled && should_cull_back_face(accumulated, plane_root) {
				culled = true
			}
		}
	}
	return culled
}

// AccumulatedVisualContextTree::build_ancestor_chain() uses Vector<size_t, 8>
// upstream. Keep the common eight-node chain on the stack as well: pointer
// movement and hit testing call this for several candidate paintables, while a
// plain V array would allocate for every candidate.
const inline_visual_context_ancestor_capacity = 8

fn (tree &AccumulatedVisualContextTree) transform_point_for_hit_test_through_node(index int,
	point Point, snapshot ScrollStateSnapshot) ?Point {
	node := tree.nodes[index]
	return match node.data {
		PerspectiveVisualData {
			inverse := node.data.matrix.inverse() or { return none }
			inverse.map_point(point)
		}
		ScrollVisualData {
			point.subtract(snapshot.device_offset_for_index(node.data.scroll_frame_index))
		}
		ScrollCompensationVisualData {
			point.add(snapshot.device_offset_for_index(node.data.scroll_frame_index))
		}
		TransformVisualData {
			inverse_map_about_origin(point, node.data.matrix, node.data.origin)
		}
		ClipVisualData {
			if !node.data.contains(IntPoint{int(point.x), int(point.y)}) {
				return none
			}
			point
		}
		ClipPathVisualData {
			if !node.data.contains(point) {
				return none
			}
			point
		}
		BackfaceVisibilityVisualData {
			point
		}

		// URL-referenced SVG masks/clips are paint-time masks in
		// StackingContext::paint, not accumulated geometric clips. Upstream hit
		// testing therefore does not reject points outside their painted alpha.
		SVGClipVisualData, SVGMaskVisualData, EffectsVisualData {
			point
		}
	}
}

pub fn (tree &AccumulatedVisualContextTree) transform_point_for_hit_test(index int,
	screen_point Point, snapshot ScrollStateSnapshot) ?Point {
	if index == 0 {
		return screen_point
	}
	if index < 0 || index >= tree.nodes.len {
		return none
	}
	if tree.context_is_backface_culled(index, snapshot) {
		return none
	}
	mut point := screen_point
	depth := tree.nodes[index].depth
	if depth <= inline_visual_context_ancestor_capacity {
		mut inline_chain := [inline_visual_context_ancestor_capacity]int{}
		mut chain_length := 0
		mut current := index
		for current > 0 {
			inline_chain[chain_length] = current
			chain_length++
			current = tree.nodes[current].parent_index
		}
		for reverse_index := chain_length - 1; reverse_index >= 0; reverse_index-- {
			point = tree.transform_point_for_hit_test_through_node(inline_chain[reverse_index], point, snapshot) or { return none }
		}
		return point
	}
	chain := tree.build_ancestor_chain(index)
	for reverse_index := chain.len - 1; reverse_index >= 0; reverse_index-- {
		point = tree.transform_point_for_hit_test_through_node(chain[reverse_index], point, snapshot) or { return none }
	}
	return point
}

fn (tree &AccumulatedVisualContextTree) inverse_transform_point_through_node(index int,
	point Point) Point {
	return match tree.nodes[index].data {
		PerspectiveVisualData {
			if inverse := tree.nodes[index].data.matrix.inverse() {
				inverse.map_point(point)
			} else {
				point
			}
		}
		TransformVisualData {
			if transformed := inverse_map_about_origin(point, tree.nodes[index].data.matrix, tree.nodes[index].data.origin) {
				transformed
			} else {
				point
			}
		}
		else {
			point
		}
	}
}

pub fn (tree &AccumulatedVisualContextTree) inverse_transform_point(index int,
	screen_point Point) Point {
	if index <= 0 || index >= tree.nodes.len {
		return screen_point
	}
	depth := tree.nodes[index].depth
	if depth <= inline_visual_context_ancestor_capacity {
		mut inline_chain := [inline_visual_context_ancestor_capacity]int{}
		mut chain_length := 0
		mut current := index
		for current > 0 {
			inline_chain[chain_length] = current
			chain_length++
			current = tree.nodes[current].parent_index
		}
		mut point := screen_point
		for reverse_index := chain_length - 1; reverse_index >= 0; reverse_index-- {
			point = tree.inverse_transform_point_through_node(inline_chain[reverse_index], point)
		}
		return point
	}
	mut point := screen_point
	chain := tree.build_ancestor_chain(index)
	for reverse_index := chain.len - 1; reverse_index >= 0; reverse_index-- {
		point = tree.inverse_transform_point_through_node(chain[reverse_index], point)
	}
	return point
}

pub fn (tree &AccumulatedVisualContextTree) transform_rect_to_viewport(index int,
	source Rect, snapshot ScrollStateSnapshot) Rect {
	mut rect := source
	mut current := index
	for current > 0 && current < tree.nodes.len {
		node := tree.nodes[current]
		match node.data {
			TransformVisualData {
				rect = rect.translated(node.data.origin.scale(-1))
				rect = node.data.matrix.map_rect(rect)
				rect = rect.translated(node.data.origin)
			}
			PerspectiveVisualData {
				rect = node.data.matrix.map_rect(rect)
			}
			ScrollVisualData {
				rect =
					rect.translated(snapshot.device_offset_for_index(node.data.scroll_frame_index))
			}
			ScrollCompensationVisualData {
				rect = rect.translated(snapshot.device_offset_for_index(node.data.scroll_frame_index).scale(-1))
			}
			else {}
		}
		current = node.parent_index
	}
	return rect
}

pub fn (tree &AccumulatedVisualContextTree) dump(index int) string {
	if index <= 0 || index >= tree.nodes.len {
		return ''
	}
	return match tree.nodes[index].data {
		PerspectiveVisualData {
			'perspective'
		}
		BackfaceVisibilityVisualData {
			'backface-hidden plane_root=${tree.nodes[index].data.plane_root_index}'
		}
		ScrollVisualData {
			'scroll_frame_id=${tree.nodes[index].data.scroll_frame_index}' + if tree.nodes[index].data.is_sticky {
				' (sticky)'
			} else {
				''
			}
		}
		ScrollCompensationVisualData {
			'scroll_compensation(frame_id=${tree.nodes[index].data.scroll_frame_index})'
		}
		TransformVisualData {
			'transform origin=(${tree.nodes[index].data.origin.x},${tree.nodes[index].data.origin.y})'
		}
		ClipVisualData {
			data := tree.nodes[index].data
			'clip=[${data.rect.x},${data.rect.y} ${data.rect.width}x${data.rect.height}]'
		}
		ClipPathVisualData {
			data := tree.nodes[index].data
			'clip_path=[${data.bounding_rect.x},${data.bounding_rect.y} ${data.bounding_rect.width}x${data.bounding_rect.height}]'
		}
		SVGClipVisualData {
			data := tree.nodes[index].data
			'svg_clip=[${data.bounding_rect.x},${data.bounding_rect.y} ${data.bounding_rect.width}x${data.bounding_rect.height}] [components: ${data.components.len}]'
		}
		SVGMaskVisualData {
			data := tree.nodes[index].data
			'svg_mask=[${data.bounding_rect.x},${data.bounding_rect.y} ${data.bounding_rect.width}x${data.bounding_rect.height}] [operations: ${data.operations.len}, type: ${data.mask_type}]'
		}
		EffectsVisualData {
			'effects=[opacity=${tree.nodes[index].data.opacity}]'
		}
	}
}
