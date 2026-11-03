module layout

import dom
import os

const retain_grid_placement_copies = os.getenv('VOX_RETAIN_GRID_PLACEMENT_COPIES') != ''
const grid_placement_reuse_diagnostics = os.getenv('VOX_GRID_PLACEMENT_REUSE_DIAGNOSTICS') != ''

__global grid_placement_reported_document dom.UniqueNodeID

// Both sizing lists are read-only. The collector changes placements only
// when projecting descendants of an item subgridded in the requested axis.
// All ordinary entries are already identical to the original placement list.
fn ordinary_grid_sizing_placements(placements []GridItemPlacement, columns bool) bool {
	if retain_grid_placement_copies { return false }
	for placement in placements {
		item := placement.item
		if !item.display().is_grid_inside() { continue }
		template := if columns {
			item.computed_values().grid_template_columns()
		} else {
			item.computed_values().grid_template_rows()
		}
		if template.is_subgrid() { return false }
	}
	return true
}

fn report_grid_placement_reuse(container &Node, count int) {
	if !grid_placement_reuse_diagnostics || count == 0 { return }
	document := container.document()
	identity := document.as_node().unique_id()
	if grid_placement_reported_document != identity {
		grid_placement_reported_document = identity
		eprintln('Vox grid placement: reused ordinary sizing placements without copying; document=${document.url.serialize()}')
	}
}
