module main

import adblock
import css
import dom
import html
import os

fn test_adblock_refresh_blocks_late_cookie_banners_without_adblock_or_runtime() {
	previous_policy := os.getenv_opt('VOX_BLOCK_COOKIE_BANNERS')
	previous_adblock := adblock.is_enabled()
	defer {
		adblock.set_enabled(previous_adblock)
		if value := previous_policy {
			os.setenv('VOX_BLOCK_COOKIE_BANNERS', value, true)
		} else {
			os.unsetenv('VOX_BLOCK_COOKIE_BANNERS')
		}
	}
	adblock.set_enabled(false)
	os.setenv('VOX_BLOCK_COOKIE_BANNERS', '1', true)
	mut document := html.parse_document_with_url('<!doctype html><body>
		<main id="content">News</main><div id="late-container"></div>
	</body>', dom.URL{ value: 'https://example.com/' })
	defer { document.finalize() }
	user_style := '#content { color: green !important; }'
	css.set_document_user_style_sheet(document, user_style)
	mut messages := []string{}
	refresh_browser_adblock(document, unsafe { nil }, mut messages)
	assert messages == []string{}
	mut container := document.get_element_by_id('late-container') or {
		panic('missing late container')
	}
	// A delayed consent callback inserts its widget after the initial pass.
	container.set_inner_html('<div id="cookie-banner">We use cookies. <button>Reject all</button></div>')!
	refresh_browser_adblock(document, unsafe { nil }, mut messages)
	assert messages == []string{}
	mut banner := document.get_element_by_id('cookie-banner') or { panic('missing late banner') }
	assert banner.has_attribute('data-vox-cookie-blocked')
	assert banner.get_attribute_value('aria-hidden') == 'true'
	assert css.inline_style(banner).get_property_value('display') == 'none'
	assert css.inline_style(banner).get_property_priority('display') == 'important'

	// Retain the block when the widget changes its identity and restores its
	// inline style, as consent scripts can do on subsequent callbacks.
	banner.set_attribute_value('id', 'renamed-widget')
	banner.set_attribute_value('style', 'position: fixed; display: flex !important')
	banner.set_attribute_value('aria-hidden', 'false')
	refresh_browser_adblock(document, unsafe { nil }, mut messages)
	assert messages == []string{}
	assert banner.get_attribute_value('aria-hidden') == 'true'
	style := css.inline_style(banner)
	assert style.get_property_value('display') == 'none'
	assert style.get_property_priority('display') == 'important'
	assert style.get_property_value('position') == 'fixed'
	version := document.dom_tree_version()
	refresh_browser_adblock(document, unsafe { nil }, mut messages)
	assert messages == []string{}
	assert document.dom_tree_version() == version
	assert !adblock.is_enabled()
	content := document.get_element_by_id('content') or { panic('missing page content') }
	assert !content.has_attribute('data-vox-cookie-blocked')
	scope := css.style_scope_for_dom_node(document.as_node())
	assert (scope.user_style_source or { '' }) == user_style
}

fn test_adblock_refresh_preserves_cookie_policy_opt_out() {
	previous_policy := os.getenv_opt('VOX_BLOCK_COOKIE_BANNERS')
	previous_adblock := adblock.is_enabled()
	defer {
		adblock.set_enabled(previous_adblock)
		if value := previous_policy {
			os.setenv('VOX_BLOCK_COOKIE_BANNERS', value, true)
		} else {
			os.unsetenv('VOX_BLOCK_COOKIE_BANNERS')
		}
	}
	adblock.set_enabled(false)
	os.setenv('VOX_BLOCK_COOKIE_BANNERS', '0', true)
	mut document := html.parse_document('<div id="cookie-banner" style="display: flex">
		We use cookies. <button>Accept all</button>
	</div>')
	defer { document.finalize() }
	version := document.dom_tree_version()
	mut messages := []string{}
	refresh_browser_adblock(document, unsafe { nil }, mut messages)
	assert messages == []string{}
	assert document.dom_tree_version() == version
	mut banner := document.get_element_by_id('cookie-banner') or { panic('missing banner') }
	assert !banner.has_attribute('data-vox-cookie-blocked')
	assert banner.get_attribute_value('style') == 'display: flex'
	os.setenv('VOX_BLOCK_COOKIE_BANNERS', '1', true)
	refresh_browser_adblock(document, unsafe { nil }, mut messages)
	assert messages == []string{}
	assert banner.has_attribute('data-vox-cookie-blocked')
	assert css.inline_style(banner).get_property_value('display') == 'none'

	// The override also prevents repairs of previously marked widgets.
	os.setenv('VOX_BLOCK_COOKIE_BANNERS', '0', true)
	banner.set_attribute_value('style', 'display: block')
	banner.set_attribute_value('aria-hidden', 'false')
	updated_version := document.dom_tree_version()
	refresh_browser_adblock(document, unsafe { nil }, mut messages)
	assert messages == []string{}
	assert document.dom_tree_version() == updated_version
	assert banner.get_attribute_value('style') == 'display: block'
	assert banner.get_attribute_value('aria-hidden') == 'false'
}
