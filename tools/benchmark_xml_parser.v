module main

import crypto.sha256
import dom
import html
import json2
import os
import strings
import time

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

$if linux || macos {
	#include <time.h>
	fn C.clock_gettime(i32, &C.timespec) i32
}

// Compile this standalone tool with the same V revision, backend, optimization
// and allocator in both source revisions. It calls the shared production XML
// entry point and includes actual DOM construction in the parse interval.
//
//   benchmark_xml_parser --workload small-svg --iterations 1000 --warmup 10
//   benchmark_xml_parser --workload many-elements --size 1000 --iterations 30
//   benchmark_xml_parser --fixture image.svg --iterations 100 --mode retained
//
// Source construction/read, document creation, full-tree verification and
// destroy/finalize are outside parse_ns and separately reported. Parsing enters
// an explicitly owned native document arena; its scope ends before verification.
// Scope exit and final retirement count toward cleanup_ns. No forced GC is
// performed. cleanup retires each document before the next parse; retained
// keeps all measured documents alive until the batch ends. Neither mode is a
// whole-browser navigation or rendering benchmark. Use an external memory
// guard and alternate fresh before/after processes for comparisons. Disable
// VOX_ARENA_POISON and VOX_ARENA_NO_REUSE for matched performance runs.

struct XMLBenchmarkOptions {
mut:
	workload   string = 'small-svg'
	fixture    string
	size       int
	iterations int    = 100
	warmup     int    = 3
	mode       string = 'cleanup'
}

struct XMLBenchmarkExpectation {
	root_name               string
	root_namespace          string
	elements                int
	attributes              int
	text_nodes              int
	cdata_nodes             int
	comments                int
	processing_instructions int
	text_bytes              int
	namespaced_attributes   int
}

struct XMLBenchmarkInput {
	name        string
	source      string
	size        int
	expectation ?XMLBenchmarkExpectation
}

struct XMLBenchmarkTree {
mut:
	checksum                string
	root_name               string
	root_namespace          string
	nodes                   int
	elements                int
	attributes              int
	text_nodes              int
	cdata_nodes             int
	comments                int
	processing_instructions int
	doctypes                int
	text_bytes              int
	namespaced_elements     int
	namespaced_attributes   int
	max_depth               int
}

struct XMLBenchmarkDigest {
mut:
	hash u64 = 14695981039346656037
	tree XMLBenchmarkTree
}

struct XMLBenchmarkResult {
	schema_version                   int    = 1
	scope                            string = 'html.parse_xml_document_source including DOM construction; setup, verification and cleanup excluded'
	storage_scope                    string = 'explicit native document owner; parse allocations retained until document retirement'
	workload                         string
	size                             int
	mode                             string
	allocator                        string
	iterations                       int
	warmup                           int
	source_bytes                     int
	source_sha256                    string
	processed_bytes                  i64
	parse_ns                         i64
	parse_min_ns                     i64
	parse_median_ns                  i64
	parse_max_ns                     i64
	parse_ns_per_iteration           f64
	parse_mib_per_second             f64
	parse_samples_ns                 []i64
	parse_cpu_ns                     i64
	parse_cpu_samples_ns             []i64
	process_cpu_available            bool
	arena_usage_available            bool
	arena_used_bytes_after_parse     []i64
	arena_capacity_bytes_after_parse []i64
	gc_allocated_bytes_available     bool
	gc_allocated_bytes_during_parse  []u64
	setup_ns                         i64
	verification_ns                  i64
	cleanup_ns                       i64
	batch_elapsed_ns                 i64
	batch_cpu_ns                     i64
	tree                             XMLBenchmarkTree
}

fn xml_benchmark_wall_ns() i64 {
	return i64(time.sys_mono_now())
}

fn xml_benchmark_cpu_ns() i64 {
	$if linux || macos {
		mut value := C.timespec{}
		if C.clock_gettime(C.CLOCK_PROCESS_CPUTIME_ID, &value) != 0 {
			panic('could not read the process CPU clock')
		}
		return value.tv_sec * i64(1000000000) + value.tv_nsec
	}
	return 0
}

fn xml_benchmark_allocator() string {
	$if prealloc {
		return 'prealloc'
	}
	$if gcboehm ? {
		return 'boehm'
	}
	return 'other'
}

fn xml_benchmark_gc_bytes() u64 {
	$if gcboehm ? {
		return u64(C.GC_get_total_bytes())
	}
	return 0
}

