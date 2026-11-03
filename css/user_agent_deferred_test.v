module css

import dom
import os
import platform

fn test_user_agent_lazy_rules_serialize_exactly_as_eager_rules() {
	previous := os.getenv_opt('VOX_EAGER_USER_AGENT_DECLARATIONS')
	defer {
		if value := previous { os.setenv('VOX_EAGER_USER_AGENT_DECLARATIONS', value, true) }
		else { os.unsetenv('VOX_EAGER_USER_AGENT_DECLARATIONS') }
	}
	for source in [user_agent_cascade_stylesheet_source, user_agent_mathml_stylesheet_source, user_agent_svg_stylesheet_source] {
		os.unsetenv('VOX_EAGER_USER_AGENT_DECLARATIONS')
		lazy := parse_shared_user_agent_stylesheet(source)
		os.setenv('VOX_EAGER_USER_AGENT_DECLARATIONS', '1', true)
		eager := parse_shared_user_agent_stylesheet(source)
		assert lazy.process_lifetime && eager.process_lifetime
		assert lazy.rules.length() == eager.rules.length()
		mut deferred := 0
		for index in 0 .. lazy.rules.length() {
			rule := lazy.rules.item(index) or { panic('lazy rule') }
			reference := eager.rules.item(index) or { panic('eager rule') }
			if declaration := rule.declaration {
				if declaration.deferred_declarations_ != none { deferred++ }
			}
			assert rule.css_text() == reference.css_text()
		}
		assert deferred > 0
	}
}

fn test_process_lifetime_ua_declarations_outlive_the_materializing_document_arena() {
	sheet := parse_shared_user_agent_stylesheet('div { display: block; color: rgb(11 22 33); width: 13px; }')
	rule := sheet.rules.item(0) or { panic('UA rule') }
	mut document := dom.Document.create(dom.url_about_blank())
	$if prealloc { document.enable_native_storage() }
	mut owner := document.enter_native_storage()
	scratch := platform.begin_thread_scratch('deferred UA properties')
	mut declaration := rule.style() or { panic('UA declaration') }
	assert declaration.get_property_value('width') == '13px'
	scratch.finish()
	owner.finish()
	document.release_native_storage()
	assert declaration.get_property_value('color') == 'rgb(11, 22, 33)'
	assert declaration.get_property_value('display') == 'block'
	declaration.set_property('width', '17px', '')!
	assert declaration.get_property_value('width') == '17px'
	assert declaration.get_property_value('color') == 'rgb(11, 22, 33)'
}
