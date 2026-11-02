module browserjs

import dom
import os

@[heap]
struct QueryFixtureOutput {
mut:
	lines []string
}

fn test_native_query_binding_matches_unmodified_source_sort_fixture_outputs() {
	$if !darwin { return }
	source := os.getenv_opt('LADYBIRD_SOURCE_DIR') or { os.home_dir() + '/code/3rd/ladybird' }
	for name in ['url-search-params-sort-utf16-code-units', 'url-search-params-sort-order-stable'] {
		mut runtime := Runtime.create()
		url := dom.URL{
			value: 'https://query-fixture.example.test/'
		}
		document := &dom.Document{
			url:     url
			origin_: url.origin()
		}
		mut host := URLSearchParamsHost.create(document)!
		host.install(mut runtime)!
		mut output := &QueryFixtureOutput{}
		owner := voidptr(runtime)
		runtime.define_value_host_function('println', fn [owner, mut output] (_ voidptr, args []voidptr) !voidptr {
			runtime := unsafe { &Runtime(owner) }
			output.lines << runtime.native_utf16_string(args[0])!.str()
			return C.vox_jsc_JSValueMakeUndefined(runtime.context)
		})!
		runtime.evaluate_host('globalThis.test=function(callback){callback()}')!
		input := os.read_file('${source}/Tests/LibWeb/Text/input/URL/${name}.html')!
		// Only the external test harness is replaced. The inline Source
		// JavaScript and its expected output are read without case overrides.
		script := input.all_after('<script>').all_before('</script>')
		assert script != ''
		runtime.evaluate_host(script)!
		expected := os.read_file('${source}/Tests/LibWeb/Text/expected/URL/${name}.txt')!
		assert output.lines.join('\n') + '\n' == expected
		assert !runtime.libjs_vm().has_running_execution_context()
		runtime.close()
	}
}
