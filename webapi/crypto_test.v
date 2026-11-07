module main

import browserjs
import dom
import html

fn test_native_document_crypto_uses_the_owning_service_and_replays_random_operations() {
	$if !darwin {
		return
	}
	document := parse_browser_navigation_document('<div id="result">pending</div>',
		dom.URL{value: 'https://crypto.example/'}, none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://crypto.example/', [
		'const random=new Uint8Array(32);const same=crypto.getRandomValues(random)===random;const uuid=crypto.randomUUID();result.textContent=same&&random.some(byte=>byte!==0)&&crypto===crypto&&crypto.subtle===crypto.subtle&&crypto instanceof Crypto&&crypto.subtle instanceof SubtleCrypto&&/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(uuid)?"source crypto":"wrong crypto";',
	], runtime, mut messages)
	assert messages == []
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'source crypto'
	settings := document.relevant_settings_object()
	assert settings != unsafe { nil }
	actual := runtime.native_crypto(runtime.evaluate_host_value('crypto')!)!
	mut owner := unsafe { &html.EnvironmentSettingsObject(settings) }
	mut scope := owner.window_or_worker_global_scope()!
	assert voidptr(actual) == voidptr(scope.crypto().crypto())
	assert !runtime.libjs_vm().has_running_execution_context()
}