fn xml_benchmark_arena_bytes(document &dom.Document) (i64, i64) {
	storage := document.native_storage()
	if storage == unsafe { nil } || storage.arena == unsafe { nil } { return 0, 0 }
	usage := storage.arena.usage()
	return usage.used, usage.capacity
}

fn xml_benchmark_integer(value string, minimum int) !int {
	if value == '' { return error('empty integer argument') }
	for byte in value {
		if byte < `0` || byte > `9` { return error('invalid integer: ${value}') }
	}
	number := value.int()
	if number < minimum { return error('expected an integer >= ${minimum}: ${value}') }
	return number
}

fn xml_benchmark_options() !XMLBenchmarkOptions {
	if os.getenv('VOX_ARENA_POISON') == '1' || os.getenv('VOX_ARENA_NO_REUSE') != '' {
		return error('disable VOX_ARENA_POISON and VOX_ARENA_NO_REUSE for performance measurements')
	}
	mut options := XMLBenchmarkOptions{}
	mut explicit_workload := false
	mut index := 1
	for index < os.args.len {
		argument := os.args[index]
		if argument == '--help' {
			println('usage: benchmark_xml_parser [--workload small-svg|many-elements|attributes|mixed|indented|entities|large-text | --fixture PATH] [--size N] [--iterations N] [--warmup N] [--mode cleanup|retained]')
			exit(0)
		}
		if index + 1 >= os.args.len { return error('${argument} requires a value') }
		index++
		value := os.args[index]
		match argument {
			'--workload' {
				options.workload = value
				explicit_workload = true
			}
			'--fixture' { options.fixture = value }
			'--size' { options.size = xml_benchmark_integer(value, 1)! }
			'--iterations' { options.iterations = xml_benchmark_integer(value, 1)! }
			'--warmup' { options.warmup = xml_benchmark_integer(value, 0)! }
			'--mode' { options.mode = value }
			else { return error('unknown argument ${argument}') }
		}
		index++
	}
	if options.mode !in ['cleanup', 'retained'] { return error('mode must be cleanup or retained') }
	if options.fixture != '' && (explicit_workload || options.size != 0) {
		return error('--fixture cannot be combined with --workload or --size')
	}
	return options
}

