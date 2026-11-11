// Benchmark the pure V JPEG XL decoder (module jpegxl). Always build with -prod:
//
//   v -prod -memory-limit 10G -o /tmp/jpegxl_bench tools/jpegxl_bench.v
//   /tmp/jpegxl_bench                      # bench inputs below, 7 decodes each
//   /tmp/jpegxl_bench -n 15 --paint a.jxl  # explicit files, premultiplied output
//
// Each file is decoded once untimed, then `-n` timed times. The report gives the
// minimum and median wall time, megapixels per second at the minimum, and the
// first 16 hex digits of the output's SHA-256 so an optimization can be checked
// for byte-identical pixels. Run under tools/run_memory_bounded.py and record
// host load: wall times on a busy machine are noisy, so compare retired
// instructions (`/usr/bin/time -l`) for small changes.
module main

import crypto.sha256
import flag
import jpegxl
import os
import time

const default_inputs = ['jpegxl/testdata/bench/progressive_ac.jxl',
	'jpegxl/testdata/bench/green_queen_vardct_e3.jxl', 'jpegxl/testdata/bench/green_queen_modular_e3.jxl',
	'jpegxl/testdata/native-corpus/issue648_palette0.jxl',
	'jpegxl/testdata/patch-frames/text-520x300-c1-e9-d1.jxl',
	'jpegxl/testdata/patch-frames/text-rgba-300x260-ramp-ll.jxl']

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('jpegxl_bench')
	fp.description('Decode JPEG XL files repeatedly with the V decoder and report timings.')
	fp.skip_executable()
	iterations := fp.int('iterations', `n`, 7, 'timed decodes per file')
	paint := fp.bool('paint', 0, false, 'request premultiplied paint rows')
	files := fp.finalize() or {
		eprintln(err)
		exit(2)
	}
	if iterations < 1 {
		eprintln('--iterations must be positive')
		exit(2)
	}
	root := os.dir(os.dir(os.real_path(@FILE)))
	inputs := if files.len > 0 { files } else { default_inputs.map(os.join_path(root, it)) }
	mut total_min := 0.0
	for path in inputs {
		data := os.read_bytes(path) or {
			eprintln('${path}: ${err}')
			exit(1)
		}
		first := jpegxl.decode_rgba(data, paint) or {
			eprintln('${os.file_name(path)}: ${err}')
			continue
		}
		digest := sha256.sum(first.pixels).hex()[..16]
		mut times := []f64{cap: iterations}
		for _ in 0 .. iterations {
			sw := time.new_stopwatch()
			image := jpegxl.decode_rgba(data, paint) or { panic(err) }
			times << f64(sw.elapsed().microseconds()) / 1000.0
			if image.pixels.len != first.pixels.len { panic('unstable output size') }
		}
		times.sort()
		minimum := times[0]
		median := times[times.len / 2]
		megapixels := f64(first.width) * f64(first.height) / 1_000_000.0
		total_min += minimum
		println('${os.file_name(path):-40s} ${first.width:5d}x${first.height:-5d} min ${minimum:8.1f} ms  median ${median:8.1f} ms  ${megapixels / (minimum / 1000.0):6.1f} MP/s  ${digest}')
	}
	println('total of minimums: ${total_min:.1f} ms')
}
