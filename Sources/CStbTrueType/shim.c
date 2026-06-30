// Suppress stb's internal assert() so malformed/corrupt font data returns
// error codes / empty results instead of abort()-ing the process. We load a
// bundled, trusted font; callers must treat rasterize output defensively.
#define STBTT_assert(x) ((void)(x))
#define STB_TRUETYPE_IMPLEMENTATION
#include "stb_truetype.h"
