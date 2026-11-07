module main

import css
import dom
import html
import os

fn assert_cookie_blocker_hidden(element &dom.Element) {
	assert element.has_attribute('data-vox-cookie-blocked')
	assert element.get_attribute_value('aria-hidden') == 'true'
	style := css.inline_style(element)
	assert style.get_property_value('display') == 'none'
	assert style.get_property_priority('display') == 'important'
}

fn test_cookie_banner_policy_can_preserve_original_site_ui_for_conformance() {
	previous := os.getenv_opt('VOX_BLOCK_COOKIE_BANNERS')
	defer {
		if value := previous {
			os.setenv('VOX_BLOCK_COOKIE_BANNERS', value, true)
		} else {
			os.unsetenv('VOX_BLOCK_COOKIE_BANNERS')
		}
	}
	mut document := html.parse_document('<!doctype html><div id="cookie-banner" style="position:fixed">We use cookies. <button>Accept</button></div>')
	defer { document.finalize() }
	os.setenv('VOX_BLOCK_COOKIE_BANNERS', '0', true)
	version := document.dom_tree_version()
	assert apply_cookie_banner_policy(document) == 0
	assert document.dom_tree_version() == version
	banner := document.get_element_by_id('cookie-banner') or { panic('missing banner') }
	assert !banner.has_attribute('data-vox-cookie-blocked')
	assert banner.get_attribute_value('style') == 'position:fixed'
	os.setenv('VOX_BLOCK_COOKIE_BANNERS', '1', true)
	assert apply_cookie_banner_policy(document) == 1
	assert_cookie_blocker_hidden(banner)
}

fn test_cookie_blocker_is_enabled_by_default() {
	previous := os.getenv_opt('VOX_BLOCK_COOKIE_BANNERS')
	defer {
		if value := previous {
			os.setenv('VOX_BLOCK_COOKIE_BANNERS', value, true)
		} else {
			os.unsetenv('VOX_BLOCK_COOKIE_BANNERS')
		}
	}
	os.unsetenv('VOX_BLOCK_COOKIE_BANNERS')
	mut document := html.parse_document('<div id="cookie-banner">We use cookies. <button>Reject all</button></div>')
	defer { document.finalize() }
	assert cookie_blocker_enabled_by_default
	assert apply_cookie_banner_policy(document) == 1
}

