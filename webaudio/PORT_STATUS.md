# WebAudio V translation status

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/WebAudio`

Translation workspace: `~/code/vox2/webaudio`

Audited: 2026-09-13 against Ladybird
`963d46a829f3e1b79f44dba9d02afb70654300fa`.

The current WebAudio tree is translated and symbol-audited. All 47 upstream
implementation units, 52 headers, and 32 IDL files have active V mappings; the
module contains 33 implementation V units (8,682 physical lines) and 31 test V
units (3,247 physical lines).

| Source area | Upstream files / LOC | V implementation |
| --- | ---: | --- |
| Core graph, node/parameter state, control messages | included below | `types_core.v`, `audio_algorithms.v` |
| Buffers, arrays, parameter maps and automation | included below | `buffer_analyser.v`, `audio_buffer_contents.v`, `audio_array.v`, `audio_param_map.v`, `audio_param_timeline.v` |
| Contexts, listeners, spatial and media-stream nodes | included below | `context.v`, `spatial_offline.v`, `media_stream_audio_source.v`, `media_stream_audio_destination.v` |
| Node factories and DSP inputs | included below | `nodes.v`, `biquad_coefficients.v`, `periodic_wave_render_data.v` |
| Audio worklets and their fixed ring transport | included below | `audio_worklet.v`, `audio_worklet_node.v`, `audio_worklet_pipe.v` |
| Render graph, render nodes, offline/realtime drivers | included below | `render_*.v` |
| Audio decoding host bridge and portable WAVE path | included below | `audio_decode.c.v`, `audio_decode_bridge.h` |
| **All `*.cpp`** | **47 / 8,256** | **33 V units / 8,682 LOC** |
| All `*.h` | 52 / 3,776 | typed records and the implementation units above |
| All `*.idl` | 32 / 562 | typed enums, option dictionaries, events, attributes, and constructors |

The translated render path includes control-message application, connection
rebuilding and input summing; k-rate and a-rate parameter automation; scheduled
sources; constant, oscillator, buffer-source, gain, delay, splitter, merger,
stereo/spatial panner, biquad, analyser, destination, and current upstream
compressor passthrough nodes; offline quantum rendering with suspend/resume;
and realtime device-buffer filling with sample-rate conversion. AudioWorklet
registration, processor construction, parameter blocks, fixed-capacity input
and output rings, priming, wakeups, underrun/drop accounting, and shutdown are
also represented.

The public/control path covers constructor validation before allocation,
sample rates from 3,000 through 768,000 Hz, AudioBuffer snapshot acquisition,
automation cancellation and ramp edge cases, scheduled-source lifetime and
ended delivery, media-stream source/destination transport, listener and panner
updates, context lifecycle, output timestamps, and real audio decoding. Native
browser builds decode through FFmpeg and resample to the context rate; portable
builds retain PCM/integer/float WAVE decoding for deterministic operation.

## Reviewed representation boundaries

The V engine is single-threaded. Offline control-thread posts run synchronously,
and the host explicitly supplies realtime output buffers; the translated graph
and ring state retain the upstream ordering at those boundaries. JavaScript
realm lookup, WebIDL callback/promise wrapping, GC visitation, weak per-realm
`Float32Array` caches, ArrayBuffer detachment, and generated JIT member-offset
helpers belong to the embedding runtime. V uses typed slices, maps, pointers,
and direct record fields for the corresponding state. AudioBuffer acquisition
still establishes the required copy-on-write playback snapshot.

The fail-open semantic audit accounts for all 684 upstream implementations:

```text
  candidate-name-match: 540
  consolidated-name-match: 9
  gc-or-binding-runtime: 45
  language-constructor-or-destructor: 59
  value-record-field-match: 31
  unmatched: 0
```

Four intentionally small V bodies were compared directly with upstream: the
allocator-only `AudioParamMap.create`, default `RenderGraph.create`, and the
constant zero input/output arities on the two media-stream endpoint nodes.
There are no unreviewed trivial WebAudio bodies.

## Verification

```text
$ V_C_ERROR_BUG_REPORT_DISABLED=1 \
    /tmp/vox2-v-c3358d3.Qu9YHN/v1_fallback -enable-globals test webaudio
Summary for all V _test.v files: 31 passed, 31 total.

$ V_BIN=/tmp/vox2-v-c3358d3.Qu9YHN/v1_fallback ./build_ladybird.sh
Built production Ladybird V app: ~/code/vox2/Build/v/Ladybird.app
```
