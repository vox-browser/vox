module css

import dom

fn redundant_removal_fixture(sources []string) (&dom.Document, &StyleSheetList, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := document.as_node()
	html := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic(err) }
	document_node.append_child(html.as_node()) or { panic(err) }
	mut root := html.as_node()
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	target.set_attribute_value('class', 'target')
	root.append_child(target.as_node()) or { panic(err) }
	mut list := StyleSheetList.create(document_node)
	for source in sources {
		mut style := document.create_element_ns('http://www.w3.org/1999/xhtml', 'style') or { panic(err) }
		root.append_child(style.as_node()) or { panic(err) }
		mut sheet := parse_css_stylesheet_with_parser(source, none)
		sheet.set_owner_node(style)
		list.add_sheet(sheet)
	}
	clear_redundant_removal_flags(document, target)
	return document, list, target
}

fn clear_redundant_removal_flags(document &dom.Document, target &dom.Element) {
	for node in [document.as_node(), target.as_node()] {
		mut n := unsafe { &dom.Node(node) }
		n.set_needs_style_update_internal(false)
		n.set_child_needs_style_update(false)
		n.set_entire_subtree_needs_style_update(false)
		for child in n.children { clear_redundant_removal_subtree(child) }
	}
	mut d := unsafe { &dom.Document(document) }
	d.set_needs_full_style_update(false)
}

fn clear_redundant_removal_subtree(node &dom.Node) {
 mut n := unsafe { &dom.Node(node) }
 n.set_needs_style_update_internal(false)
 n.set_child_needs_style_update(false)
 n.set_entire_subtree_needs_style_update(false)
 for child in n.children { clear_redundant_removal_subtree(child) }
}

fn test_redundant_sheet_removal_keeps_ownership_and_pending_invalidations() {
	document, mut list, target := redundant_removal_fixture(['.target {color:red}', '.target {color:red}'])
	defer { document.finalize() }
	sheet := list.sheets[0]
	list.remove_sheet(sheet)
	assert list.sheets.len == 1
	assert sheet.owning_documents_or_shadow_roots.len == 0
	assert target.needs_style_update() == retain_redundant_sheet_removal
	// A previous insert or unrelated mutation must still be processed.
	mut node := target.as_node()
	node.set_needs_style_update_internal(true)
	mut duplicate := parse_css_stylesheet_with_parser('.target {color:red}', none)
	duplicate.set_owner_node(list.sheets[0].base.owner_node)
	list.sheets.prepend(duplicate)
	duplicate.add_owning_document_or_shadow_root(document.as_node())
	list.remove_sheet(duplicate)
	assert target.needs_style_update()
}

fn test_redundant_sheet_removal_ignores_only_never_seen_leaf_tags() {
	for metadata in ['unseen.target {color:blue}', 'unseen::before {content:"x"}',
		'unseen.a, another.b {color:blue}'] {
		document, mut list, target := redundant_removal_fixture(['.target {color:red}' + metadata, '.target {color:red}'])
		list.remove_sheet(list.sheets[0])
		assert target.needs_style_update() == retain_redundant_sheet_removal
		document.finalize()
	}
	for metadata in ['unseen .target {color:blue}', 'unseen.a, .target {color:blue}',
		'unseen { .target {color:blue} }'] {
		document, mut list, target := redundant_removal_fixture(['.target {color:red}' + metadata, '.target {color:red}'])
		assert !list.removal_has_equivalent_following_sheet(list.sheets[0])
		document.finalize()
	}
}

fn test_redundant_sheet_removal_remembers_removed_tag_names() {
	mut document, mut list, target := redundant_removal_fixture(['.target {color:red} unseen {color:blue}', '.target {color:red}'])
	defer { document.finalize() }
	mut root := target.as_node().parent() or { panic("missing parent") }
	unseen := document.create_element_ns('http://www.w3.org/1999/xhtml', 'unseen') or { panic(err) }
	root.append_child(unseen.as_node()) or { panic(err) }
	root.remove_child(unseen.as_node()) or { panic(err) }
	clear_redundant_removal_flags(document, target)
	assert document.has_seen_element_local_name('unseen')
	assert !list.removal_has_equivalent_following_sheet(list.sheets[0])
	list.remove_sheet(list.sheets[0])
	assert target.needs_style_update()
}