fn xml_benchmark_input(options XMLBenchmarkOptions) !XMLBenchmarkInput {
	if options.fixture != '' {
		return XMLBenchmarkInput{ name: options.fixture, source: os.read_file(options.fixture)! }
	}
	default_size := match options.workload {
		'small-svg' { 1 }
		'many-elements', 'mixed', 'indented', 'indentation', 'entities' { 1000 }
		'attributes' { 100 }
		'large-text' { 16384 }
		else { return error('unknown workload ${options.workload}') }
	}
	size := if options.size > 0 { options.size } else { default_size }
	mut source := strings.new_builder(1024)
	mut expected := XMLBenchmarkExpectation{}
	match options.workload {
		'small-svg' {
			source.write_string('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">')
			source.write_string('<path d="M2 12L10 20L22 4" fill="none" stroke="currentColor"/>'.repeat(size))
			source.write_string('<circle cx="12" cy="12" r="10"/></svg>')
			expected = XMLBenchmarkExpectation{ root_name: 'svg', root_namespace: 'http://www.w3.org/2000/svg', elements: 2 + size, attributes: 5 + 3 * size, namespaced_attributes: 1 }
		}
		'many-elements' {
			source.write_string('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 1000 1000">')
			for index in 0 .. size {
				source.write_string('<g id="g${index}" fill="#336699"><path d="M0 0L8 0L8 8Z"/><use xlink:href="#g${index}" x="12"/></g>')
			}
			source.write_string('</svg>')
			expected = XMLBenchmarkExpectation{ root_name: 'svg', root_namespace: 'http://www.w3.org/2000/svg', elements: 1 + 3 * size, attributes: 3 + 5 * size, namespaced_attributes: 2 + size }
		}
		'attributes' {
			source.write_string('<root xmlns="urn:benchmark" xmlns:a="urn:attrs">')
			for index in 0 .. size {
				source.write_string('<item id="row${index}" a:token="row${index}"')
				for attribute in 0 .. 64 {
					source.write_string(' k${attribute}="value${attribute}"')
				}
				source.write_string('/>')
			}
			source.write_string('</root>')
			expected = XMLBenchmarkExpectation{ root_name: 'root', root_namespace: 'urn:benchmark', elements: 1 + size, attributes: 2 + 66 * size, namespaced_attributes: 2 + size }
		}
		'mixed' {
			source.write_string('<root xmlns="urn:benchmark">')
			for index in 0 .. size {
				source.write_string(' head <item id="${index}">inner <![CDATA[<raw>]]><!--note--><?work data?> tail</item> foot ')
			}
			source.write_string('</root>')
			expected = XMLBenchmarkExpectation{ root_name: 'root', root_namespace: 'urn:benchmark', elements: 1 + size, attributes: 1 + size, text_nodes: 3 * size + 1, cdata_nodes: size, comments: size, processing_instructions: size, text_bytes: 28 * size, namespaced_attributes: 1 }
		}
		'indented', 'indentation' {
			source.write_string('<root xmlns="urn:benchmark">')
			for index in 0 .. size {
				source.write_string('\n  <group id="${index}">\n    <item/>\n  </group>')
			}
			source.write_string('\n</root>')
			// Root separators contain 3 * size + 1 whitespace bytes; each
			// nested group contributes two more text nodes and eight bytes.
			expected = XMLBenchmarkExpectation{ root_name: 'root', root_namespace: 'urn:benchmark', elements: 1 + 2 * size, attributes: 1 + size, text_nodes: 3 * size + 1, text_bytes: 11 * size + 1, namespaced_attributes: 1 }
		}
		'entities' {
			source.write_string('<root xmlns="urn:benchmark">')
			source.write_string('<item a="&amp;amp; &AElig; &NotEqualTilde;">Привет 文 😀 &amp;amp; &AElig; &NotEqualTilde; &#65; &#x1F600;</item>'.repeat(size))
			source.write_string('</root>')
			expected = XMLBenchmarkExpectation{ root_name: 'root', root_namespace: 'urn:benchmark', elements: 1 + size, attributes: 1 + size, text_nodes: size, text_bytes: 'Привет 文 😀 &amp; Æ ≂̸ A 😀'.len * size, namespaced_attributes: 1 }
		}
		'large-text' {
			text := 'The quick brown fox jumps over the lazy dog. Привет 文 😀\n'
			source.write_string('<root xmlns="urn:benchmark">')
			source.write_string(text.repeat(size))
			source.write_string('</root>')
			expected = XMLBenchmarkExpectation{ root_name: 'root', root_namespace: 'urn:benchmark', elements: 1, attributes: 1, text_nodes: 1, text_bytes: text.len * size, namespaced_attributes: 1 }
		}
		else { return error('unknown workload ${options.workload}') }
	}
	return XMLBenchmarkInput{ name: options.workload, source: source.str(), size: size, expectation: expected }
}

fn (mut digest XMLBenchmarkDigest) number(value u64) {
	for shift in 0 .. 8 {
		digest.hash = (digest.hash ^ ((value >> (shift * 8)) & 255)) * u64(1099511628211)
	}
}

fn (mut digest XMLBenchmarkDigest) field(value string) {
	digest.number(u64(value.len))
	for byte in value { digest.hash = (digest.hash ^ u64(byte)) * u64(1099511628211) }
}

fn xml_benchmark_visit(node &dom.Node, depth int, mut digest XMLBenchmarkDigest) ! {
	digest.tree.nodes++
	if depth > digest.tree.max_depth { digest.tree.max_depth = depth }
	digest.number(u64(node.node_type_value()))
	digest.field(node.node_name())
	if element := node.as_element() {
		digest.tree.elements++
		namespace_ := element.namespace_uri() or { '' }
		if namespace_ != '' { digest.tree.namespaced_elements++ }
		digest.field(namespace_)
		digest.field(element.prefix() or { '' })
		digest.field(element.local_name())
		mut names := element.get_attribute_names()
		names.sort()
		digest.number(u64(names.len))
		if attributes := element.attribute_list() {
			for name in names {
				attribute := attributes.get_attribute(name) or { return error('missing attribute ${name}') }
				digest.tree.attributes++
				attribute_namespace := attribute.namespace_uri() or { '' }
				if attribute_namespace != '' { digest.tree.namespaced_attributes++ }
				digest.field(attribute_namespace)
				digest.field(attribute.name())
				digest.field(attribute.local_name())
				digest.field(attribute.prefix() or { '' })
				digest.field(attribute.value())
			}
		}
	}
	if data := node.character_data() {
		digest.field(data.data())
		if node.is_exclusive_text() {
			digest.tree.text_nodes++
			digest.tree.text_bytes += data.data().len
		}
		if node.is_cdata_section() {
			digest.tree.cdata_nodes++
			digest.tree.text_bytes += data.data().len
		}
		if node.is_comment() { digest.tree.comments++ }
		if node.as_processing_instruction() != none { digest.tree.processing_instructions++ }
	}
	if doctype := node.as_document_type() {
		digest.tree.doctypes++
		digest.field(doctype.name())
		digest.field(doctype.public_id())
		digest.field(doctype.system_id())
	}
	digest.number(u64(node.children.len))
	for child in node.children { xml_benchmark_visit(child, depth + 1, mut digest)! }
}

