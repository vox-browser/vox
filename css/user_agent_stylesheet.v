module css

import platform
import os
import processmetrics
import runtime
import sync
import time

// The user-agent (default) stylesheet, embedded verbatim from Ladybird's CSS/Default.css.
const user_agent_stylesheet_source = platform.embedded_text($embed_file('ua_default.css'))
const user_agent_quirks_mode_stylesheet_source = platform.embedded_text($embed_file('ua_quirks_mode.css'))
const user_agent_mathml_stylesheet_source = platform.embedded_text($embed_file('ua_mathml_default.css'))
const user_agent_svg_stylesheet_source = platform.embedded_text($embed_file('ua_svg_default.css'))
const user_agent_counter_styles_marker = '/* https://w3c.github.io/predefined-counter-styles/ */'
const user_agent_cascade_stylesheet_source = user_agent_stylesheet_source.all_before(user_agent_counter_styles_marker)
const user_agent_counter_stylesheet_source = user_agent_stylesheet_source.all_after(user_agent_counter_styles_marker)

// The user-agent sheets are shared by every StyleScope in the process.
const user_agent_stylesheets = load_user_agent_stylesheets()
const user_agent_quirks_mode_stylesheet = user_agent_stylesheets.quirks
const user_agent_mathml_stylesheet = user_agent_stylesheets.mathml
const user_agent_svg_stylesheet = user_agent_stylesheets.svg
const sync_user_agent_syntax = os.getenv('VOX_SYNC_UA_STYLESHEET_SYNTAX') == '1'
const sync_user_agent_rule_cache = os.getenv('VOX_SYNC_UA_STYLESHEET_RULE_CACHE') == '1'
const sync_user_agent_selectors = os.getenv('VOX_SYNC_UA_STYLESHEET_SELECTORS') == '1'
const early_user_agent_stylesheet_join = os.getenv('VOX_EARLY_UA_STYLESHEET_JOIN') == '1'
const user_agent_syntax_diagnostics = os.getenv('VOX_UA_STYLESHEET_DIAGNOSTICS') == '1'
const deferred_user_agent_startup = use_deferred_user_agent_startup()

__global (
	user_agent_startup_mutex = sync.new_mutex()
	user_agent_startup_work &UserAgentSyntaxPreparation
	deferred_user_agent_default &CSSStyleSheet
)

struct UserAgentStyleSheets {
	quirks &CSSStyleSheet
	mathml &CSSStyleSheet
	svg &CSSStyleSheet
mut:
	default_sheet &CSSStyleSheet = unsafe { nil }
}

struct UserAgentSyntaxPreparation {
	ready chan PreparedUserAgentSyntax
	consumed chan bool
	worker thread
}

struct PreparedUserAgentSyntax {
	rules []Rule
	cache_payload StylesheetRulePayload
	selectors &PreparedStyleRuleSelectors = unsafe { nil }
	thread_id u64
	ready_ns u64
mut:
	cache_storage platform.DetachedThreadScratch
	selector_storage platform.DetachedThreadScratch
}

struct PreparedStyleRuleSelectors {
mut:
	lists map[voidptr]SelectorList
}

fn prepare_user_agent_selector_lists(rules []Rule) (&PreparedStyleRuleSelectors, platform.DetachedThreadScratch) {
	scratch := platform.begin_thread_scratch('user agent stylesheet selectors')
	mut prepared := &PreparedStyleRuleSelectors{}
	mut parser := RuleSelectorParser{is_ua_style_sheet: .yes}
	for rule in rules {
		parser.prepare_user_agent_selector_list(rule, mut prepared)
	}
	return prepared, scratch.detach()
}