fn test_redundant_sheet_removal_requires_the_entire_ordered_sequence() {
	for replacement in ['.target {color:red}',
		'.target {color:blue} .target {color:red}',
		'.target {color:red} .target {color:green}',
		'.target {color:red!important} .target {color:blue}',
		'.target {color:red} .other {color:blue}'] {
		document, mut list, target := redundant_removal_fixture(['.target {color:red} .target {color:blue}', replacement])
		list.remove_sheet(list.sheets[0])
		assert target.needs_style_update()
		document.finalize()
	}
}

fn test_redundant_sheet_removal_does_not_cross_an_intervening_sheet() {
	document, mut list, target := redundant_removal_fixture(['.target {color:red}', '.target {color:blue}', '.target {color:red}'])
	defer { document.finalize() }
	list.remove_sheet(list.sheets[0])
	assert target.needs_style_update()
}

fn test_redundant_sheet_removal_preserves_media_and_global_rule_effects() {
	for source in ['@media all {.target {color:red}}',
		'@supports (display:block) {.target {--x:1;color:var(--x)}}'] {
		document, mut list, target := redundant_removal_fixture([source, source])
		list.remove_sheet(list.sheets[0])
		assert target.needs_style_update() == retain_redundant_sheet_removal
		document.finalize()
	}
	for source in ['@keyframes A {to {opacity:0}}', '@font-face {font-family:A;src:url(a.woff2)}',
		'@layer A {.target {color:red}}', '@property --x {syntax:"<color>";inherits:true;initial-value:red}',
		'@namespace url(http://www.w3.org/1999/xhtml); .target {color:red}'] {
		document, list, _ := redundant_removal_fixture([source, source])
		assert !list.removal_has_equivalent_following_sheet(list.sheets[0])
		document.finalize()
	}
}

fn test_redundant_sheet_removal_rejects_different_bases_media_and_disabled_sheets() {
	for change in ['location', 'base', 'media', 'condition', 'disabled', 'constructed'] {
		document, list, _ := redundant_removal_fixture(['.target {background:url(image.png)}', '.target {background:url(image.png)}'])
		mut following := list.sheets[1]
		match change {
			'location' { following.base.location = 'https://example.com/a/' }
			'base' { following.base_url = 'https://example.com/b/' }
			'media' { following.set_media('not all') }
			'condition' { following.did_match = false }
			'disabled' { following.base.disabled = true }
			else { following.constructed = true }
		}
		assert !list.removal_has_equivalent_following_sheet(list.sheets[0])
		document.finalize()
	}
}

fn test_redundant_sheet_removal_rechecks_live_declarations_and_later_edits() {
	document, mut list, target := redundant_removal_fixture(['.target {--x:red;color:var(--x)}', '.target {--x:red;color:var(--x)}'])
	defer { document.finalize() }
	mut following := list.sheets[1]
	mut declaration := following.rules.rules[0].style() or { panic("missing style") }
	declaration.set_property('--x', 'blue', '') or { panic(err) }
	assert !list.removal_has_equivalent_following_sheet(list.sheets[0])
	declaration.set_property('--x', 'red', '') or { panic(err) }
	list.remove_sheet(list.sheets[0])
	clear_redundant_removal_flags(document, target)
	declaration.set_property('color', 'green', '') or { panic(err) }
	assert target.needs_style_update() || document.needs_full_style_update()
}

fn test_redundant_sheet_removal_preserves_future_tag_insertion_and_media_changes() {
	mut document, mut list, target := redundant_removal_fixture([
		'@media all {.target {color:red}} unseen {color:blue}',
		'@media all {.target {color:red}} unseen {color:blue}',
	])
	defer { document.finalize() }
	list.remove_sheet(list.sheets[0])
	clear_redundant_removal_flags(document, target)
	mut root := target.as_node().parent() or { panic('missing parent') }
	unseen := document.create_element_ns('http://www.w3.org/1999/xhtml', 'unseen') or { panic(err) }
	root.append_child(unseen.as_node()) or { panic(err) }
	assert unseen.needs_style_update()
	clear_redundant_removal_flags(document, target)
	mut remaining := list.sheets[0]
	remaining.set_media('not all')
	assert target.needs_style_update() || document.needs_full_style_update()
}
