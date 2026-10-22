module main

import css
import dom
import html

// Start all image requests, but only wait before the first layout for images
// that can participate in it. This changes neither HTML lazy-loading policy nor
// whether hidden images are fetched. The caller must install external styles
// and set the viewport before asking for this plan.
fn partition_nonrendered_image_preloads(document &dom.Document, base_url string, urls []string) ([]string, []string) {
	if document.as_node().is_scripting_enabled() || urls.len == 0 {
		return urls.clone(), []string{}
	}
	// A shadow tree can paint a URL also referenced by a hidden light-tree
	// image. Keep the ordinary preload barrier until all composed-tree resource
	// consumers can be classified. Internal control roots do not add authors'
	// image consumers and must not disable the optimization on ordinary forms.
	if document.shadow_roots.any(!it.is_user_agent_internal()) {
		return urls.clone(), []string{}
	}
	types := document_preload_resource_types(document, base_url)
	root := document.as_node()
	mut hidden_by_url := map[string]bool{}
	mut hidden_by_element := map[u64]bool{}
	for image in css.query_selector_all(root, 'img[src]') {
		if !image.is_html_element() { continue }
		resource_url := resolve_document_reference(image.get_attribute_value('src'), base_url)
		if resource_url !in urls || (types[resource_url] or { 'image' }) != 'image' {
			continue
		}
		hidden := preload_element_has_no_display_box(image, mut hidden_by_element)
		if previous := hidden_by_url[resource_url] {
			hidden_by_url[resource_url] = previous && hidden
		} else {
			hidden_by_url[resource_url] = hidden
		}
	}
	// A URL shared with a different resource role is conservatively foreground.
	// In particular, SVG image resources can contribute through a paint server
	// even when their own DOM ancestors do not create ordinary CSS boxes.
	mut current := root.first_child()
	for {
		node := current or { break }
		if node.is_element() {
			element := unsafe { &dom.Element(node) }
			if element.is_html_element() && element.local_name() in ['img', 'source'] {
				if source_set := element.get_attribute('srcset') {
					for source in html.parse_a_srcset_attribute(source_set).sources {
						resource_url := resolve_document_reference(source.url, base_url)
						if resource_url in hidden_by_url { hidden_by_url[resource_url] = false }
					}
				}
			}
			if !(element.is_html_element() && element.local_name() == 'img') {
				for attribute in ['src', 'href', 'xlink:href', 'poster', 'data']! {
					if reference := element.get_attribute(attribute) {
						hidden_by_url[resolve_document_reference(reference, base_url)] = false
					}
				}
			}
		}
		current = node.next_in_pre_order(root)
	}
	if hidden_by_url.values().any(it) {
		// A background, marker, generated-content image, or image-set can use
		// the same bytes as a hidden <img>. Such a URL must still be ready for
		// the first frame. Tokenization retains quoted and escaped CSS URLs.
		mut seen_sheets := map[u64]bool{}
		scope := css.style_scope_for_dom_node(root)
		for origin in [css.CascadeOrigin.author, .user, .user_agent] {
			for sheet in scope.stylesheets_for_cascade_origin(origin) {
				preload_preserve_sheet_resource_urls(sheet, base_url, mut hidden_by_url, mut seen_sheets)
			}
		}
		for element in css.query_selector_all(root, '[style]') {
			if inline_style := element.get_attribute('style') {
				preload_preserve_css_resource_urls(inline_style, base_url, mut hidden_by_url)
			}
		}
	}
	mut foreground := []string{cap: urls.len}
	mut background := []string{}
	for resource_url in urls {
		if hidden_by_url[resource_url] or { false } {
			background << resource_url
		} else {
			foreground << resource_url
		}
	}
	return foreground, background
}

fn preload_preserve_sheet_resource_urls(sheet &css.CSSStyleSheet, fallback_base string,
	mut hidden_by_url map[string]bool, mut seen map[u64]bool) {
	key := u64(voidptr(sheet))
	if key in seen { return }
	seen[key] = true
	base_url := sheet.base_url or { sheet.href() or { fallback_base } }
	preload_preserve_rule_resource_urls(sheet.css_rules(), base_url, mut hidden_by_url, mut seen)
}

fn preload_preserve_rule_resource_urls(rules &css.CSSRuleList, base_url string,
	mut hidden_by_url map[string]bool, mut seen map[u64]bool) {
	for rule in rules.rules {
		if imported := rule.loaded_style_sheet_for_bindings() {
			preload_preserve_sheet_resource_urls(imported, base_url, mut hidden_by_url, mut seen)
		}
		// CSSRule.style() is a CSSOM accessor that materializes deferred
		// declarations. Resource discovery only needs the retained URL tokens.
		if declaration := rule.declaration {
			for candidate in declaration.resource_url_candidates(base_url) {
				resource_url := resolve_document_reference(candidate.url, candidate.base_url)
				if resource_url in hidden_by_url { hidden_by_url[resource_url] = false }
			}
		} else if rule.css_rules() == none {
			preload_preserve_css_resource_urls(rule.css_text(), base_url, mut hidden_by_url)
		}
		if nested := rule.css_rules() {
			preload_preserve_rule_resource_urls(nested, base_url, mut hidden_by_url, mut seen)
		}
	}
}

fn preload_element_has_no_display_box(element &dom.Element, mut cache map[u64]bool) bool {
	key := u64(voidptr(element))
	if cached := cache[key] { return cached }
	// Resolve ancestors first. Descendants of display:none need no computed
	// style, and asking for one could repeatedly restyle that unboxed subtree.
	mut hidden := false
	if parent := element.as_node().parent_element() {
		hidden = preload_element_has_no_display_box(parent, mut cache)
	}
	if !hidden {
		hidden = css.up_to_date_computed_properties_for_element(element).display().is_none()
	}
	cache[key] = hidden
	return hidden
}

// A hidden image may become visible through native interaction or a media
// query while its request is in flight. Rebuild its intrinsic geometry when
// the response arrives, without rebuilding for images that remain unboxed.
fn completed_nonrendered_images_need_layout(document &dom.Document, completed map[string]bool) bool {
	mut hidden_by_element := map[u64]bool{}
	base_url := document.base_url().serialize()
	for image in css.query_selector_all(document.as_node(), 'img[src]') {
		if !image.is_html_element() { continue }
		resource_url := resolve_document_reference(image.get_attribute_value('src'), base_url)
		if resource_url in completed && !preload_element_has_no_display_box(image, mut hidden_by_element) {
			return true
		}
	}
	return false
}

fn preload_preserve_css_resource_urls(source string, base_url string, mut hidden_by_url map[string]bool) {
	for token in css.tokenize_css(source, 'utf-8') {
		// Quoted strings also cover image-set("image.png" 1x). Treating an
		// unrelated CSS string as a possible URL only keeps more work foreground.
		if token.is(.url) || token.is(.string) {
			resource_url := resolve_document_reference(token.value, base_url)
			if resource_url in hidden_by_url { hidden_by_url[resource_url] = false }
		}
	}
}