fn (mut parser RuleSelectorParser) prepare_user_agent_selector_list(rule Rule, mut prepared PreparedStyleRuleSelectors) {
	match rule {
		QualifiedRule {
			// The owner uses this exact raw prelude when converting the rule.
			// Invalid lists stay on the normal path to report the same error.
			mut stream := ParserTokenStream.from_values(rule.prelude)
			if selectors := parser.parse_a_selector_list(mut stream, .standalone, .standard) {
				prepared.lists[rule.prelude.data] = selectors
			}
		}
		AtRule {
			// A top-level media rule preserves the standalone selector mode.
			if !rule.is_block_rule || !equals_ignoring_ascii_case(rule.name, 'media') { return }
			for child in rule.child_rules_and_lists_of_declarations {
				if child is RuleNode { parser.prepare_user_agent_selector_list(child.rule, mut prepared) }
			}
		}
	}
}

fn user_agent_selector_worker_available() bool {
	// These opt-in selector traces write main-thread diagnostic state.
	return !sync_user_agent_selectors && !rule_selector_reuse_diagnostics
		&& !borrowed_selector_span_diagnostics
}

fn prepare_user_agent_syntax(source string, max_cache_nodes int, prepare_selectors bool, ready chan PreparedUserAgentSyntax, consumed chan bool) {
	scratch := platform.begin_thread_scratch('user agent stylesheet worker')
	defer { scratch.finish() }
	// Parse raw grammar and prepare an independent cache copy. The caller owns
	// cache publication, CSSOM construction and document-dependent parsing.
	mut parser := RuleSelectorParser{
		token_stream: ParserTokenStream.from_transient_source(source, 'utf-8')
		is_ua_style_sheet: .yes
	}
	rules := parser.parse_a_stylesheet(none).rules
	payload, storage := if max_cache_nodes > 0 {
		prepare_stylesheet_rule_payload(source, rules, max_cache_nodes)
	} else {
		StylesheetRulePayload{}, platform.DetachedThreadScratch{}
	}
	selectors, selector_storage := if prepare_selectors {
		prepare_user_agent_selector_lists(rules)
	} else {
		empty := unsafe { &PreparedStyleRuleSelectors(nil) }
		empty, platform.DetachedThreadScratch{}
	}
	ready <- PreparedUserAgentSyntax{
		rules: rules
		cache_payload: payload
		cache_storage: storage
		selectors: selectors
		selector_storage: selector_storage
		thread_id: if user_agent_syntax_diagnostics { platform.native_thread_identity() } else { u64(0) }
		ready_ns: if user_agent_syntax_diagnostics { time.sys_mono_now() } else { u64(0) }
	}
	// Keep the scratch arena alive until the owner has copied all retained spans.
	_ = <-consumed
}

fn user_agent_syntax_worker_available() bool {
	$if macos && prealloc && !vox_css_diagnostics ? {
		return !sync_user_agent_syntax && !bulk_css_input_probe_diagnostics && runtime.nr_cpus() >= 2
	}
	return false
}

fn use_deferred_user_agent_startup() bool {
	$if vox_production ? {
		return !early_user_agent_stylesheet_join && user_agent_syntax_worker_available()
	}
	return false
}

fn load_companion_user_agent_stylesheets() UserAgentStyleSheets {
	return UserAgentStyleSheets{
		quirks: parse_shared_user_agent_stylesheet(user_agent_quirks_mode_stylesheet_source)
		mathml: parse_shared_user_agent_stylesheet(user_agent_mathml_stylesheet_source)
		svg: parse_shared_user_agent_stylesheet(user_agent_svg_stylesheet_source)
	}
}

fn load_user_agent_stylesheets() UserAgentStyleSheets {
	stage := processmetrics.begin_instruction_stage('user_agent_stylesheets')
	defer { stage.finish() }
	if deferred_user_agent_startup {
		return load_companion_user_agent_stylesheets()
	}
	if user_agent_syntax_worker_available() {
		return load_user_agent_stylesheets_with_worker()
	}
	default_sheet := parse_shared_user_agent_stylesheet(user_agent_cascade_stylesheet_source)
	mut sheets := load_companion_user_agent_stylesheets()
	sheets.default_sheet = default_sheet
	return sheets
}

