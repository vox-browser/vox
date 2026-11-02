module layout

import dom
import html

const fixed_raster_card = '<div class="fixed"><div class="card"></div></div>'
const fixed_raster_icon = '<div class="footer"><svg width="40" height="40" viewBox="0 0 40 40"><path d="M2 2L38 19L8 38Z" fill="#333"/></svg></div>'

fn fixed_raster_identity_fixture(content string, extra_style string) (&dom.Document, []PaintCommand, ChromiumRasterLayerPlan) {
	mut document := html.parse_document('<!doctype html><style>*{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;overflow:hidden}.fixed{position:fixed;left:260px;right:0;top:61px;bottom:76px}.card{position:absolute;left:12px;bottom:8px;width:740px;height:126.03125px;border:1px solid rgb(0 0 0/.05);border-radius:30px;box-shadow:0 4px 16px rgb(0 0 0/.05);background:white}.footer{position:fixed;left:280px;bottom:20px;width:740px;height:40px}${extra_style}</style>${content}')
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 1024, 768)
	commands := display_list_commands(document.record_display_list() or { panic('missing display list') })
	plan := chromium_raster_layer_plan(document, commands, 1)
	assert plan.layers.len > 1
	return document, commands, plan
}

fn fixed_raster_card_and_icon_layers(commands []PaintCommand, plan ChromiumRasterLayerPlan) (int, int) {
	mut card := -1
	mut icon := -1
	for index, command in commands {
		if command.kind == 'paint_uniform_border' { card = plan.command_layers[index] }
		if command.kind == 'draw_svg_path' { icon = plan.command_layers[index] }
	}
	assert card > 0
	assert icon > 0
	return card, icon
}

fn test_sibling_viewport_fixed_containers_keep_independent_raster_coverage() {
	for content in [fixed_raster_card + fixed_raster_icon, fixed_raster_icon + fixed_raster_card] {
		mut document, commands, plan := fixed_raster_identity_fixture(content, '')
		defer { document.finalize() }
		card, icon := fixed_raster_card_and_icon_layers(commands, plan)
		assert card != icon
		assert plan.layers[card].composited_contents
		assert plan.layers[icon].composited_contents
	}
}

fn test_descendants_of_the_same_fixed_container_can_share_raster_coverage() {
	mut document, commands, plan := fixed_raster_identity_fixture(
		'<div class="fixed"><div class="card"></div>${fixed_raster_icon}</div>',
		'.footer{position:absolute;left:20px;bottom:-56px}')
	defer { document.finalize() }
	card, icon := fixed_raster_card_and_icon_layers(commands, plan)
	assert card == icon
}

fn test_viewport_metadata_planner_preserves_fixed_container_identity() {
	mut document, commands, _ := fixed_raster_identity_fixture(fixed_raster_icon + fixed_raster_card, '')
	defer { document.finalize() }
	mut plan := ChromiumRasterLayerPlan{}
	update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
		LayoutRect{0, 0, 1024, 768}, mut plan)
	card, icon := fixed_raster_card_and_icon_layers(commands, plan)
	assert card != icon
}
