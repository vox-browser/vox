module main

import browserjs
import dom
import html

fn install_compact_module_host(document &dom.Document, mut runtime browserjs.Runtime) ! {
	$if darwin {
		settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
		mut host := browserjs.ModuleHost.create_native(settings)!
		host.install(mut runtime) or {
			host.close()
			return err
		}
	}
}