fn start_user_agent_syntax_preparation() &UserAgentSyntaxPreparation {
	// Establish the owner arena before the tokenizer enters worker scratch.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	ready := chan PreparedUserAgentSyntax{cap: 1}
	consumed := chan bool{}
	source := user_agent_cascade_stylesheet_source
	max_cache_nodes := if !sync_user_agent_rule_cache && !disable_stylesheet_rule_cache
		&& stylesheet_rule_cache_.eligible(source) {
		stylesheet_rule_cache_.max_nodes
	} else { 0 }
	worker := spawn prepare_user_agent_syntax(source, max_cache_nodes,
		user_agent_selector_worker_available(), ready, consumed)
	return &UserAgentSyntaxPreparation{ready: ready, consumed: consumed, worker: worker}
}

fn (preparation &UserAgentSyntaxPreparation) release() {
	preparation.consumed <- true
	preparation.worker.wait()
}

fn (preparation &UserAgentSyntaxPreparation) discard() {
	mut prepared := <-preparation.ready
	mut storage := prepared.cache_storage.adopt('stylesheet rule cache')
	if storage != unsafe { nil } { storage.release() }
	mut selector_storage := prepared.selector_storage.adopt('user agent stylesheet selectors')
	if selector_storage != unsafe { nil } { selector_storage.release() }
	preparation.release()
}

fn (preparation &UserAgentSyntaxPreparation) convert() &CSSStyleSheet {
	defer { preparation.release() }
	join_started := if user_agent_syntax_diagnostics { time.sys_mono_now() } else { u64(0) }
	mut prepared := <-preparation.ready
	if user_agent_syntax_diagnostics {
		off_thread := prepared.thread_id != platform.native_thread_identity()
		eprintln('VOX_UA_STYLESHEET_SYNTAX rules=${prepared.rules.len} off_thread=${off_thread} ready=${prepared.ready_ns <= join_started} worker_cache_nodes=${prepared.cache_payload.nodes}')
	}
	css_stage := processmetrics.begin_instruction_stage('css_parsing')
	defer { css_stage.finish() }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	source := user_agent_cascade_stylesheet_source
	deferred := os.getenv('VOX_EAGER_USER_AGENT_DECLARATIONS') == ''
	if stylesheet_parse_diagnostics {
		eprintln('VOX_CSS_PARSE location=- bytes=${source.len} deferred=${deferred} cached=false rule_context=0')
	}
	id := if !sync_user_agent_rule_cache {
		stylesheet_rule_cache_.store_prepared(prepared.cache_payload, mut prepared.cache_storage)
	} else if !disable_stylesheet_rule_cache {
		stylesheet_rule_cache_.store(source, prepared.rules)
	} else { u64(0) }
	mut default_sheet := convert_transient_stylesheet_rules(ParsingParams{is_ua_style_sheet: .yes},
		prepared.rules, none, none, deferred: deferred, syntax_id: id, prepared_selectors: prepared.selectors)
	default_sheet.user_agent_selector_storage_ = prepared.selector_storage.adopt('user agent stylesheet selectors')
	default_sheet.process_lifetime = true
	return default_sheet
}

fn load_user_agent_stylesheets_with_worker() UserAgentStyleSheets {
	preparation := start_user_agent_syntax_preparation()
	mut sheets := load_companion_user_agent_stylesheets()
	sheets.default_sheet = preparation.convert()
	return sheets
}

// Bracket the browser setup work before the first document needs UA styles.
// Other embedders can keep using the ordinary stylesheet accessors.
pub fn begin_user_agent_stylesheet_startup() {
	if !deferred_user_agent_startup || !platform.arena_thread_is_current() { return }
	user_agent_startup_mutex.lock()
	defer { user_agent_startup_mutex.unlock() }
	if deferred_user_agent_default == unsafe { nil } && user_agent_startup_work == unsafe { nil } {
		user_agent_startup_work = start_user_agent_syntax_preparation()
	}
}

pub fn finish_user_agent_stylesheet_startup() {
	if deferred_user_agent_startup {
		_ = default_user_agent_stylesheet()
	}
}

