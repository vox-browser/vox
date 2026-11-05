module layout

import math
import painting
import platform

// Perspective leaves a z=0 plane unchanged. A flat subtree can therefore
// retain its ordinary compositor pictures; depth transforms and nested
// perspectives keep the existing root-raster fallback.
fn chromium_transform_keeps_z_plane(transform painting.TransformVisualData) bool {
	if !transform.uses_matrix_4x4 { return true }
	m := transform.matrix_4x4
	for row in 0 .. 4 {
		for column in 0 .. 4 {
			value := m.at(row,column)
			if math.is_nan(value) || math.is_inf(value,0) { return false }
		}
	}
	return m.m31 == 0 && m.m32 == 0 && m.m34 == 0
		&& m.m41 == 0 && m.m42 == 0 && m.m44 == 1
}

fn (mut scratch ChromiumRasterPlanScratch) prepare_perspective_rasters(
	tree &painting.AccumulatedVisualContextTree) {
	count := tree.nodes.len
	if scratch.perspective_owners.cap < count || scratch.perspective_root_rasters.cap < count {
		persistent := platform.enter_persistent()
		if scratch.perspective_owners.cap < count {
			scratch.perspective_owners = []int{cap:count}
		}
		if scratch.perspective_root_rasters.cap < count {
			scratch.perspective_root_rasters = []bool{cap:count}
		}
		platform.leave_persistent(persistent)
	}
	scratch.perspective_owners.clear()
	scratch.perspective_root_rasters.clear()
	for _ in 0 .. count {
		scratch.perspective_owners << -1
		scratch.perspective_root_rasters << false
	}
	for index in 1 .. count {
		node := tree.nodes[index]
		parent := node.parent_index
		// -2 carries an unsupported ancestor transform (or broken ancestry)
		// into the next perspective, even when that perspective's own subtree is flat.
		inherited := if parent >= 0 && parent < index {
			scratch.perspective_owners[parent]
		} else { -2 }
		scratch.perspective_owners[index] = inherited
		match node.data {
			painting.PerspectiveVisualData {
				if inherited >= 0 { scratch.perspective_root_rasters[inherited] = true }
				if inherited == -2 { scratch.perspective_root_rasters[index] = true }
				scratch.perspective_owners[index] = index
			}
			painting.TransformVisualData {
				if !chromium_transform_keeps_z_plane(node.data) {
					if inherited >= 0 {
						scratch.perspective_root_rasters[inherited] = true
					} else { scratch.perspective_owners[index] = -2 }
				}
			}
			else {}
		}
	}
}
