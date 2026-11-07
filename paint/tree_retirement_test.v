module main

import html
import layout

fn test_shell_retains_previous_tree_until_geometry_and_scene_are_replaced() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{width:30px;height:20px;background:red}</style><div id="target"></div>')
	mut app := BrowserApp{document: document}
	defer { app.dispose_browser_tab() }
	app.relayout(200, 232)
	$if prealloc { assert app.paint_tree_storage != unsafe { nil } }
	geometry := layout.retain_document_paint_tree(document)
	old_tree := app.root_box
	old_scene := app.paint_scene
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	identity := i64(target.as_node().unique_id())
	app.begin_frame_preparation()
	target.set_attribute_value('style', 'width:70px;background:rgb(71 72 73)')
	app.relayout(200, 232)
	assert app.root_box.find_box(identity)?.width == 70
	assert app.paint_scene == old_scene
	layout.release_paint_tree(geometry)
	// The adopted scene is now the old tree's only reader in the shell.
	assert old_tree.find_box(identity)?.width == 30
	app.finish_frame_preparation()
	assert app.root_box.find_box(identity)?.width == 70
	assert app.paint_commands.any(it.color == 'rgb(71 72 73)')
}

fn test_tab_disposal_releases_shell_geometry_and_scene_handles() {
	mut app := BrowserApp{document: html.parse_document('<!doctype html><p>Retired tree</p>')}
	app.relayout(200, 232)
	$if prealloc { assert app.paint_tree_storage != unsafe { nil } }
	assert app.paint_scene != unsafe { nil }
	app.dispose_browser_tab()
	assert app.paint_tree_storage == unsafe { nil }
	assert app.paint_scene == unsafe { nil }
	assert app.paint_display_list == unsafe { nil }
	assert app.paint_commands.len == 0
	assert app.root_box.children.len == 0
}