pub fn discard_user_agent_stylesheet_startup() {
	if !deferred_user_agent_startup || !platform.arena_thread_is_current() { return }
	user_agent_startup_mutex.lock()
	preparation := user_agent_startup_work
	user_agent_startup_work = unsafe { nil }
	user_agent_startup_mutex.unlock()
	if preparation != unsafe { nil } { preparation.discard() }
}

fn default_user_agent_stylesheet() &CSSStyleSheet {
	if user_agent_stylesheets.default_sheet != unsafe { nil } {
		return user_agent_stylesheets.default_sheet
	}
	owner := platform.arena_thread_is_current()
	user_agent_startup_mutex.lock()
	current := deferred_user_agent_default
	mut preparation := unsafe { &UserAgentSyntaxPreparation(nil) }
	if owner {
		preparation = user_agent_startup_work
		user_agent_startup_work = unsafe { nil }
	}
	user_agent_startup_mutex.unlock()
	if current != unsafe { nil } {
		if preparation != unsafe { nil } { preparation.discard() }
		return current
	}
	stage := processmetrics.begin_instruction_stage('user_agent_default_stylesheet')
	defer { stage.finish() }
	// Conversion can checkpoint and reenter the browser. Claim a worker's
	// input under the mutex, then let a reentrant caller parse synchronously.
	sheet := if preparation != unsafe { nil } {
		preparation.convert()
	} else {
		parse_shared_user_agent_stylesheet(user_agent_cascade_stylesheet_source)
	}
	user_agent_startup_mutex.lock()
	defer { user_agent_startup_mutex.unlock() }
	if deferred_user_agent_default == unsafe { nil } {
		if !owner {
			persistent := platform.enter_persistent()
			platform.retain_thread_allocations()
			platform.leave_persistent(persistent)
		}
		deferred_user_agent_default = sheet
	}
	return deferred_user_agent_default
}

__global user_agent_counter_stylesheet &CSSStyleSheet

// The predefined counter styles occupy most of Default.css, but do not
// participate in selector matching. Parse them only when a document actually
// needs a non-trivial list marker or generated counter.
fn user_agent_counter_style_sheet() &CSSStyleSheet {
	if user_agent_counter_stylesheet == unsafe { nil } {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		user_agent_counter_stylesheet = parse_shared_user_agent_stylesheet(user_agent_counter_stylesheet_source)
	}
	return user_agent_counter_stylesheet
}

// Predefined @counter-style rules are split out of the selector-bearing UA
// sheet so normal cascade startup stays cheap. Marker generation still needs
// that second sheet rather than the selector-only user_agent_rules() list.
pub fn user_agent_counter_style_rules() []&CSSRule {
	return user_agent_counter_style_sheet().css_rules().rules
}

// Compatibility callers need the same default-UA rules as StyleScope. Reuse
// the sheet's list instead of parsing the 90 KiB Default.css source a second
// time during every process startup.
pub fn user_agent_rules() []&CSSRule {
	return default_user_agent_stylesheet().css_rules().rules
}

// The shared parsed user-agent stylesheet for `url`, or none if that sheet isn't embedded.
pub fn user_agent_default_style_sheet(url string) ?&CSSStyleSheet {
	if url == 'CSS/Default.css' {
		return default_user_agent_stylesheet()
	}
	if url == 'CSS/QuirksMode.css' {
		return user_agent_quirks_mode_stylesheet
	}
	if url == 'MathML/Default.css' {
		return user_agent_mathml_stylesheet
	}
	if url == 'SVG/Default.css' {
		return user_agent_svg_stylesheet
	}
	return none
}

fn parse_shared_user_agent_stylesheet(source string) &CSSStyleSheet {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut sheet := parse_css_stylesheet_in_workspace(ParsingParams{is_ua_style_sheet: .yes},
		source, none, none, os.getenv('VOX_EAGER_USER_AGENT_DECLARATIONS') == '')
	sheet.process_lifetime = true
	return sheet
}
