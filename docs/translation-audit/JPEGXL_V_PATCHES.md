# JPEG XL V patch dictionaries, blending and row application

Three separately committed slices translate patch dictionaries and ordered row
lookup, color/extra-channel blending, and clipped row application. They add
2,216 frozen source records: **287,235 records and 97 test files** total.
Cadence is **3/10** after the completed 94-file checkpoint; no full 97-file run
is claimed. Complete encoded frames with patches still require reference-frame
ownership and pipeline integration. Production and its native developer test
continue to use Rust.

## Independent reference

Temporary callers link the cached `jxl` 0.7.0 rlib directly; no Cargo refresh or
new library build is claimed. The archive SHA-256 is
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`,
and the cached rlib is
`06df072014bab7d540f1e8d29d7f78f24cae957d3e8619bd25a81b0d5bc66fe8`.
Six relevant cached files match the archive byte for byte:

| Source | SHA-256 |
| --- | --- |
| `features/patches.rs` | `04d0542c9825012d8397a6fddbc90c04687d195e7ae4ee32290effd52f2a7612` |
| `features/blending.rs` | `03efc4a1cddbf543309469b4b69f5aad4b6d94809a272578f67a30ce1df12547` |
| `image/typed.rs` | `50f5f2896c13d641bda1f8ba9fe22a24abc872075370a0afc2eb18ed5be622a6` |
| `frame/mod.rs` | `f84f7e643436f790166aa66bfd5f86226d3238c52ba5f643a9d3f2cf101f8d05` |
| `headers/extra_channels.rs` | `78baa0e732a40d8e1d3f0ad6a97ef3319351c620bd367f4b4c70ff96ea257ba9` |
| `entropy_coding/decode.rs` | `ff3696293c449ba15074ed0c815ef140d4cc6e85ee7bc0b3c2b1034b943d0b6b` |

The dictionary caller invokes original `PatchesDictionary::read` and
`set_patches_for_row`. Independently authored prefix packets use constant
symbols in the ten contexts. Accepted records compare consumed bits, positions,
reference rectangles, every blend field and ordered row IDs. The private
fields come from the original Debug output, normalized into documented integer
lists and frozen by SHA-256; tree representation is intentionally independent.
Errors normalize to `err`, without error-text/cursor parity claims.

The 678 records include 514 accepted cases, every blend mode, multiple reference
rectangles and placements, signed deltas, overlaps, 1,408 reference rectangles,
5,632 positions, all byte prefixes of four headers, invalid references/bounds,
post-transform references, alpha indices and allocation limits. The source's
u8 narrowing before blend-mode validation is preserved. The parser retains the
source's lack of symbol-reader finalization at this point; this is not a claim
of complete section validation. Dictionary-level ANS/LZ77 streams are not newly
exercised; the existing entropy corpus covers their separate primitives.

The blending caller invokes original public `perform_blending`: 1,024 records
compare **32,640 output float words** exactly, including all eight color modes,
mixed extra-channel modes, zero to three extras, associated/unassociated alpha,
non-alpha extras, clamping, old-alpha dependencies, negative and above-unit
values, and widths 1/3/4/5/7/8/9/17. Arithmetic steps remain separate to preserve
the source's unfused operations. This measures the cached AArch64 reference;
native scalar/AVX execution is not claimed.

The application caller invokes original `add_one_row` with deterministic stored
planes. All 514 accepted dictionaries compare **3,121,152 output float words**
by SHA-256 over explicit little-endian words. Both original and V callers also
require bit-exact equality between full rows and irregular 1–11-sample chunks,
covering clipping at both ends, ordered overlaps and selected alpha semantics.
These records count whole applications once, rather than counting each float.

| Frozen fixture | SHA-256 |
| --- | --- |
| `patch-dictionary.tsv` | `13c6e2c2d27d38ea141d0251d5c587514cff26eb055da38f42e6b077976b0ecd` |
| `patch-blending.tsv` | `930e6481f83401cf811f3a43a8ae3c2302d3f4ee0a64fbd09bc42aa037f744f5` |
| `patch-application.tsv` | `a8bef11b0f815029c2cb0d67fd6b8061479dd4327ecbe0003273ab96dc7d3854` |

| Temporary caller | Source SHA-256 | Executable SHA-256 |
| --- | --- | --- |
| Dictionary | `cb9bed298277704b86a456715a3eff4a42987b198a65230b5e02c3816c381245` | `3339f87413bc173ca1767a31c1b65f1db96bf2e6dbd31e87526db55f3343bffc` |
| Blending | `466e722c4d7ec451afeb6374ac79dd9e882a0d36328bc9ae8f6484918320a28c` | `78a7ece4f8bfd90b82dbdd580a3ba4796c8717bbd848ac8ff629c87cbe0693d5` |
| Application | `b3eccd18521930378bac2172d0120245b73258c8490067e549365095b76148b9` | `79b06c3d9028449a1469490f5871cefc84c8d52e07b7efbcd65dd6192091e5dc` |

The input author and normalization helper hashes are respectively
`bdcacef4e9e8e4c7ab796edd83b011487926ec98f8694f1ca263415544b9aa4c`
and `0ebe879bd6ea37b432bd48726d25aee84aa34e9647f539f14a7eb0529872f532`.
Selected native inputs and change times remain unchanged. Actual reference
guards/callers exit zero: dictionary 2,899,968 peak RSS bytes / 0.254 seconds;
blending 32,768 / 0.389; application 3,620,864 / 3.669. These sampled short-run
RSS values are observations, not total allocation estimates. One preliminary
blending caller failed compilation by using a nonexistent BitDepth constructor;
it was corrected before reference generation and receives no execution credit.

## V checks and limits

Final focused checks execute all three new test files with unavailable Rust
compiler paths, `VJOBS=1`, no compatibility fallback, separate 3 GiB guards and
600-second timeouts. The command is
`v -memory-limit 10G -b c -cc clang [FLAGS] test
jpegxl/patch_dictionary_test.v jpegxl/patch_blending_test.v
jpegxl/patch_rows_test.v`; flags are empty, `-gc none`, or `-prod`.

| Mode | Passed | Peak RSS, bytes | Guard seconds |
| --- | ---: | ---: | ---: |
| Default | 3/3 | 290,045,952 | 12.188 |
| No GC | 3/3 | 431,144,960 | 11.914 |
| Optimized | 3/3 | 381,943,808 | 18.947 |

Actual tests and guards exit zero. All **710 selected input hashes/change
times** remain unchanged, manifest SHA-256
`db0bcac12cc8afa52d8f2d8c12ef05fde940d83e8e0df94215d8a98ae1d6aeb2`.
Compiler: V 0.5.2 a5bda29, SHA-256
`53ae5fd6323569d6e2915db8305b3db5603b700f4e2f0f1cb8968772acd041b7`.
Host: 18 CPUs, loads 21.605/38.018/64.753 at 15:48:41 UTC, 2026-11-09.
These are correctness observations, not browser or rendering benchmarks.

The V tree avoids the source's per-row counting allocation and returns sorted
active IDs. APIs check dimensions, channel shapes, references and row slices.
Additional bounds are 256 extras, 1,048,576 reference rectangles/positions,
4,194,304 blend records and the existing budget of 67,108,864 samples. Blending
accepts finite inputs and disjoint foreground/destination storage. Allocation,
panic/error behavior and the source's entire limit surface are not parity
claims. Shape errors are checked before applying any selected reference span.

Complete patch-frame decoding, reference saving/composition, spline rendering,
wider extra-channel/LF combinations and production/tool replacement remain.
The shared completed bundle still has executable SHA-256
`db8acd8538ffa9db2ed78617e018362d1b96c0150e1d0e6784b6f0bac2391337`
(receipt `20261109-112648-d0d016af`); it cannot validate this unconnected code.
Managed commit hooks request coalesced production rebuilds. No duplicate manual
build or browser launch is used as evidence for these V module checks.