fn xml_benchmark_tree(document &dom.Document) !XMLBenchmarkTree {
	root := document.document_element() or { return error('parsed document has no root element') }
	mut digest := XMLBenchmarkDigest{}
	digest.tree.root_name = root.node_name().clone()
	digest.tree.root_namespace = (root.namespace_uri() or { '' }).clone()
	xml_benchmark_visit(document.as_node(), 0, mut digest)!
	digest.tree.checksum = digest.hash.hex()
	return digest.tree
}

fn xml_benchmark_check(input XMLBenchmarkInput, tree XMLBenchmarkTree, baseline ?XMLBenchmarkTree) ! {
	if expected := input.expectation {
		expected_nodes := 1 + expected.elements + expected.text_nodes + expected.cdata_nodes +
			expected.comments + expected.processing_instructions
		if tree.root_name != expected.root_name || tree.root_namespace != expected.root_namespace
			|| tree.nodes != expected_nodes || tree.elements != expected.elements
			|| tree.attributes != expected.attributes || tree.text_nodes != expected.text_nodes
			|| tree.cdata_nodes != expected.cdata_nodes || tree.comments != expected.comments
			|| tree.processing_instructions != expected.processing_instructions || tree.doctypes != 0
			|| tree.text_bytes != expected.text_bytes || tree.namespaced_elements != expected.elements
			|| tree.namespaced_attributes != expected.namespaced_attributes {
			return error('unexpected ${input.name} DOM: ${json2.encode(tree,
				escape_unicode: true
				time_as_unix:   true
			)}')
		}
	}
	if previous := baseline {
		if tree != previous {
			return error('DOM changed between iterations: ${json2.encode(tree,
				escape_unicode: true
				time_as_unix:   true
			)}')
		}
	}
}

fn xml_benchmark_retire(mut document dom.Document) {
	document.destroy()
	document.finalize()
	document.release_native_storage()
}

