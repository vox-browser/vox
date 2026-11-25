module css

import platform
import os
import processmetrics
import runtime
import time

// The user-agent (default) stylesheet, embedded verbatim from Ladybird's CSS/Default.css.
const user_agent_stylesheet_source = platform.embedded_text($embed_file('ua_default.css'))
const user_agent_quirks_mode_stylesheet_source = platform.embedded_text($embed_file('ua_quirks_mode.css'))
const user_agent_mathml_stylesheet_source = platform.embedded_text($embed_file('ua_mathml_default.css'))
const user_agent_svg_stylesheet_source = platform.embedded_text($embed_file('ua_svg_default.css'))
const user_agent_counter_styles_marker = '/* https://w3c.github.io/predefined-counter-styles/ */'
const user_agent_cascade_stylesheet_source = user_agent_stylesheet_source.all_before(user_agent_counter_styles_marker)
const user_agent_counter_stylesheet_source = user_agent_stylesheet_source.all_after(user_agent_counter_styles_marker)

// The parsed user-agent CSSStyleSheet, built once at startup and shared by every StyleScope's UA rule
// cache (the sheet is identical for all documents), so documents don't each re-parse Default.css.
const user_agent_stylesheets = load_user_agent_stylesheets()
const user_agent_default_stylesheet = user_agent_stylesheets.default_sheet
const user_agent_quirks_mode_stylesheet = user_agent_stylesheets.quirks
const user_agent_mathml_stylesheet = user_agent_stylesheets.mathml
const user_agent_svg_stylesheet = user_agent_stylesheets.svg
const sync_user_agent_syntax = os.getenv('VOX_SYNC_UA_STYLESHEET_SYNTAX') == '1'
const user_agent_syntax_diagnostics = os.getenv('VOX_UA_STYLESHEET_DIAGNOSTICS') == '1'

struct UserAgentStyleSheets {
	default_sheet &CSSStyleSheet
	quirks &CSSStyleSheet
	mathml &CSSStyleSheet
	svg &CSSStyleSheet
}

struct PreparedUserAgentSyntax {
	rules []Rule
	thread_id u64
	ready_ns u64
}

fn prepare_user_agent_syntax(source string, ready chan PreparedUserAgentSyntax, consumed chan bool) {
	scratch := platform.begin_thread_scratch('user agent stylesheet worker')
	defer { scratch.finish() }
	// Tokenize and parse raw grammar only. The caller owns the shared caches,
	// CSSOM construction and any document-dependent value parsing.
	mut parser := RuleSelectorParser{
		token_stream: ParserTokenStream.from_transient_source(source, 'utf-8')
		is_ua_style_sheet: .yes
	}
	rules := parser.parse_a_stylesheet(none).rules
	ready <- PreparedUserAgentSyntax{
		rules: rules
		thread_id: if user_agent_syntax_diagnostics { platform.native_thread_identity() } else { u64(0) }
		ready_ns: if user_agent_syntax_diagnostics { time.sys_mono_now() } else { u64(0) }
	}
	// Keep the scratch arena alive until the owner has copied all retained spans.
	_ = <-consumed
}

fn load_user_agent_stylesheets() UserAgentStyleSheets {
	stage := processmetrics.begin_instruction_stage('user_agent_stylesheets')
	defer { stage.finish() }
	$if macos && prealloc && !vox_css_diagnostics ? {
		if !sync_user_agent_syntax && !bulk_css_input_probe_diagnostics && runtime.nr_cpus() >= 2 {
			return load_user_agent_stylesheets_with_worker()
		}
	}
	return UserAgentStyleSheets{
		default_sheet: parse_shared_user_agent_stylesheet(user_agent_cascade_stylesheet_source)
		quirks: parse_shared_user_agent_stylesheet(user_agent_quirks_mode_stylesheet_source)
		mathml: parse_shared_user_agent_stylesheet(user_agent_mathml_stylesheet_source)
		svg: parse_shared_user_agent_stylesheet(user_agent_svg_stylesheet_source)
	}
}

fn load_user_agent_stylesheets_with_worker() UserAgentStyleSheets {
	// Establish the owner arena before the tokenizer enters worker scratch.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	source := user_agent_cascade_stylesheet_source
	ready := chan PreparedUserAgentSyntax{cap: 1}
	consumed := chan bool{}
	worker := spawn prepare_user_agent_syntax(source, ready, consumed)
	defer {
		consumed <- true
		worker.wait()
	}
	quirks := parse_shared_user_agent_stylesheet(user_agent_quirks_mode_stylesheet_source)
	mathml := parse_shared_user_agent_stylesheet(user_agent_mathml_stylesheet_source)
	svg := parse_shared_user_agent_stylesheet(user_agent_svg_stylesheet_source)
	companion_ready := if user_agent_syntax_diagnostics { time.sys_mono_now() } else { u64(0) }
	prepared := <-ready
	if user_agent_syntax_diagnostics {
		off_thread := prepared.thread_id != platform.native_thread_identity()
		eprintln('VOX_UA_STYLESHEET_SYNTAX rules=${prepared.rules.len} off_thread=${off_thread} ready=${prepared.ready_ns <= companion_ready}')
	}
	css_stage := processmetrics.begin_instruction_stage('css_parsing')
	defer { css_stage.finish() }
	cache_rules := !disable_stylesheet_rule_cache && stylesheet_rule_cache_.eligible(source)
	deferred := os.getenv('VOX_EAGER_USER_AGENT_DECLARATIONS') == ''
	if stylesheet_parse_diagnostics {
		eprintln('VOX_CSS_PARSE location=- bytes=${source.len} deferred=${deferred} cached=false rule_context=0')
	}
	id := if cache_rules {
		stylesheet_rule_cache_.store(source, prepared.rules)
	} else { u64(0) }
	mut default_sheet := convert_transient_stylesheet_rules(ParsingParams{is_ua_style_sheet: .yes},
		prepared.rules, none, none, deferred, id)
	default_sheet.process_lifetime = true
	return UserAgentStyleSheets{
		default_sheet: default_sheet
		quirks: quirks
		mathml: mathml
		svg: svg
	}
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
	return user_agent_default_stylesheet.css_rules().rules
}

// The shared parsed user-agent stylesheet for `url`, or none if that sheet isn't embedded.
pub fn user_agent_default_style_sheet(url string) ?&CSSStyleSheet {
	if url == 'CSS/Default.css' {
		return user_agent_default_stylesheet
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
