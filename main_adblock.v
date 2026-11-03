module main

import adblock
import browserjs
import css
import dom
import os
import platform

const retain_empty_procedural_styles = os.getenv('VOX_RETAIN_EMPTY_PROCEDURAL_STYLES') != ''
const empty_procedural_style_diagnostics = os.getenv('VOX_EMPTY_PROCEDURAL_STYLE_DIAGNOSTICS') != ''

fn browser_adblock_tokens(document &dom.Document) []string {
	scratch := platform.begin_thread_scratch('adblock DOM token survey')
	mut tokens := map[string]bool{}
	mut class_values := map[string]bool{}
	collect_browser_adblock_tokens(document.as_node(), mut tokens, mut class_values)
	mut result := tokens.keys()
	result.sort()
	// The maps, split class names and sort buffer are query state. Keep only
	// independent strings: filter transport may outlive this survey workspace.
	scratch.leave()
	retained := []string{len: result.len, init: result[index].clone()}
	scratch.finish()
	return retained
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
	tokens := browser_adblock_tokens(document)
	filter_css := adblock.document_css(document.url.serialize(), tokens)!
	// An unchanged sheet is common during timestamp updates. Its composed
	// source is comparison storage; only an actual replacement must survive.
	work := platform.begin_thread_scratch('adblock stylesheet comparison')
	user_style := existing.all_before(marker).trim_right('\n')
	// The procedural adapter returns its marker even when it emitted no rules.
	// Keep that nonempty result for DOM mutation replay, but do not let the
	// comment alone replace the user sheet and invalidate its unchanged rules.
	procedural_rules := if !retain_empty_procedural_styles
		&& procedural_css == '/* vox procedural filters */\n' {
		if empty_procedural_style_diagnostics {
			eprintln('Vox procedural styles: omitted empty generated CSS payload')
		}
		''
	} else { procedural_css }
	source := if filter_css == '' && procedural_rules == '' { user_style }
		else { '${user_style}\n${marker}\n${filter_css}\n${procedural_rules}' }
	// A new ID/class token can leave the emitted rules unchanged. Compare the
	// actual stylesheet, so input bookkeeping cannot invalidate every style.
	if existing == source { work.finish(); return }
	work.leave()
	owned_source := source.clone()
	work.finish()
	css.set_document_user_style_sheet(document, owned_source)
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
	// Consent widgets can arrive in delayed callbacks or be shown again by
	// scripts. Apply the independent cookie policy after replay, before layout.
	apply_cookie_banner_policy(document)
	install_browser_adblock_styles(document, procedural_css) or { messages << 'Adblock styles: ${err.msg()}' }
}