fn xml_benchmark_run(options XMLBenchmarkOptions, input XMLBenchmarkInput) !XMLBenchmarkResult {
	mut baseline := ?XMLBenchmarkTree(none)
	for _ in 0 .. options.warmup {
		mut document := dom.Document.create(dom.url_about_blank())
		document.set_document_type(.xml)
		document.enable_native_storage()
		mut allocations := document.enter_native_storage()
		html.parse_xml_document_source(document, input.source) or {
			allocations.finish()
			xml_benchmark_retire(mut document)
			return err
		}
		allocations.finish()
		tree := xml_benchmark_tree(document) or {
			xml_benchmark_retire(mut document)
			return err
		}
		xml_benchmark_check(input, tree, baseline) or {
			xml_benchmark_retire(mut document)
			return err
		}
		baseline = tree
		xml_benchmark_retire(mut document)
	}
	mut samples := []i64{cap: options.iterations}
	mut cpu_samples := []i64{cap: options.iterations}
	mut arena_used_samples := []i64{cap: options.iterations}
	mut arena_capacity_samples := []i64{cap: options.iterations}
	mut gc_bytes_samples := []u64{cap: options.iterations}
	mut retained := []&dom.Document{cap: if options.mode == 'retained' {
		options.iterations
	} else {
		0
	}}
	mut setup_ns := i64(0)
	mut verification_ns := i64(0)
	mut cleanup_ns := i64(0)
	mut parse_ns := i64(0)
	mut parse_cpu_ns := i64(0)
	batch_cpu_start := xml_benchmark_cpu_ns()
	batch_start := xml_benchmark_wall_ns()
	for _ in 0 .. options.iterations {
		setup_start := xml_benchmark_wall_ns()
		mut document := dom.Document.create(dom.url_about_blank())
		document.set_document_type(.xml)
		document.enable_native_storage()
		mut allocations := document.enter_native_storage()
		setup_ns += xml_benchmark_wall_ns() - setup_start
		gc_before := xml_benchmark_gc_bytes()
		parse_cpu_start := xml_benchmark_cpu_ns()
		parse_start := xml_benchmark_wall_ns()
		html.parse_xml_document_source(document, input.source) or {
			allocations.finish()
			xml_benchmark_retire(mut document)
			return err
		}
		elapsed := xml_benchmark_wall_ns() - parse_start
		cpu_elapsed := xml_benchmark_cpu_ns() - parse_cpu_start
		gc_after := xml_benchmark_gc_bytes()
		arena_used, arena_capacity := xml_benchmark_arena_bytes(document)
		scope_leave_start := xml_benchmark_wall_ns()
		allocations.finish()
		cleanup_ns += xml_benchmark_wall_ns() - scope_leave_start
		// Capture allocation counters before sample arrays or verification can
		// allocate. The process CPU interval also includes the two wall reads.
		parse_ns += elapsed
		parse_cpu_ns += cpu_elapsed
		samples << elapsed
		cpu_samples << cpu_elapsed
		arena_used_samples << arena_used
		arena_capacity_samples << arena_capacity
		gc_bytes_samples << gc_after - gc_before
		verify_start := xml_benchmark_wall_ns()
		tree := xml_benchmark_tree(document) or {
			xml_benchmark_retire(mut document)
			return err
		}
		xml_benchmark_check(input, tree, baseline) or {
			xml_benchmark_retire(mut document)
			return err
		}
		baseline = tree
		verification_ns += xml_benchmark_wall_ns() - verify_start
		if options.mode == 'retained' {
			retained << document
		} else {
			cleanup_start := xml_benchmark_wall_ns()
			xml_benchmark_retire(mut document)
			cleanup_ns += xml_benchmark_wall_ns() - cleanup_start
		}
	}
	if options.mode == 'retained' {
		cleanup_start := xml_benchmark_wall_ns()
		for mut document in retained { xml_benchmark_retire(mut document) }
		cleanup_ns += xml_benchmark_wall_ns() - cleanup_start
	}
	batch_elapsed := xml_benchmark_wall_ns() - batch_start
	batch_cpu_elapsed := xml_benchmark_cpu_ns() - batch_cpu_start
	mut sorted := samples.clone()
	sorted.sort()
	middle := sorted.len / 2
	median := if sorted.len % 2 == 0 {
		(sorted[middle - 1] + sorted[middle]) / 2
	} else {
		sorted[middle]
	}
	processed_bytes := i64(input.source.len) * i64(options.iterations)
	return XMLBenchmarkResult{
		workload:                         input.name
		size:                             input.size
		mode:                             options.mode
		allocator:                        xml_benchmark_allocator()
		iterations:                       options.iterations
		warmup:                           options.warmup
		source_bytes:                     input.source.len
		source_sha256:                    sha256.hexhash(input.source)
		processed_bytes:                  processed_bytes
		parse_ns:                         parse_ns
		parse_min_ns:                     sorted[0]
		parse_median_ns:                  median
		parse_max_ns:                     sorted[sorted.len - 1]
		parse_ns_per_iteration:           f64(parse_ns) / f64(options.iterations)
		parse_mib_per_second:             if parse_ns > 0 {
			f64(processed_bytes) * 1e9 / (f64(parse_ns) * 1048576.0)
		} else {
			0
		}
		parse_samples_ns:                 samples
		parse_cpu_ns:                     parse_cpu_ns
		parse_cpu_samples_ns:             cpu_samples
		process_cpu_available:            $if linux || macos { true } $else { false }
		arena_usage_available:            $if prealloc { true } $else { false }
		arena_used_bytes_after_parse:     arena_used_samples
		arena_capacity_bytes_after_parse: arena_capacity_samples
		gc_allocated_bytes_available:     $if gcboehm ? { true } $else { false }
		gc_allocated_bytes_during_parse:  gc_bytes_samples
		setup_ns:                         setup_ns
		verification_ns:                  verification_ns
		cleanup_ns:                       cleanup_ns
		batch_elapsed_ns:                 batch_elapsed
		batch_cpu_ns:                     batch_cpu_elapsed
		tree:                             baseline or { return error('no measured document') }
	}
}

fn main() {
	options := xml_benchmark_options() or {
		eprintln(err)
		exit(2)
	}
	input := xml_benchmark_input(options) or {
		eprintln(err)
		exit(2)
	}
	result := xml_benchmark_run(options, input) or {
		eprintln(err)
		exit(1)
	}
	println(json2.encode(result, escape_unicode: true, time_as_unix: true))
}