fn test_cookie_blocker_hides_reddit_eu_cookie_policy_banner() {
	mut document := html.parse_document('<!doctype html><body>
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
	defer { document.finalize() }

	assert hide_cookie_banners(document) == 1
	banner := document.get_element_by_id('eu-cookie-policy') or { panic('missing test banner') }
	assert_cookie_blocker_hidden(banner)
	inner_element := document.get_element_by_id('cookie-infobar-inner') or {
		panic('missing inner banner')
	}
	assert inner_element.get_attribute_value('style') == 'position: fixed'
	assert !inner_element.has_attribute('data-vox-cookie-blocked')
	content := document.get_element_by_id('content') or { panic('missing page content') }
	assert !content.has_attribute('data-vox-cookie-blocked')
	version := document.dom_tree_version()
	assert hide_cookie_banners(document) == 0
	assert document.dom_tree_version() == version
	assert inner_element.get_attribute_value('style') == 'position: fixed'
}

fn test_cookie_blocker_does_not_hide_cookie_policy_content() {
	mut document := html.parse_document('<!doctype html><body>
		<article id="policy-article">
			<h1>Cookie policy</h1>
			<p>This article explains which cookies the site uses.</p>
		</article>
		<section id="cookie-policy">
			<h2>Cookie policy</h2>
			<p>You may allow or reject cookies in your browser settings.</p>
			<a href="/preferences">Manage cookie preferences</a>
		</section>
		<div id="policy-copy" class="cookie-policy">
			<p>Consent to cookies can be changed in account settings.</p>
			<a href="/consent">Cookie consent policy</a>
		</div>
		<form id="cookie-policy-settings">
			<label><input type="checkbox" name="analytics">Allow analytics cookies</label>
			<button>Save settings</button>
		</form>
	</body>')
	defer { document.finalize() }

	version := document.dom_tree_version()
	assert hide_cookie_banners(document) == 0
	assert document.dom_tree_version() == version
	for id in ['policy-article', 'cookie-policy', 'policy-copy', 'cookie-policy-settings'] {
		element := document.get_element_by_id(id) or { panic('missing policy content') }
		assert !element.has_attribute('data-vox-cookie-blocked')
		assert !element.has_attribute('style')
	}
}

fn test_cookie_blocker_requires_consent_controls_for_heuristic_matches() {
	mut document := html.parse_document('<section id="cookie-notice">
		<p>We explain how to accept cookies or change your settings.</p>
		<input type="text" value="Accept cookies">
		<button>Read the guide</button>
		<a href="/settings">Cookie settings</a>
		<a href="/policy">Cookie consent policy</a>
	</section>')
	defer { document.finalize() }

	assert hide_cookie_banners(document) == 0
	content := document.get_element_by_id('cookie-notice') or { panic('missing notice') }
	assert !content.has_attribute('data-vox-cookie-blocked')
}

fn test_cookie_blocker_hides_localized_vendor_roots() {
	mut document := html.parse_document('<!doctype html><body>
		<div id="onetrust-consent-sdk">
			<div id="onetrust-banner-sdk">Votre vie privée <button>Tout refuser</button></div>
		</div>
		<div id="CybotCookiebotDialog">Ваши настройки конфиденциальности <button>Отклонить</button></div>
		<div id="didomi-host">Tu privacidad <button>Rechazar todo</button></div>
		<main id="content">Page content</main>
	</body>')
	defer { document.finalize() }

	assert hide_cookie_banners(document) == 3
	for id in ['onetrust-consent-sdk', 'CybotCookiebotDialog', 'didomi-host'] {
		banner := document.get_element_by_id(id) or { panic('missing vendor banner') }
		assert_cookie_blocker_hidden(banner)
	}
	inner_banner := document.get_element_by_id('onetrust-banner-sdk') or {
		panic('missing nested vendor banner')
	}
	assert !inner_banner.has_attribute('data-vox-cookie-blocked')
	assert !inner_banner.has_attribute('style')
	content := document.get_element_by_id('content') or { panic('missing page content') }
	assert !content.has_attribute('data-vox-cookie-blocked')
}

fn test_cookie_blocker_matches_complete_vendor_class_tokens() {
	mut document := html.parse_document('<section id="localized" class="site-overlay cc-window cc-banner">
		Datenschutz <button>Ablehnen</button>
	</section>
	<div id="preview" class="cc-window-preview">Documentation preview</div>
	<div id="article" class="didomi-article">An article about cookies and consent settings.</div>')
	defer { document.finalize() }

	assert hide_cookie_banners(document) == 1
	banner := document.get_element_by_id('localized') or { panic('missing localized banner') }
	assert_cookie_blocker_hidden(banner)
	for id in ['preview', 'article'] {
		element := document.get_element_by_id(id) or { panic('missing ordinary content') }
		assert !element.has_attribute('data-vox-cookie-blocked')
	}
}

fn test_cookie_blocker_hides_semantic_cookie_dialogs() {
	mut document := html.parse_document('<div id="privacy-choice" role="dialog" aria-modal="true">
		We use cookies. <button>Reject all</button>
	</div>
	<div id="privacy-alert" role="alertdialog">We use cookies. <button>Accept all</button></div>
	<dialog id="native-dialog" open>We use cookies. <button>Manage preferences</button></dialog>
	<div id="login" role="dialog">Sign in to continue. <button>Continue</button></div>
	<div id="cookie-login" role="dialog">Enable cookies to sign in.
		<button>Continue</button><button>Close</button>
	</div>')
	defer { document.finalize() }

	assert hide_cookie_banners(document) == 3
	for id in ['privacy-choice', 'privacy-alert', 'native-dialog'] {
		banner := document.get_element_by_id(id) or { panic('missing consent dialog') }
		assert_cookie_blocker_hidden(banner)
	}
	for id in ['login', 'cookie-login'] {
		login := document.get_element_by_id(id) or { panic('missing login dialog') }
		assert !login.has_attribute('data-vox-cookie-blocked')
		assert !login.has_attribute('style')
	}
}

fn test_cookie_blocker_uses_accessible_and_input_control_labels() {
	mut document := html.parse_document('<aside id="cookie-banner">We use cookies.
		<button aria-label="Reject all cookies"><span aria-hidden="true">X</span></button>
	</aside>
	<footer id="cookie-warning">We use cookies. <input type="submit" value="Accept all"></footer>
	<header id="cookie-notice">We use cookies. <span role="button" aria-label="Decline"></span></header>
	<cookie-consent-banner id="custom-banner">We use cookies. <a href="#">Reject all</a></cookie-consent-banner>
	<div id="label-only" aria-label="Cookie consent">We use cookies. <button>Continue</button></div>')
	defer { document.finalize() }

	assert hide_cookie_banners(document) == 5
	for id in ['cookie-banner', 'cookie-warning', 'cookie-notice', 'custom-banner', 'label-only'] {
		banner := document.get_element_by_id(id) or { panic('missing warning') }
		assert_cookie_blocker_hidden(banner)
	}
}

fn test_cookie_blocker_preserves_existing_inline_style() {
	mut document := html.parse_document('<div id="cookie-consent" style="position: fixed; bottom: 0; display: flex !important; --message: \'keep; this\'">
		This site uses cookies. <button>Accept</button>
	</div>')
	defer { document.finalize() }

	banner := document.get_element_by_id('cookie-consent') or { panic('missing test banner') }
	style := css.inline_style(banner)
	position := style.get_property_value('position')
	bottom := style.get_property_value('bottom')
	message := style.get_property_value('--message')
	assert hide_cookie_banners(document) == 1
	assert_cookie_blocker_hidden(banner)
	assert style.get_property_value('position') == position
	assert style.get_property_value('bottom') == bottom
	assert style.get_property_value('--message') == message
	assert message != ''
}

fn test_cookie_blocker_repairs_script_changes_without_repeated_mutations() {
	mut document := html.parse_document('<div id="cookie-banner">We use cookies. <button>Accept</button></div>')
	defer { document.finalize() }

	assert hide_cookie_banners(document) == 1
	mut banner := document.get_element_by_id('cookie-banner') or { panic('missing banner') }
	assert_cookie_blocker_hidden(banner)
	initial_style := banner.get_attribute_value('style')
	initial_version := document.dom_tree_version()
	assert hide_cookie_banners(document) == 0
	assert banner.get_attribute_value('style') == initial_style
	assert document.dom_tree_version() == initial_version

	// Consent scripts commonly replace the complete style attribute after load.
	banner.set_attribute_value('style', 'position: fixed; display: flex !important')
	banner.set_attribute_value('aria-hidden', 'false')
	assert hide_cookie_banners(document) == 1
	assert_cookie_blocker_hidden(banner)
	assert css.inline_style(banner).get_property_value('position') == 'fixed'
	updated_style := banner.get_attribute_value('style')
	updated_version := document.dom_tree_version()
	assert hide_cookie_banners(document) == 0
	assert banner.get_attribute_value('style') == updated_style
	assert document.dom_tree_version() == updated_version

	// Accessibility-only changes also need repair without adding another rule.
	banner.remove_attribute('aria-hidden')
	assert hide_cookie_banners(document) == 1
	assert_cookie_blocker_hidden(banner)
	assert banner.get_attribute_value('style') == updated_style
}

fn test_cookie_blocker_hides_banners_inserted_after_the_first_pass() {
	mut document := html.parse_document('<main id="content">Page content</main>')
	defer { document.finalize() }
	assert hide_cookie_banners(document) == 0

	mut banner := document.create_element('div')!
	banner.set_attribute_value('id', 'cookie-banner')
	mut banner_node := unsafe { &dom.Node(banner) }
	banner_node.append_child(document.create_text_node('We use cookies. ').as_node())!
	button := document.create_element('button')!
	mut button_node := unsafe { &dom.Node(button) }
	button_node.append_child(document.create_text_node('Reject all').as_node())!
	banner_node.append_child(button_node)!
	content := document.get_element_by_id('content') or { panic('missing content') }
	mut content_node := unsafe { &dom.Node(content) }
	content_node.append_child(banner_node)!

	assert hide_cookie_banners(document) == 1
	assert_cookie_blocker_hidden(banner)
	assert !content.has_attribute('data-vox-cookie-blocked')
	assert document.get_element_by_id('cookie-banner') != none
	assert hide_cookie_banners(document) == 0
}

fn test_cookie_blocker_preserves_consent_controls_and_page_scroll_styles() {
	mut document := html.parse_document('<body id="page" style="overflow: hidden">
		<form id="cookie-consent" action="/save-consent">
			<p>We use cookies.</p>
			<input id="analytics" type="checkbox" name="analytics" value="yes">
			<input id="required" type="checkbox" name="required" checked>
			<button id="accept" name="choice" value="all" onclick="document.cookie=\'consent=all\'">Accept all</button>
			<button id="reject" name="choice" value="required">Reject all</button>
		</form>
		<div id="unrelated-overlay" style="position: fixed">Another dialog</div>
	</body>')
	defer { document.finalize() }

	assert hide_cookie_banners(document) == 1
	analytics := document.get_element_by_id('analytics') or { panic('missing analytics control') }
	assert !analytics.has_attribute('checked')
	assert analytics.get_attribute_value('value') == 'yes'
	required := document.get_element_by_id('required') or { panic('missing required control') }
	assert required.has_attribute('checked')
	accept := document.get_element_by_id('accept') or { panic('missing accept control') }
	assert accept.get_attribute_value('value') == 'all'
	assert accept.get_attribute_value('onclick') == "document.cookie='consent=all'"
	reject := document.get_element_by_id('reject') or { panic('missing reject control') }
	assert reject.get_attribute_value('value') == 'required'
	banner := document.get_element_by_id('cookie-consent') or { panic('missing consent form') }
	assert banner.get_attribute_value('action') == '/save-consent'
	page := document.get_element_by_id('page') or { panic('missing page body') }
	assert page.get_attribute_value('style') == 'overflow: hidden'
	overlay := document.get_element_by_id('unrelated-overlay') or { panic('missing unrelated overlay') }
	assert overlay.get_attribute_value('style') == 'position: fixed'
	assert !overlay.has_attribute('data-vox-cookie-blocked')
}
