module main

import dom
import html
import page

fn test_script_commit_adopts_already_flushed_geometry_and_matches_shell_relayout() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}textarea{width:180px;height:40px}</style><body><textarea id="editor">before</textarea><p id="sibling">Story</p></body>')
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut navigable := &dom.Navigable{active_document_: document, is_top_level_traversable_: true}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	rendering_page := page.Page.create(1)!
	document.set_page(unsafe { &dom.Page(rendering_page) })
	mut app := BrowserApp{document: document}
	defer { app.adblock_tokens.release() }
	app.relayout(320, 312)
	mut editor := document.get_element_by_id('editor')?
	dom.run_focusing_steps_for_node(editor.as_node(), none, .click)
	editor.set_attribute_value('style', 'width:210px')
	// Model an input listener's synchronous getClientRects() flush.
	assert editor.get_bounding_client_rect().width >= 210
	assert document.layout_is_up_to_date()
	adoptions := javascript_paint_sync_adoptions
	app.begin_frame_preparation()
	app.synchronize_javascript_task_paint(true)
	assert (javascript_paint_sync_adoptions > adoptions) == !disable_javascript_paint_only_sync
	app.finish_frame_preparation()
	actual := document.record_display_list()?.dump()
	app.relayout(320, 312)
	expected := document.record_display_list()?.dump()
	assert expected == actual, 'adopted:\n${actual}\nfull shell:\n${expected}'
	assert app.viewport_width == 320
}

fn test_script_commit_still_applies_cosmetic_mutations_after_a_geometry_flush() {
	mut document := html.parse_document('<!doctype html><body><div id="cookie-banner">We use cookies. <button>Accept</button></div></body>')
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut navigable := &dom.Navigable{active_document_: document, is_top_level_traversable_: true}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	rendering_page := page.Page.create(1)!
	document.set_page(unsafe { &dom.Page(rendering_page) })
	mut app := BrowserApp{document: document}
	defer { app.adblock_tokens.release() }
	app.relayout(320, 312)
	mut banner := document.get_element_by_id('cookie-banner')?
	banner.set_attribute_value('style', 'display:block!important')
	_ = banner.get_bounding_client_rect()
	assert document.layout_is_up_to_date()
	app.synchronize_javascript_task_paint(true)
	assert document.layout_is_up_to_date()
	assert banner.get_bounding_client_rect().height == 0
	actual := document.record_display_list()?.dump()
	app.relayout(320, 312)
	assert document.record_display_list()?.dump() == actual
}
