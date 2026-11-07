module main

import css
import dom
import os
import platform

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
	'footer',
	'form',
	'header',
	'section',
]

const cookie_banner_identity_fragments = [
	'cookie-banner',
	'cookie_banner',
	'cookiebanner',
	'cookie-consent',
	'cookie_consent',
	'cookieconsent',
	'cookie-bar',
	'cookie_bar',
	'cookiebar',
	'cookie-infobar',
	'cookie-notice',
	'cookie_notice',
	'cookienotice',
	'cookie-warning',
	'cookie_warning',
	'cookiewarning',
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

// Match vendor roots exactly, including widgets whose text lives in a shadow
// tree or is translated. A brand name anywhere in a class or article is not
// sufficient evidence that the element is a consent widget.
const cookie_banner_vendor_ids = [
	'cmpbox',
	'cybotcookiebotdialog',
	'didomi-host',
	'didomi-notice',
	'didomi-popup',
	'fc-consent-root',
	'iubenda-cs-banner',
	'onetrust-banner-sdk',
	'onetrust-consent-sdk',
	'qc-cmp2-container',
	'qc-cmp-ui-container',
	'usercentrics-root',
]

const cookie_banner_vendor_classes = [
	'cc-window',
	'cmpbox',
	'iubenda-cs-container',
	'qc-cmp2-container',
	'qc-cmp-ui-container',
]

const cookie_banner_action_fragments = [
	'accept',
	'agree',
	'allow',
	'close',
	'consent',
	'continue',
	'decline',
	'dismiss',
	'got it',
	'manage cookies',
	'no thanks',
	'preferences',
	'reject',
	'save choices',
	'settings',
]

const cookie_banner_choice_fragments = [
	'accept',
	'agree',
	'allow',
	'consent',
	'decline',
	'manage cookies',
	'preferences',
	'reject',
	'save choices',
	'cookie settings',
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
	label := element.get_attribute_value('aria-label').fields().join('-')
	return '${element.local_name()} ${element.get_attribute_value('id')} ${element.get_attribute_value('class')} ${label} ${element.get_attribute_value('data-testid')}'.to_lower()
}

fn has_cookie_banner_identity(identity string) bool {
	if contains_any_fragment(identity, cookie_banner_identity_fragments) {
		return true
	}
	// Sites frequently choose names such as "cookie-toast" without using one
	// of the conventional spellings above. Keep both clues in the same token:
	// unrelated classes such as "cookies sidebar" are not a banner identity.
	for token in identity.fields() {
		if token.contains('cookie')
			&& contains_any_fragment(token, ['banner', 'consent', 'dialog', 'modal', 'notice',
				'popup', 'toast', 'wall', 'warning', 'notification', 'alert', 'infobar']) {
			return true
		}
		if (token.contains('consent') || token.contains('gdpr'))
			&& contains_any_fragment(token, ['banner', 'box', 'container', 'dialog', 'modal', 'popup',
				'root', 'toast']) {
			return true
		}
	}
	return false
}

fn is_cookie_banner_container(element &dom.Element) bool {
	return element.local_name() in cookie_banner_container_tags || element.local_name().contains('-')
}

fn is_cookie_banner_vendor_root(element &dom.Element) bool {
	if element.get_attribute_value('id').to_lower() in cookie_banner_vendor_ids {
		return true
	}
	for name in element.get_attribute_value('class').to_lower().fields() {
		if name in cookie_banner_vendor_classes {
			return true
		}
	}
	return false
}

fn is_cookie_banner_action(element &dom.Element, require_choice bool) bool {
	tag := element.local_name()
	role := element.get_attribute_value('role').to_lower()
	is_button := tag == 'button' || role == 'button'
		|| (tag == 'input' && element.get_attribute_value('type').to_lower() in [
			'button',
			'submit',
			'reset',
		])
	is_link := tag == 'a' && element.has_attribute('href')
	if !is_button && !is_link {
		return false
	}
	label := '${element.get_attribute_value('aria-label')} ${element.get_attribute_value('value')} ${element.as_node().descendant_text_content()}'.to_lower()
	// A generic dialog mentioning cookies can be a sign-in/error dialog with a
	// Continue or Close button. Without a banner identity, require a choice.
	if require_choice && !contains_any_fragment(label, cookie_banner_choice_fragments) {
		return false
	}
	if is_button {
		return contains_any_fragment(label, cookie_banner_action_fragments)
	}
	// A policy page can link to cookie settings without asking for consent.
	// Plain links need an explicit dismissal/choice; role=button links above
	// can also provide a preferences or settings action.
	return contains_any_fragment(label, ['accept', 'agree', 'allow', 'close', 'continue', 'decline',
		'dismiss', 'got it', 'no thanks', 'reject'])
}

fn has_cookie_banner_action(node &dom.Node, require_choice bool) bool {
	if element := node.as_element() {
		if is_cookie_banner_action(element, require_choice) {
			return true
		}
	}
	for child in node.children {
		if has_cookie_banner_action(child, require_choice) {
			return true
		}
	}
	return false
}

fn is_cookie_banner(element &dom.Element) bool {
	if !is_cookie_banner_container(element) {
		return false
	}
	if is_cookie_banner_vendor_root(element) {
		return true
	}
	identity := cookie_banner_identity(element)
	role := element.get_attribute_value('role').to_lower()
	is_dialog := element.local_name() == 'dialog' || role in ['dialog', 'alertdialog']
	// Reddit's outer consent form wraps a cookie-infobar. Generic cookie-policy
	// content remains visible unless it also identifies itself as a dialog.
	is_reddit_banner := element.get_attribute_value('id') == 'eu-cookie-policy'
	identified := has_cookie_banner_identity(identity) || is_reddit_banner
	if !identified && !is_dialog {
		return false
	}
	text := element.as_node().descendant_text_content().to_lower()
	return text.contains('cookie') && has_cookie_banner_action(element.as_node(), !identified)
}

// hide_cookie_banners marks the outermost matching banner elements before
// layout. Inline !important wins over the page's own author rules while leaving
// the DOM in place for scripts that expect their consent widget to exist.
// No buttons are clicked and no consent choice is persisted.
fn hide_cookie_banners(document &dom.Document) int {
	scratch := platform.begin_thread_scratch('cookie banner survey')
	mut banners := []&dom.Element{}
	banners_ptr := &banners
	document_node := unsafe { &dom.Node(document) }
	document_node.visit_subtree(fn [banners_ptr] (node &dom.Node) dom.TraversalDecision {
		element := node.as_element() or { return .@continue }
		if is_cookie_banner_container(element)
			&& (element.has_attribute('data-vox-cookie-blocked') || is_cookie_banner(element)) {
			unsafe {
				mut matches := *banners_ptr
				matches << element
				*banners_ptr = matches
			}
			return .skip_children_and_continue
		}
		return .@continue
	})
	// Matching creates temporary identities and text on every refresh. Release
	// them after the pass, but allocate retained CSS/attributes in the caller's
	// heap rather than in the survey workspace.
	scratch.leave()
	mut changed := 0
	for banner in banners {
		mut mutable_banner := unsafe { &dom.Element(banner) }
		mut needs_update := false
		if !banner.has_attribute('data-vox-cookie-blocked') {
			mutable_banner.set_attribute_value('data-vox-cookie-blocked', '')
			needs_update = true
		}
		if banner.get_attribute_value('aria-hidden') != 'true' {
			mutable_banner.set_attribute_value('aria-hidden', 'true')
			needs_update = true
		}
		// Scripts can replace a banner's style after the initial load. CSSOM
		// replaces display rather than appending duplicate declarations on each
		// refresh, and unchanged banners do not dirty style/layout again.
		style := css.inline_style(banner)
		if style.get_property_value('display') != 'none'
			|| style.get_property_priority('display') != 'important' {
			style.set_property_with_priority('display', 'none', 'important')
			needs_update = true
		}
		if needs_update {
			changed++
		}
	}
	scratch.finish()
	return changed
}
