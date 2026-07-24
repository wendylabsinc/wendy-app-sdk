# Third-Party Notices

The `wendy-app-sdk` source is licensed under the MIT License (see `LICENSE`).
It vendors and links third-party components under their own permissive licenses,
reproduced/attributed below. Distribute this file (or an equivalent notice) with
any binary or container that bundles these components — in particular the
embedded font, whose license requires its notice to travel with all copies.

---

## 1. Vendored source (included in this repository)

### stb_truetype — `Sources/CStbTrueType`
Single-file public-domain font rasterizer.
Copyright (c) 2017 Sean Barrett. Dual-licensed: **MIT License OR Public Domain
(Unlicense)** — see the license block at the bottom of `stb_truetype.h`. Used
here under the MIT alternative (see §4, MIT License).

### DRM/KMS uAPI headers — `Sources/WendyKMSDRM/vendor/drm/{drm.h,drm_mode.h}`
Linux Direct Rendering Manager userspace API headers. These specific headers are
**MIT-licensed** (the kernel's UAPI exception — they are *not* GPL), so vendoring
them imposes no copyleft obligation. SPDX: `MIT`. Copyrights:
- Copyright 1999 Precision Insight, Inc., Cedar Park, Texas.
- Copyright 2000 VA Linux Systems, Inc., Sunnyvale, California.
- Copyright (c) 2007 Dave Airlie `<airlied@linux.ie>`
- Copyright (c) 2007 Jakob Bornecrantz `<wallbraker@gmail.com>`
- Copyright (c) 2008 Red Hat Inc.
- Copyright (c) 2007-2008 Tungsten Graphics, Inc., Cedar Park, TX., USA
- Copyright (c) 2007-2008 Intel Corporation

(Full MIT text in §4. The original notices are retained at the top of each file.)

---

## 2. Bundled font

### WendySans — `Sources/WendyTextKit/Resources/WendySans.ttf` (also embedded into the binary via `Sources/CWendyFont`)
WendySans is **DejaVu Sans, version 2.37** (https://github.com/dejavu-fonts/dejavu-fonts),
which derives from the Bitstream Vera and Arev fonts. DejaVu's own changes are in
the public domain; the underlying fonts are licensed as below.

The font has been renamed to "WendySans" — note that, per the license, the name
contains neither "Bitstream" nor "Vera". The license permits embedding,
redistribution, modification and sale **as part of a larger package** (but the
font may not be sold on its own). The notice below must accompany all copies,
including binaries/containers with the font embedded.

```
Bitstream Vera Fonts Copyright

Copyright (c) 2003 by Bitstream, Inc. All Rights Reserved. Bitstream Vera is
a trademark of Bitstream, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of the fonts accompanying this license ("Fonts") and associated documentation
files (the "Font Software"), to reproduce and distribute the Font Software,
including without limitation the rights to use, copy, merge, publish,
distribute, and/or sell copies of the Font Software, and to permit persons to
whom the Font Software is furnished to do so, subject to the following
conditions:

The above copyright and trademark notices and this permission notice shall be
included in all copies of one or more of the Font Software typefaces.

The Font Software may be modified, altered, or added to, and in particular the
designs of glyphs or characters in the Fonts, and the Font Software may be
converted into other formats, provided that the above terms are met.

THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF THIRD PARTY RIGHTS. IN NO EVENT
SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
INCLUDING AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE FONT SOFTWARE OR THE AGREEMENT, TERMS, CONDITIONS OR OTHER
DEALINGS IN THE FONT SOFTWARE.

Except as contained in this notice, the names of Bitstream or the Bitstream
logo shall not be used in advertising or otherwise to promote the sale, use or
other dealings in this Font Software without prior written authorization from
Bitstream.

Arev Fonts Copyright

Copyright (c) 2006 by Tavmjong Bah. All Rights Reserved. (Same terms as above;
the name of Tavmjong Bah shall not be used to promote dealings in the Font
Software without prior written authorization.)
```

The complete upstream license is at `Sources/WendyTextKit/Resources/LICENSE-font.txt`.

---

## 3. Swift package dependencies (linked into binaries)

**MIT License** (§4):
- IkigaJSON / swift-json (Joannis Orlandos) — 2.5.3
- swift-cross-ui (stackotter) — 0.7.0
- swift-image-formats (stackotter) — 0.5.0

**Apache License 2.0** (© Apple Inc. and the SwiftNIO/gRPC/Swift project authors;
full text at https://www.apache.org/licenses/LICENSE-2.0 and in each package's
bundled `LICENSE`/`NOTICE`):
- grpc-swift, grpc-swift-nio-transport, grpc-swift-protobuf
- swift-protobuf
- swift-nio, swift-nio-extras, swift-nio-http2, swift-nio-ssl, swift-nio-transport-services
- swift-collections, swift-atomics, swift-algorithms, swift-async-algorithms, swift-numerics
- swift-crypto, swift-certificates, swift-asn1
- swift-http-types, swift-http-structured-headers
- swift-log, swift-service-lifecycle, swift-system
- swift-argument-parser, swift-container-plugin

**Native image codecs** (pulled in via swift-image-formats; linked where image
support is built):
- `jpeg` (tayloraswift/swift-jpeg) — **MPL-2.0** (file-level copyleft; no effect on
  this project's own MIT code). https://www.mozilla.org/MPL/2.0/
- `libpng` — **PNG Reference Library License v2** (permissive). © PNG authors.
- `libwebp` — **BSD-3-Clause** (§4). Copyright (c) 2010, Google Inc.
- `zlib` — **zlib License** (§4). Copyright (C) 1995-2024 Jean-loup Gailly and Mark Adler.

> The resolved dependency graph also contains platform packages that are **not**
> linked into the WendyOS (Linux/aarch64) binaries — e.g. AndroidKit, swift-winui,
> swift-java — listed here only for completeness. Each ships its own permissive
> (MIT/Apache-2.0) license in its checkout.

---

## 4. License texts

### MIT License
(Applies to stb_truetype, the vendored DRM uAPI headers, IkigaJSON,
swift-cross-ui, swift-image-formats, and other MIT-licensed components above.
Copyright is held by the respective authors named above.)

```
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

### BSD-3-Clause (libwebp)
```
Copyright (c) 2010, Google Inc. All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

  * Redistributions of source code must retain the above copyright notice, this
    list of conditions and the following disclaimer.
  * Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.
  * Neither the name of Google nor the names of its contributors may be used to
    endorse or promote products derived from this software without specific prior
    written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

### zlib License (zlib)
```
Copyright (C) 1995-2024 Jean-loup Gailly and Mark Adler

This software is provided 'as-is', without any express or implied warranty. In
no event will the authors be held liable for any damages arising from the use of
this software.

Permission is granted to anyone to use this software for any purpose, including
commercial applications, and to alter it and redistribute it freely, subject to
the following restrictions:

1. The origin of this software must not be misrepresented; you must not claim
   that you wrote the original software. If you use this software in a product,
   an acknowledgment in the product documentation would be appreciated but is not
   required.
2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.
```

The Apache-2.0, MPL-2.0 and PNG Reference Library License full texts are
available at the URLs above and in each dependency's bundled license file.
