module main

import browserjs
import css
import dom
import fetch
import html
import os

const retain_separate_module_connection = os.getenv('VOX_RETAIN_SEPARATE_MODULE_CONNECTION') != ''
const disable_module_preloads = os.getenv('VOX_DISABLE_MODULE_PRELOADS') != ''

fn install_compact_module_host(document &dom.Document, mut runtime browserjs.Runtime) ! {
	$if darwin {
		settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
		mut host := if transport := runtime.installed_fetch_transport() {
			if retain_separate_module_connection {
				browserjs.ModuleHost.create_native(settings)!
			} else {
				browserjs.ModuleHost.create(settings, transport)
			}
		} else {
			browserjs.ModuleHost.create_native(settings)!
		}
		host.install(mut runtime) or {
			host.close()
			return err
		}
		if !disable_module_preloads {
			for preload in document_module_preloads(document, settings) {
				host.preload(preload.url, preload.options)
			}
		}
	}
}

struct DocumentModulePreload {
	url     string
	options html.ScriptFetchOptions
}

// The parsed document's <link rel=modulepreload> elements, in tree order.
// Only JavaScript module destinations without a media query are preloaded;
// any other link keeps the ordinary import-time fetch.
fn document_module_preloads(document &dom.Document, settings &html.EnvironmentSettingsObject) []DocumentModulePreload {
	base_url := document.base_url().serialize()
	mut preloads := []DocumentModulePreload{}
	mut seen := map[string]bool{}
	for element in css.query_selector_all(document.as_node(), 'link[rel][href]') {
		relations := element.get_attribute_value('rel').to_lower().fields()
		// A link that is also a stylesheet, icon or alternate takes the default
		// fetch algorithm instead of the modulepreload one.
		if 'modulepreload' !in relations || relations.any(it in ['stylesheet', 'icon', 'alternate']) {
			continue
		}
		destination := element.get_attribute_value('as').trim_space().to_lower()
		if destination !in ['', 'script'] || element.get_attribute_value('media').trim_space() != '' {
			continue
		}
		address := resolve_document_reference(element.get_attribute_value('href'), base_url)
		if !(address.starts_with('https://') || address.starts_with('http://')) || address in seen {
			continue
		}
		seen[address] = true
		integrity := if element.has_attribute('integrity') {
			element.get_attribute_value('integrity')
		} else {
			html.resolve_a_module_integrity_metadata(dom.URL{ value: address }, settings)
		}
		credentials := if element.get_attribute_value('crossorigin').trim_space().to_lower() == 'use-credentials' {
			fetch.CredentialsMode.include
		} else {
			fetch.CredentialsMode.same_origin
		}
		preloads << DocumentModulePreload{
			url:     address
			options: html.ScriptFetchOptions{
				cryptographic_nonce: element.cryptographic_nonce()
				integrity_metadata:  integrity
				credentials_mode:    credentials
				referrer_policy:     element.get_attribute_value('referrerpolicy').trim_space().to_lower()
			}
		}
	}
	return preloads
}
