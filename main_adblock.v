module main

import adblock
import browserjs
import css
import dom

fn browser_adblock_tokens(document &dom.Document) []string {
	mut tokens := map[string]bool{}
	mut class_values := map[string]bool{}
	collect_browser_adblock_tokens(document.as_node(), mut tokens, mut class_values)
	mut result := tokens.keys()
	result.sort()
	return result
}

// Survey the light DOM directly: a selector match would read these same two
// attributes before the survey reads them again. Repeated class strings only
// need tokenizing once within this snapshot; later surveys still see live edits.
fn collect_browser_adblock_tokens(node &dom.Node, mut tokens map[string]bool,
	mut class_values map[string]bool) {
	if element := node.as_element() {
		id := element.get_attribute_value('id')
		if id != '' { tokens['#${id}'] = true }
		classes := element.get_attribute_value('class')
		if classes != '' && classes !in class_values {
			class_values[classes] = true
			for name in classes.fields() {
				tokens['.${name}'] = true
			}
		}
	}
	for child in node.children {
		collect_browser_adblock_tokens(child, mut tokens, mut class_values)
	}
}

// uBO inserts cosmetic rules at the user cascade origin, so !important page
// rules cannot reveal an advert. Keep the user's page stylesheet alongside it.
fn install_browser_adblock_styles(document &dom.Document, procedural_css string) ! {
	scope := css.style_scope_for_dom_node(unsafe { &dom.Node(document) })
	existing := scope.user_style_source or {
		if document.has_page() { document.page().user_style() or { '' } } else { '' }
	}
	marker := '/* vox-adblock-start */'
	user_style := existing.all_before(marker).trim_right('\n')
	tokens := browser_adblock_tokens(document)
	filters := adblock.document_filters(document.url.serialize(), tokens)!
	source := if filters.css == '' && procedural_css == '' { user_style }
		else { '${user_style}\n${marker}\n${filters.css}\n${procedural_css}' }
	// A new ID/class token can leave the emitted rules unchanged. Compare the
	// actual stylesheet, so input bookkeeping cannot invalidate every style.
	if existing == source { return }
	css.set_document_user_style_sheet(document, source)
}

fn browser_adblock_requires_runtime(document &dom.Document) bool {
	filters := adblock.document_filters(document.url.serialize(), []string{}) or { return false }
	return filters.scriptlets != '' || filters.procedural.len > 0
}

fn install_browser_adblock_scriptlets(document &dom.Document, runtime &browserjs.Runtime, mut messages []string) {
	filters := adblock.document_filters(document.url.serialize(), []string{}) or {
		messages << 'Adblock: ${err.msg()}'
		return
	}
	if filters.scriptlets != '' {
		// uBO's shared safe-self helper captures Request.clone even for cookie
		// and storage scriptlets. The compact host has no Request constructor
		// yet; keep that optional capture from disabling unrelated scriptlets.
		source := filters.scriptlets.replace('.Request.prototype.clone', '.Request?.prototype?.clone')
		// The content-script `self` binding is the page's actual global object.
		runtime.evaluate_host('(function(self){\n${source}\n})(globalThis);') or {
			messages << 'Adblock scriptlets: ${err.msg()}'
		}
	}
	procedural := adblock.procedural_script(filters)
	if procedural != '' {
		runtime.evaluate_host(procedural) or { messages << 'Adblock procedural filters: ${err.msg()}' }
	}
}

fn refresh_browser_adblock(document &dom.Document, runtime &browserjs.Runtime, mut messages []string) {
	mut procedural_css := ''
	if runtime != unsafe { nil } && adblock.is_enabled() {
		// Upstream primes action styles before evaluating selectors. Publish them
		// before a :matches-css query can synchronously flush style and layout.
		primed_css := runtime.evaluate_host('typeof __voxAdblockProceduralCSS==="function"?__voxAdblockProceduralCSS():""') or {
			messages << 'Adblock procedural filters: ${err.msg()}'
			''
		}
		if primed_css != '' {
			install_browser_adblock_styles(document, primed_css) or { messages << 'Adblock styles: ${err.msg()}' }
		}
		procedural_css = runtime.evaluate_host('typeof __voxAdblockApplyProcedural==="function"?__voxAdblockApplyProcedural():""') or {
			messages << 'Adblock procedural filters: ${err.msg()}'
			''
		}
		// Procedural actions use the same live compact DOM mutation replay as
		// author scripts, including attribute edits and node removals.
		if procedural_css != '' {
			state := runtime.evaluate_host('__ladybirdFinalize()') or { '' }
			if state != '' {
				apply_javascript_runtime_state(document, state, runtime, mut messages)
			}
		}
	}
	install_browser_adblock_styles(document, procedural_css) or { messages << 'Adblock styles: ${err.msg()}' }
}
