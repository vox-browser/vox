module main

import dom
import html
import css

fn preload_plan_test_document(markup string) &dom.Document {
	address := dom.URL{value: 'https://preload-plan.test/dir/index.html'}
	mut document := html.parse_navigation_document(markup, address, address.origin(), none) or { panic(err) }
	document.set_scripting_enabled_by_embedder(false)
	document.set_viewport_rect(dom.Rect{x: 0, y: 0, width: 1024, height: 768})
	return document
}

fn test_nonrendered_preload_plan_honors_closed_dialog_and_author_display_override() {
	mut document := preload_plan_test_document('<!doctype html><style>dialog.shown { display: block }</style><dialog><img loading="lazy" src="hidden.png"></dialog><dialog class="shown"><img loading="lazy" src="shown.png"></dialog><dialog open><img src="open.png"></dialog><img loading="lazy" src="visible-lazy.png">')
	defer { document.finalize() }
	urls := document_preload_resource_urls(document, document.base_url().serialize())
	foreground, background := partition_nonrendered_image_preloads(document, document.base_url().serialize(), urls)
	assert background == ['https://preload-plan.test/dir/hidden.png']
	assert foreground == ['https://preload-plan.test/dir/shown.png', 'https://preload-plan.test/dir/open.png', 'https://preload-plan.test/dir/visible-lazy.png']
}

fn test_nonrendered_preload_plan_promotes_visible_duplicate_and_keeps_ancestor_hidden() {
	mut document := preload_plan_test_document('<!doctype html><style>.hidden { display:none } .contents { display:contents }</style><div class="hidden"><img src="shared.png"><div style="display:block"><img src="hidden.png"></div></div><div class="contents"><img src="shared.png"></div><img style="display:none" src="self.png">')
	defer { document.finalize() }
	base := document.base_url().serialize()
	foreground, background := partition_nonrendered_image_preloads(document, base, document_preload_resource_urls(document, base))
	assert foreground == ['https://preload-plan.test/dir/shared.png']
	assert background == ['https://preload-plan.test/dir/hidden.png', 'https://preload-plan.test/dir/self.png']
}

fn test_nonrendered_preload_plan_keeps_other_roles_unknown_and_css_image_urls_foreground() {
	mut document := preload_plan_test_document('<!doctype html><style>.paint { background-image: url("css.png") }</style><div class="paint"></div><dialog><img src="css.png"><img src="svg.png"><img src="sheet.png"><img src="inline.png"><img src="only-hidden.png"></dialog><svg><image href="svg.png"/></svg><link rel="stylesheet" href="sheet.png"><div style="background-image:url(inline.png)"></div>')
	defer { document.finalize() }
	base := document.base_url().serialize()
	mut urls := document_preload_resource_urls(document, base)
	urls << 'https://preload-plan.test/dir/plain-css.png'
	foreground, background := partition_nonrendered_image_preloads(document, base, urls)
	assert background == ['https://preload-plan.test/dir/only-hidden.png']
	assert 'https://preload-plan.test/dir/plain-css.png' in foreground
	assert foreground.len == urls.len - 1
}

fn test_nonrendered_preload_plan_preserves_each_other_role_reference_attribute() {
	mut document := preload_plan_test_document('<!doctype html><dialog><img src="source.png"><img src="href.png"><img src="xlink.png"><img src="poster.png"><img src="data.png"><img src="hidden.png"></dialog><input type="image" src="source.png"><svg><image href="href.png"/><image xlink:href="xlink.png"/></svg><video poster="poster.png"></video><object data="data.png"></object>')
	defer { document.finalize() }
	base := document.base_url().serialize()
	urls := ['https://preload-plan.test/dir/source.png', 'https://preload-plan.test/dir/href.png',
		'https://preload-plan.test/dir/xlink.png', 'https://preload-plan.test/dir/poster.png',
		'https://preload-plan.test/dir/data.png', 'https://preload-plan.test/dir/hidden.png']
	foreground, background := partition_nonrendered_image_preloads(document, base, urls)
	assert foreground == urls[..5]
	assert background == ['https://preload-plan.test/dir/hidden.png']
}

fn test_nonrendered_preload_plan_resolves_external_css_urls_and_replans_after_live_change() {
	mut document := preload_plan_test_document('<!doctype html><style data-libweb-v-source-url="https://preload-plan.test/assets/site.css">.paint { background-image: image-set("../dir/shared.png" 1x) }</style><div class="paint"></div><dialog id="dialog"><img src="shared.png"><img src="hidden.png"></dialog>')
	defer { document.finalize() }
	base := document.base_url().serialize()
	urls := document_preload_resource_urls(document, base)
	foreground, background := partition_nonrendered_image_preloads(document, base, urls)
	assert foreground == ['https://preload-plan.test/dir/shared.png']
	assert background == ['https://preload-plan.test/dir/hidden.png']
	mut dialog := document.get_element_by_id('dialog') or { panic('missing dialog') }
	dialog.set_attribute_value('open', '')
	updated_foreground, updated_background := partition_nonrendered_image_preloads(document, base, urls)
	assert updated_foreground == urls
	assert updated_background == []string{}
	document.set_scripting_enabled_by_embedder(true)
	dialog.remove_attribute('open')
	scripted_foreground, scripted_background := partition_nonrendered_image_preloads(document, base, urls)
	assert scripted_foreground == urls
	assert scripted_background == []string{}
}

