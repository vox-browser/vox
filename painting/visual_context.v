module painting

pub struct ScrollVisualData {
pub:
	scroll_frame_index int
	is_sticky          bool
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
	origin Point
	matrix Affine
}

pub struct PerspectiveVisualData {
pub:
	matrix Affine
}

pub struct ClipPathVisualData {
pub:
	bounding_rect IntRect
	polygon       []Point
	fill_rule     WindingRule = .nonzero
}

fn edge_side(start Point, end Point, point Point) f64 {
	return (end.x - start.x) * (point.y - start.y) - (point.x - start.x) * (end.y - start.y)
}

pub fn polygon_contains_with_rule(polygon []Point, point Point, rule WindingRule) bool {
	if polygon.len < 3 {
		return false
	}
	mut crossings := 0
	mut winding := 0
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
	return if rule == .even_odd { crossings % 2 == 1 } else { winding != 0 }
}

pub fn (clip ClipPathVisualData) contains(point Point) bool {
	if !clip.bounding_rect.contains(IntPoint{int(point.x), int(point.y)}) {
		return false
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
	| ScrollVisualData
	| TransformVisualData

pub struct AccumulatedVisualContextNode {
pub:
	data                     VisualContextData
	parent_index             int
	depth                    int
	has_empty_effective_clip bool
}

pub struct AccumulatedVisualContextTree {
pub mut:
	nodes []AccumulatedVisualContextNode
}

pub fn new_accumulated_visual_context_tree() AccumulatedVisualContextTree {
	return AccumulatedVisualContextTree{
		nodes: [AccumulatedVisualContextNode{ data: ScrollVisualData{} }]
	}
}

pub fn (mut tree AccumulatedVisualContextTree) append(data VisualContextData, parent int) int {
	depth := if parent > 0 && parent < tree.nodes.len { tree.nodes[parent].depth + 1 } else { 1 }
	mut empty_clip := parent > 0 && parent < tree.nodes.len
		&& tree.nodes[parent].has_empty_effective_clip
	if !empty_clip {
		empty_clip = match data {
			ClipVisualData { data.rect.is_empty() }
			ClipPathVisualData { data.bounding_rect.is_empty() || data.polygon.len < 3 }
			else { false }
		}
	}
	index := tree.nodes.len
	tree.nodes << AccumulatedVisualContextNode{data, parent, depth, empty_clip}
	return index
}

pub fn (tree AccumulatedVisualContextTree) find_common_ancestor(first int, second int) int {
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

pub fn (tree AccumulatedVisualContextTree) ancestor_chain(index int) []int {
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

pub fn (tree AccumulatedVisualContextTree) transform_point_for_hit_test(index int,
	screen_point Point, snapshot ScrollStateSnapshot) ?Point {
	if index == 0 {
		return screen_point
	}
	chain := tree.ancestor_chain(index)
	mut point := screen_point
	for reverse_index := chain.len - 1; reverse_index >= 0; reverse_index-- {
		node := tree.nodes[chain[reverse_index]]
		match node.data {
			PerspectiveVisualData {
				inverse := node.data.matrix.inverse() or { return none }
				point = inverse.map_point(point)
			}
			ScrollVisualData {
				point =
					point.subtract(snapshot.device_offset_for_index(node.data.scroll_frame_index))
			}
			TransformVisualData {
				point = inverse_map_about_origin(point, node.data.matrix, node.data.origin) or {
					return none
				}
			}
			ClipVisualData {
				if !node.data.contains(IntPoint{int(point.x), int(point.y)}) {
					return none
				}
			}
			ClipPathVisualData {
				if !node.data.contains(point) {
					return none
				}
			}
			EffectsVisualData {}
		}
	}
	return point
}

pub fn (tree AccumulatedVisualContextTree) inverse_transform_point(index int,
	screen_point Point) Point {
	mut point := screen_point
	chain := tree.ancestor_chain(index)
	for reverse_index := chain.len - 1; reverse_index >= 0; reverse_index-- {
		match tree.nodes[chain[reverse_index]].data {
			PerspectiveVisualData {
				if inverse := tree.nodes[chain[reverse_index]].data.matrix.inverse() {
					point = inverse.map_point(point)
				}
			}
			TransformVisualData {
				data := tree.nodes[chain[reverse_index]].data
				if transformed := inverse_map_about_origin(point, data.matrix, data.origin) {
					point = transformed
				}
			}
			else {}
		}
	}
	return point
}

pub fn (tree AccumulatedVisualContextTree) transform_rect_to_viewport(index int,
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
			else {}
		}
		current = node.parent_index
	}
	return rect
}

pub fn (tree AccumulatedVisualContextTree) is_effect(index int) bool {
	if index <= 0 || index >= tree.nodes.len {
		return false
	}
	return tree.nodes[index].data is EffectsVisualData
}

pub fn (tree AccumulatedVisualContextTree) dump(index int) string {
	if index <= 0 || index >= tree.nodes.len {
		return ''
	}
	return match tree.nodes[index].data {
		PerspectiveVisualData {
			'perspective'
		}
		ScrollVisualData {
			'scroll_frame_id=${tree.nodes[index].data.scroll_frame_index}' + if tree.nodes[index].data.is_sticky {
				' (sticky)'
			} else {
				''
			}
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
		EffectsVisualData {
			'effects=[opacity=${tree.nodes[index].data.opacity}]'
		}
	}
}
