module browserjs

import dom
import os

@[heap]
struct URLFixtureOutput {
mut:
	lines []string
}

fn test_native_url_binding_matches_unmodified_source_url_and_query_fixture_outputs() {
	$if !darwin { return }
	source := os.getenv_opt('LADYBIRD_SOURCE_DIR') or { os.home_dir() + '/code/3rd/ladybird' }
	for name in ['url', 'search-params-with-no-query'] {
		mut runtime := Runtime.create()
		address := dom.URL{
			value: 'https://url-fixture.example.test/'
		}
		document := &dom.Document{
			url:     address
			origin_: address.origin()
		}
		mut query := URLSearchParamsHost.create(document)!
		query.install(mut runtime)!
		mut host := URLHost.create(document)!
		host.install(mut runtime)!
		mut output := &URLFixtureOutput{}
		owner := voidptr(runtime)
		runtime.define_value_host_function('println', fn [owner, mut output] (_ voidptr, args []voidptr) !voidptr {
			runtime := unsafe { &Runtime(owner) }
			output.lines << runtime.native_utf16_string(args[0])!.str()
			return C.vox_jsc_JSValueMakeUndefined(runtime.context)
		})!
		runtime.evaluate_host('globalThis.test=function(callback){callback()}')!
		input := os.read_file('${source}/Tests/LibWeb/Text/input/URL/${name}.html')!
		script := input.all_after('<script>').all_before('</script>')
		assert script != ''
		runtime.evaluate_host(script)!
		actual := output.lines.join('\n') + '\n'
		os.write_file('Build/audit-fixes/source-url-host-${name}.actual.txt', actual)!
		expected := os.read_file('${source}/Tests/LibWeb/Text/expected/URL/${name}.txt')!
		assert actual == expected
		runtime.close()
	}
}
