module layout

import os

const disable_markerless_measurements = os.getenv('VOX_DISABLE_MARKERLESS_MEASUREMENTS') != ''
const markerless_measurement_diagnostics = os.getenv('VOX_MARKERLESS_MEASUREMENT_DIAGNOSTICS') != ''

__global markerless_measurement_reported bool

fn measurement_list_item_has_no_marker(node &Node) bool {
	item := node.as_list_item_box() or { return false }
	return item.marker() == none
}

fn report_markerless_measurement_reuse(inputs []RetainedInlineInput) {
	if !markerless_measurement_diagnostics || markerless_measurement_reported { return }
	if inputs.any(it.node.is_list_item_box()) {
		markerless_measurement_reported = true
		eprintln('Vox markerless measurement: reused closed list-item geometry')
	}
}
