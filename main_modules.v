module main

import browserjs
import dom
import html
import os

const retain_separate_module_connection = os.getenv('VOX_RETAIN_SEPARATE_MODULE_CONNECTION') != ''

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
	}
}