fn test_nonrendered_preload_plan_preserves_imported_and_cssom_changed_rule_urls() {
	mut document := preload_plan_test_document('<!doctype html><style id="sheet">@import url("nested.css"); .paint { color:red }</style><div class="paint"></div><dialog><img src="imported.png"><img src="cssom.png"><img src="hidden.png"></dialog>')
	defer { document.finalize() }
	owner := document.get_element_by_id('sheet') or { panic('missing sheet owner') }
	sheet := css.style_sheet_for_owner_node(document, owner) or { panic('missing live sheet') }
	mut import_rule := sheet.css_rules().item(0) or { panic('missing import rule') }
	imported := css.parse_css_stylesheet_with_parser('@media screen { .paint { background-image: url("../dir/imported.png") } }', 'https://preload-plan.test/assets/nested.css')
	import_rule.set_style_sheet(imported)
	rule := sheet.css_rules().item(1) or { panic('missing style rule') }
	mut declaration := rule.style() or { panic('missing declaration') }
	declaration.set_property('border-image-source', 'url("cssom.png")', '')!
	base := document.base_url().serialize()
	foreground, background := partition_nonrendered_image_preloads(document, base, document_preload_resource_urls(document, base))
	assert foreground == ['https://preload-plan.test/dir/imported.png', 'https://preload-plan.test/dir/cssom.png']
	assert background == ['https://preload-plan.test/dir/hidden.png']
}

fn test_nonrendered_preload_plan_preserves_adopted_sheet_and_escaped_css_urls() {
	mut document := preload_plan_test_document('<!doctype html><div class="paint"></div><dialog><img src="adopted.png"><img src="escaped.png"><img src="hidden.png"></dialog>')
	defer { document.finalize() }
	mut sheet := css.css_style_sheet_construct(css.CSSStyleSheetInit{
		base_url: 'https://preload-plan.test/assets/site.css'
	}, document)!
	sheet.replace_sync(r'.paint { background-image: image-set("../dir/adopted.png" 1x); border-image-source: url("../dir/esc\61 ped.png"); }')!
	mut adopted := css.create_adopted_style_sheets_list(document.as_node())
	adopted.append(sheet)!
	base := document.base_url().serialize()
	foreground, background := partition_nonrendered_image_preloads(document, base, document_preload_resource_urls(document, base))
	assert foreground == ['https://preload-plan.test/dir/adopted.png', 'https://preload-plan.test/dir/escaped.png']
	assert background == ['https://preload-plan.test/dir/hidden.png']
}

fn test_nonrendered_preload_plan_preserves_srcset_and_picture_consumers() {
	mut document := preload_plan_test_document('<!doctype html><dialog><img src="retina.png"><img src="picture.png"><img src="hidden.png"></dialog><img src="logo.png" srcset="logo.png 1x, retina.png 2x"><picture><source media="(min-width:900px)" srcset="picture.png 900w"><img src="fallback.png"></picture>')
	defer { document.finalize() }
	base := document.base_url().serialize()
	urls := document_preload_resource_urls(document, base)
	foreground, background := partition_nonrendered_image_preloads(document, base, urls)
	assert background == ['https://preload-plan.test/dir/hidden.png']
	assert 'https://preload-plan.test/dir/retina.png' in foreground
	assert 'https://preload-plan.test/dir/picture.png' in foreground
	assert 'https://preload-plan.test/dir/logo.png' in foreground
}

fn test_nonrendered_preload_plan_retains_barrier_for_author_shadow_consumers_but_not_controls() {
	mut document := preload_plan_test_document('<!doctype html><div id="internal"></div><div id="author"></div><dialog><img src="shared.png"><img src="hidden.png"></dialog>')
	defer { document.finalize() }
	base := document.base_url().serialize()
	urls := document_preload_resource_urls(document, base)
	mut internal := document.get_element_by_id('internal') or { panic('missing internal host') }
	internal.attach_a_user_agent_shadow_root(.named)
	foreground, background := partition_nonrendered_image_preloads(document, base, urls)
	assert foreground == []string{}
	assert background == urls
	mut author := document.get_element_by_id('author') or { panic('missing author host') }
	mut shadow := author.attach_shadow(dom.ShadowRootInit{mode: .open})!
	shadow.set_declarative(true)
	mut style := document.create_element('style')!
	mut style_node := style.as_node()
	style_node.set_text_content('.paint { background-image:url(shared.png) }')!
	mut shadow_node := shadow.as_node()
	shadow_node.append_child(style_node)!
	guarded_foreground, guarded_background := partition_nonrendered_image_preloads(document, base, urls)
	assert guarded_foreground == urls
	assert guarded_background == []string{}
}

fn test_nonrendered_preload_plan_keeps_deferred_variable_image_urls_foreground() {
	// Cross the DOM-owned sheet's deferred-declaration threshold. The unused
	// selector still supplies a conservative URL candidate without requiring
	// property conversion, including a custom-property image-set fallback.
	padding := '/*${'padding '.repeat(2200)}*/'
	mut document := preload_plan_test_document('<!doctype html><style>${padding}.unused { --image:var(--other,image-set("shared.png" 2x)); background:var(--image) }</style><dialog><img src="shared.png"><img src="only-hidden.png"></dialog>')
	defer { document.finalize() }
	base := document.base_url().serialize()
	foreground, background := partition_nonrendered_image_preloads(document, base, document_preload_resource_urls(document, base))
	assert foreground == ['https://preload-plan.test/dir/shared.png']
	assert background == ['https://preload-plan.test/dir/only-hidden.png']
}
