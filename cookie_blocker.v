module main

import dom
import os

// Cookie banners are blocked in ordinary sessions. The environment override
// below permits a consent state shared with a reference browser.
const cookie_blocker_enabled_by_default = true

// Conformance captures and launches can preserve a site's consent UI while
// retaining the browser's default policy for ordinary sessions.
fn apply_cookie_banner_policy(document &dom.Document) int {
	if os.getenv('VOX_BLOCK_COOKIE_BANNERS') == '0' { return 0 }
	return if cookie_blocker_enabled_by_default { hide_cookie_banners(document) } else { 0 }
}

const cookie_banner_container_tags = [
	'aside',
	'dialog',
	'div',
	'form',
	'section',
]

const cookie_banner_identity_fragments = [
	'cookie-banner',
	'cookie_banner',
	'cookiebanner',
	'cookie-consent',
	'cookie_consent',
	'cookieconsent',
	'cookie-infobar',
	'cookie-notice',
	'cookie_notice',
	'cookienotice',
	'cookie-policy',
	'cookie_policy',
	'cookiepolicy',
	'cookie-popup',
	'cookie_popup',
	'cookie-modal',
	'cookie_modal',
	'cookie-wall',
	'cookie_wall',
	'cookie-law',
	'cookie_law',
	'consent-banner',
	'consent_banner',
	'consent-modal',
	'consent_modal',
	'consent-popup',
	'consent_popup',
	'gdpr-banner',
	'gdpr_banner',
	'gdpr-consent',
	'gdpr_consent',
	'privacy-banner',
	'privacy_banner',
]

const cookie_banner_vendor_fragments = [
	'cmpbox',
	'cookiebot',
	'didomi',
	'fc-consent-root',
	'onetrust-banner',
	'onetrust-consent',
	'qc-cmp',
]

const cookie_banner_action_fragments = [
	'accept',
	'agree',
	'allow',
	'consent',
	'continue',
	'decline',
	'got it',
	'manage cookies',
	'preferences',
	'reject',
	'save choices',
	'settings',
]

fn contains_any_fragment(value string, fragments []string) bool {
	for fragment in fragments {
		if value.contains(fragment) {
			return true
		}
	}
	return false
}

fn cookie_banner_identity(element &dom.Element) string {
	return '${element.get_attribute_value('id')} ${element.get_attribute_value('class')} ${element.get_attribute_value('aria-label')} ${element.get_attribute_value('data-testid')}'.to_lower()
}

fn has_cookie_banner_identity(identity string) bool {
	if contains_any_fragment(identity, cookie_banner_identity_fragments)
		|| contains_any_fragment(identity, cookie_banner_vendor_fragments) {
		return true
	}
	// Sites frequently choose names such as "cookie-toast" without using one
	// of the conventional spellings above.
	if identity.contains('cookie')
		&& contains_any_fragment(identity, ['banner', 'bar', 'consent', 'dialog', 'modal', 'notice',
			'policy', 'popup', 'toast', 'wall']) {
		return true
	}
	return (identity.contains('consent') || identity.contains('gdpr'))
		&& contains_any_fragment(identity, ['banner', 'box', 'container', 'dialog', 'modal', 'popup',
			'root', 'toast'])
}

fn is_cookie_banner(element &dom.Element) bool {
	if element.local_name() !in cookie_banner_container_tags {
		return false
	}
	identity := cookie_banner_identity(element)
	if !has_cookie_banner_identity(identity) {
		return false
	}
	text := element.as_node().descendant_text_content().to_lower()
	return text.contains('cookie') && contains_any_fragment(text, cookie_banner_action_fragments)
}

fn has_cookie_banner_ancestor(node &dom.Node) bool {
	mut ancestor := node.parent()
	for ancestor != none {
		current := ancestor or { break }
		if element := current.as_element() {
			if is_cookie_banner(element) {
				return true
			}
		}
		ancestor = current.parent()
	}
	return false
}

fn cookie_blocker_hidden_style(existing string) string {
	trimmed := existing.trim_space()
	if trimmed == '' {
		return 'display: none !important;'
	}
	separator := if trimmed.ends_with(';') { ' ' } else { '; ' }
	return '${trimmed}${separator}display: none !important;'
}

// hide_cookie_banners marks the outermost matching banner elements before
// layout. Inline !important wins over the page's own author rules while leaving
// the DOM in place for scripts that expect their consent widget to exist.
fn hide_cookie_banners(document &dom.Document) int {
	mut banners := []&dom.Element{}
	banners_ptr := &banners
	document_node := unsafe { &dom.Node(document) }
	document_node.visit_subtree(fn [banners_ptr] (node &dom.Node) dom.TraversalDecision {
		element := node.as_element() or { return .@continue }
		if !element.has_attribute('data-vox-cookie-blocked') && is_cookie_banner(element)
			&& !has_cookie_banner_ancestor(node) {
			unsafe {
				mut matches := *banners_ptr
				matches << element
				*banners_ptr = matches
			}
			return .skip_children_and_continue
		}
		return .@continue
	})
	for banner in banners {
		mut mutable_banner := unsafe { &dom.Element(banner) }
		mutable_banner.set_attribute_value('data-vox-cookie-blocked', '')
		mutable_banner.set_attribute_value('aria-hidden', 'true')
		mutable_banner.set_attribute_value('style', cookie_blocker_hidden_style(banner.get_attribute_value('style')))
	}
	return banners.len
}
