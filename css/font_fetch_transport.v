// FontComputer.cpp: host adapter for fetch_a_style_resource's RequestServer.
@[has_globals]
module css

import dom
import fetch

pub type FontFetchHostProvider = fn (&dom.Document) ?&fetch.FetchHost

__global font_fetch_host_provider_ ?FontFetchHostProvider = ?FontFetchHostProvider(none)

pub fn install_font_fetch_host_provider(provider FontFetchHostProvider) {
	font_fetch_host_provider_ = provider
}

pub fn (mut computer FontComputer) set_fetch_host(host ?&fetch.FetchHost) {
	computer.fetch_host_ = unsafe { host }
}

fn (computer &FontComputer) font_fetch_host() ?&fetch.FetchHost {
	if host := computer.fetch_host_ { return host }
	if document := computer.document_ {
		if provider := font_fetch_host_provider_ { return provider(document) }
	}
	return none
}

fn font_rule_or_declaration(computer &FontComputer, rule ?&CSSFontFaceRule) RuleOrDeclaration {
	environment := if document := computer.document_ {
		CSSFetchEnvironmentSettings.from_document(document)
	} else {
		CSSFetchEnvironmentSettings{}
	}
	return RuleOrDeclaration{
		value:                       RuleOrDeclarationRule{
			parent_style_sheet: if parent := rule { parent.parent_style_sheet } else { none }
		}
		environment_settings_object: environment
	}
}
