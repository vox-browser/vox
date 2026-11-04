module css

import dom

fn fresh_following_media_fixture(source string) (&dom.Document, &StyleSheetList, &dom.Element) {
	mut document, list, target := redundant_removal_fixture([source,source])
	document.set_viewport_rect(dom.Rect{width:800,height:600})
	mut old := list.sheets[0]
	old.evaluate_media_queries(document)
	// The viewport update initialized the original fixture's sheets. Model the
	// parser's replacement after that update, retaining its real style owner.
	mut prior := list.sheets[1]
	mut fresh := parse_css_stylesheet_with_parser(source, none)
	fresh.set_owner_node(prior.base.owner_node)
	prior.remove_owning_document_or_shadow_root(document.as_node())
	fresh.add_owning_document_or_shadow_root(document.as_node())
	unsafe { list.sheets[1] = fresh }
	assert list.sheets[1].did_match == none
	clear_redundant_removal_flags(document,target)
	return document,list,target
}

fn test_fresh_following_sheet_proves_current_media_without_consuming_cached_state() {
	for source in ['.target{color:red}', '@media(min-width:700px){.target{color:red}}', '@supports(display:block){@media(min-width:700px){.target{color:red}}}'] {
		document, mut list, target := fresh_following_media_fixture(source)
		defer { document.finalize() }
		following := list.sheets[1]
		before := following.base.media.media.clone()
		plan := list.removal_following_sheet_changes(list.sheets[0])
		assert (plan != none) == !retain_unevaluated_following_sheet
		assert following.did_match == none
		assert following.base.media.media == before
		if first := following.rules.item(0) {
			if first.type_ == .media { assert !first.did_evaluate }
		}
		list.remove_sheet(list.sheets[0])
		assert target.needs_style_update() == retain_unevaluated_following_sheet
		assert list.sheets.len == 1
		assert following.did_match == none
	}
}

fn test_fresh_following_sheet_keeps_changed_declarations_targeted_and_pending_dirty() {
	document, mut list, target := fresh_following_media_fixture('.target{color:red}.other{color:blue}')
	defer { document.finalize() }
	mut following := list.sheets[1]
	mut declaration := following.rules.item(1)?.style()?
	declaration.set_property('color','lime','')!
	mut pending := target.as_node()
	pending.set_needs_style_update_internal(true)
	plan := list.removal_following_sheet_changes(list.sheets[0])
	if !retain_unevaluated_following_sheet {
		changed := plan?
		assert changed.len == 1
		assert changed[0].selector_text() == '.other'
	}
	list.remove_sheet(list.sheets[0])
	assert pending.needs_style_update()
}

fn test_fresh_following_sheet_rejects_stale_removed_media_and_already_evaluated_nested_media() {
	mut document, list, _ := fresh_following_media_fixture('@media(min-width:700px){.target{color:red}}')
	defer { document.finalize() }
	document.set_viewport_rect(dom.Rect{width:600,height:600})
	assert list.removal_following_sheet_changes(list.sheets[0]) == none
	document.set_viewport_rect(dom.Rect{width:800,height:600})
	mut following_media := list.sheets[1].rules.item(0)?
	following_media.evaluate_media(document)
	assert following_media.did_evaluate
	assert list.removal_following_sheet_changes(list.sheets[0]) == none
	assert list.sheets[1].did_match == none
}

fn test_fresh_following_sheet_keeps_bases_global_effects_and_selector_order_guards() {
	for source in ['@font-face{font-family:A;src:url(a.woff2)}', '@layer A{.target{color:red}}', '@namespace url(http://example.test);.target{color:red}'] {
		document, list, _ := fresh_following_media_fixture(source)
		defer { document.finalize() }
		assert list.removal_following_sheet_changes(list.sheets[0]) == none
	}
	document, list, _ := fresh_following_media_fixture('.target{background:url(a.png)}')
	defer { document.finalize() }
	mut following := list.sheets[1]
	following.base_url = 'https://different.test/'
	assert list.removal_following_sheet_changes(list.sheets[0]) == none
}

fn test_fresh_following_sheet_root_media_snapshot_preserves_uninitialized_entries() {
	document, list, _ := fresh_following_media_fixture('.target{color:red}')
	defer { document.finalize() }
	mut old := list.sheets[0]
	mut following := list.sheets[1]
	old.set_media('(min-width:700px)')
	old.evaluate_media_queries(document)
	// Install parser-created media data without the CSSOM setter, which also
	// schedules and evaluates the owning document's sheets.
	following.did_match = none
	following.base.media = MediaList.create([MediaQueryListEntry{text:'(min-width: 700px)'}])
	before := following.base.media.media.clone()
	assert (list.removal_following_sheet_changes(old) != none) == !retain_unevaluated_following_sheet
	assert following.base.media.media == before
	assert following.did_match == none
}

fn test_fresh_following_sheet_rejects_different_title_and_alternate_selection() {
	for field in ['title','alternate'] {
		document, list, _ := fresh_following_media_fixture('.target{color:red}')
		defer { document.finalize() }
		mut following := list.sheets[1]
		if field == 'title' { following.base.title = 'other' } else { following.base.alternate = true }
		assert list.removal_following_sheet_changes(list.sheets[0]) == none
		assert following.did_match == none
	}
}

fn test_fresh_following_sheet_removal_preserves_cascade_and_future_cssom_changes() {
	mut document, mut list, target := fresh_following_media_fixture('.target{color:red}')
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{active_document_:document})
	document.set_navigable(&dom.Navigable{active_document_:document})
	mut scope := css_style_scope_for_document(document)
	scope.style_sheets = list
	css_style_computer_for(document)
	document.update_style()
	assert (computed_value_for(target,.color) or { panic('missing color') }) == 'rgb(255, 0, 0)'
	mut previous := list.sheets[1]
	mut fresh := parse_css_stylesheet_with_parser('.target{color:red}',none)
	fresh.set_owner_node(previous.base.owner_node)
	previous.remove_owning_document_or_shadow_root(document.as_node())
	fresh.add_owning_document_or_shadow_root(document.as_node())
	list.sheets[1] = fresh
	list.remove_sheet(list.sheets[0])
	document.update_style()
	assert (computed_value_for(target,.color) or { panic('missing color') }) == 'rgb(255, 0, 0)'
	mut declaration := fresh.rules.item(0)?.style()?
	declaration.set_property('color','blue','')!
	document.update_style()
	assert (computed_value_for(target,.color) or { panic('missing color') }) == 'rgb(0, 0, 255)'
}
