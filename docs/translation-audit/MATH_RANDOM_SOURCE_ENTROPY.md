# Math random Source entropy

Recorded 2026-10-04 against Ladybird
`963d46a829f3e1b79f44dba9d02afb70654300fa`.

`MathObject.cpp:811–817` retains an AK `XorShift128PlusRNG` and returns its
`get()` result. `AK/Random.cpp` constructs that generator with two separate
`get_random<u64>()` calls, applying splitmix to each in order. `AK/Random.h`
fills each native-width object's bytes through `fill_with_random`; that
function uses the operating system CSPRNG and makes platform errors fatal.
The previous V caller used `rand.u64()`, V's default pseudorandom generator,
for those seeds. Its splitmix, xorshift and 53-bit floating projection already
followed Source and remain unchanged.

Feature `ce231a42` replaces only that seed dependency. The V initialization
stores the first splitmix result before taking the second draw. The thin
`libjs/math_random_entropy.h` ABI maps Source's platform families to the same
native APIs: `arc4random_buf`, the Linux `getrandom` loop with EINTR retry and
partial-read advancement, or the required Windows `ProcessPrng` entry point.
The Windows loader retains the required function using the corresponding
`AK/Windows.h` LoadLibrary/GetProcAddress checks. Fatal platform errors abort;
unsupported platforms fail compilation as in Source. No default-PRNG fallback
or replacement generator algorithm is introduced.

`tools/source_math_random_probe.py` extracts the unchanged Source constructor,
splitmix, advance, get and CSPRNG bodies and uses current real AK headers.
Test-only external entropy draws provide deterministic native-width values.
Both `-O0` and `-O2` produce the same 48 exact double-bit results across six
seed pairs. A separate native fixture compares actual Source CSPRNG calls
and the translated ABI's two draw sizes, order and object byte representation.
The tracked JSON fixture keeps decimal integers as strings to preserve all
64 bits independently of a JSON consumer's number representation. The linked
upstream AK dylib supplies assertion dependencies; this is not a build of the
complete current AK library.

The native entropy ABI probe exercises this macOS arm64 branch. Linux and
Windows branches are mapped to Source but have not been executed on those
platforms here. Source C++ static-initialization synchronization and the full
runtime/global intrinsic graph remain separate boundaries; this slice does
not establish multi-threaded VM or full LibJS parity. The browser continues
to execute JavaScriptCore.

New exact-output/native-constructor and existing Math files pass **2/2 with
default GC** and **2/2 under production compilation with GC disabled** in the
private `10-math-source-entropy` worktree. Logs are
`source-math-entropy-corrected-default.log` and
`source-math-entropy-prod-gc-none.log`. The initial new-fixture compile log
`source-math-entropy-default.log` is retained: it attempted direct test-file
global access and decoded a private record. The fixture now uses the actual
constructor and a public fixture record; production logic was not changed to
expose testing hooks. The final pinned native probe is
`source-math-random-entropy-final-probe.log`. Required whole-package GC-mode
and exact AST checks are recorded separately for their frozen revision.
