module main

import html
import os

fn test_cookie_banner_policy_can_preserve_original_site_ui_for_conformance() {
	previous := os.getenv_opt('VOX_BLOCK_COOKIE_BANNERS')
	defer {
		if value := previous { os.setenv('VOX_BLOCK_COOKIE_BANNERS', value, true) } else { os.unsetenv('VOX_BLOCK_COOKIE_BANNERS') }
	}
	mut document := html.parse_document('<!doctype html><div id="cookie-banner" style="position:fixed">We use cookies. <button>Accept</button></div>')
	defer { document.finalize() }
	os.setenv('VOX_BLOCK_COOKIE_BANNERS', '0', true)
	assert apply_cookie_banner_policy(document) == 0
	banner := document.get_element_by_id('cookie-banner') or { panic('missing banner') }
	assert !banner.has_attribute('data-vox-cookie-blocked')
	assert banner.get_attribute_value('style') == 'position:fixed'
	os.setenv('VOX_BLOCK_COOKIE_BANNERS', '1', true)
	assert apply_cookie_banner_policy(document) == 1
}

fn test_cookie_blocker_is_enabled_by_default() {
	assert cookie_blocker_enabled_by_default
}

fn test_cookie_blocker_hides_reddit_eu_cookie_policy_banner() {
	document := html.parse_document('<!doctype html><body>
		<main id="content">News</main>
		<div class="infobar-toaster-container">
			<form id="eu-cookie-policy">
				<div id="cookie-infobar-inner" class="reddit-infobar cookie-infobar" style="position: fixed">
					<p>Reddit uses cookies and similar technologies to:</p>
					<button>Continue</button>
				</div>
			</form>
		</div>
	</body>')

	assert hide_cookie_banners(document) == 1
	banner := document.get_element_by_id('eu-cookie-policy') or { panic('missing test banner') }
	assert banner.has_attribute('data-vox-cookie-blocked')
	assert banner.get_attribute_value('aria-hidden') == 'true'
	assert banner.get_attribute_value('style') == 'display: none !important;'
	inner_element := document.get_element_by_id('cookie-infobar-inner') or {
		panic('missing inner banner')
	}
	assert inner_element.get_attribute_value('style') == 'position: fixed'
	content := document.get_element_by_id('content') or { panic('missing page content') }
	assert !content.has_attribute('data-vox-cookie-blocked')
	assert hide_cookie_banners(document) == 0
}

fn test_cookie_blocker_does_not_hide_cookie_policy_content() {
	document := html.parse_document('<!doctype html><body>
		<article id="cookie-policy">
			<h1>Cookie policy</h1>
			<p>This article explains which cookies the site uses.</p>
		</article>
	</body>')

	assert hide_cookie_banners(document) == 0
	article := document.get_element_by_id('cookie-policy') or { panic('missing policy article') }
	assert !article.has_attribute('data-vox-cookie-blocked')
}

fn test_cookie_blocker_preserves_existing_inline_style() {
	document := html.parse_document('<div id="cookie-consent" style="position: fixed; bottom: 0">
		This site uses cookies. <button>Accept</button>
	</div>')

	assert hide_cookie_banners(document) == 1
	banner := document.get_element_by_id('cookie-consent') or { panic('missing test banner') }
	assert banner.get_attribute_value('style') == 'position: fixed; bottom: 0; display: none !important;'
}
