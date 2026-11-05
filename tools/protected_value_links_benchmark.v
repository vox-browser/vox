// Component diagnostic of real JavaScriptCore protection and registry calls.
module main

import browserjs
import processmetrics

fn measure_protection_scene(mut runtime browserjs.Runtime, name string, values []voidptr, copies int, repetitions int, absent bool) {
	mut checksum := u64(0)
	start := processmetrics.instruction_snapshot()
	for _ in 0 .. repetitions {
		if !absent {
			for _ in 0 .. copies {
				for value in values {
					retained := runtime.retain_javascript_value(value) or { panic(err) }
					assert retained == value
					checksum++
				}
			}
		}
		for _ in 0 .. copies {
			for index in 0 .. values.len {
				// An odd multiplier permutes each power-of-two-sized bank.
				runtime.release_javascript_value(values[(index * 173) % values.len])
			}
		}
	}
	instructions := processmetrics.instruction_snapshot().since(start) or { panic('instruction counter unavailable') }
	println('{"scene":"${name}","instructions":${instructions},"protections":${if absent {
		0
	} else {
		values.len * copies * repetitions
	}},"releases":${values.len * copies * repetitions},"checksum":${checksum}}')
}

fn main() {
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	// The JS global keeps every bank object alive independently of the host
	// registry, including the intervals after its last host protection ends.
	runtime.evaluate_host('globalThis.__voxProtectionBank = Array.from({length:256}, (_,i)=>({i}))') or { panic(err) }
	mut values := []voidptr{cap: 256}
	for index in 0 .. 256 {
		value := runtime.evaluate_host_value('__voxProtectionBank[${index}]') or { panic(err) }
		values << value
		runtime.release_javascript_value(value)
	}
	measure_protection_scene(mut runtime, 'distinct-churn', values, 1, 128, false)
	measure_protection_scene(mut runtime, 'one-handle-duplicates', values[..1], 1024, 64, false)
	measure_protection_scene(mut runtime, 'duplicate-fanout', values[..64], 8, 128, false)
	measure_protection_scene(mut runtime, 'absent-handles', values, 1, 256, true)
	assert runtime.evaluate_host('String(__voxProtectionBank[255].i)') or { panic(err) } == '255'
}
