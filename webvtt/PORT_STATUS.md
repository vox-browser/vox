# WebVTT module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/WebVTT`

Audited: 2026-08-17

The current upstream inventory is 2 `.cpp` files / 326 LOC, 2 `.h` files /
184 LOC, and 2 `.idl` files / 42 LOC. The translated package has 2
implementation `.v` files / 445 LOC and 2 test `.v` files / 221 LOC (15 test
functions).
Documentation is excluded from both V LOC totals.

## Implementation-unit mapping

| Upstream `.cpp` | LOC | V implementation |
| --- | ---: | --- |
| `VTTCue.cpp` | 206 | `vtt_cue.v` |
| `VTTRegion.cpp` | 120 | `vtt_region.v` |
| **Total** | **326** | **2/2 mapped** |

Both adjacent headers and both WebIDL definitions are represented. The cue
surface includes inherited text-track cue state, construction, region identity,
all direction/alignment/line/position/size/text attributes, and the computed
line, position, and position-alignment algorithms. The region surface includes
all defaults, attributes, enum state, and range-checked setters. Upstream marks
`getCueAsHTML()` `[FIXME]`, so it is not a generated observable API at this
revision.

## Completion fixes

- Computed auto line now distinguishes a detached cue from a cue on a media
  element and counts preceding showing tracks through a typed integration
  value.
- Automatic start/end position alignment now follows the first strong
  left-to-right or right-to-left cue-text character.
- Weak and neutral bidi characters, including Arabic-Indic digits, no longer
  incorrectly establish a right-to-left cue-text base direction.
- Tests cover constructor errors/defaults, inherited cue state, every cue and
  region setter, explicit and automatic computation branches, invalid ranges,
  detached/media track positioning, object identity, bidirectional text, and
  unrestricted-double NaN behavior.

## Boundaries

LibJS/WebIDL realms, prototypes, garbage collection, DOMException classes, and
HTML media-element ownership remain runtime services. The number of showing
tracks preceding the cue is injected as typed state because HTML owns the media
track list. Full Unicode bidi-property lookup is a platform Unicode-data
service; the deterministic V fallback covers the strong Latin, Greek,
Cyrillic, Hebrew, and Arabic ranges used by the WebVTT base-direction step.

## Verification

```text
$ /Users/alex/code/v/v test webvtt
Summary for all V _test.v files: 2 passed, 2 total.

$ /Users/alex/code/v/v fmt -verify webvtt
(no output; exit status 0)

$ git diff --check -- webvtt
(no output; exit status 0)
```
