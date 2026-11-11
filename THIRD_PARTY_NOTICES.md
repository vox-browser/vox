# Third-party notices

Vox includes translated and adapted third-party code and resources. Their
copyright holders retain their rights, and their individual copyright and
license notices remain applicable alongside Vox's [license](LICENSE).

## Ladybird and SerenityOS

Vox is based on a V translation of an older version of
[Ladybird](https://ladybird.org/), whose engine and libraries originated in
[SerenityOS](https://serenityos.org/). We acknowledge Andreas Kling and all
Ladybird and SerenityOS contributors for this foundation.

Ladybird-derived source files retain their original copyright and SPDX notices.
The upstream [Ladybird license](https://github.com/LadybirdBrowser/ladybird/blob/master/LICENSE)
is reproduced below. Source distributions must retain these notices; binary
distributions must reproduce them in their documentation or other accompanying
materials.

```text
BSD 2-Clause License

Copyright (c) 2018-present, the Ladybird developers.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

## Other bundled components

Additional notices already accompany the components in the repository:

- [uBlock Origin and ad-blocking dependencies](adblock/vendor/NOTICE.md),
  including uBlock Origin's [GPL-3.0-or-later license](adblock/vendor/ublock/LICENSE.txt),
  polyfill licenses and filter-list attributions.
- [ANGLE and Khronos declarations](webgl/ANGLE_LICENSE).
- [Chromium broken-image icons](layout/resources/chromium/README.md) and their
  [BSD license](layout/resources/chromium/LICENSE).
- [es-module-lexer](browserjs/vendor/es-module-lexer-1.7.0/LICENSE).
- [simdutf-derived fixtures](libjs/licenses/simdutf-MIT.txt).
- Test resources such as [jQuery](Tests/Browser/fixtures/jquery-2.1.1.LICENSE.txt),
  [Ahem](Tests/Browser/Brave/resources/Ahem-LICENSE.txt), and the
  [Noto Sans Arabic shaping subset](platform/testdata/NotoSansArabic-OFL.txt).

Vox's `GPL-2.0-or-later` grant allows choosing GPL version 3 or later when
distributing the combined browser with its uBlock Origin integration. That
integration includes GPL-3.0-or-later code and the Apache-2.0-licensed
fast-text-encoding polyfill. These cannot be combined under GPL version 2 only;
see the [GNU GPL compatibility guidance](https://www.gnu.org/licenses/gpl-faq.html#AllCompatibility).
Their original notices and source-distribution obligations still apply.
