# cmake-everywhere

One `find_package()` in your project, everything underneath it resolved:
from the system when it is there, built from a pinned source when it is not,
and given a CMake build by this registry when upstream has none.

```cmake
set(CMAKE_PROJECT_TOP_LEVEL_INCLUDES ${CMAKE_CURRENT_LIST_DIR}/cmake/get_cme.cmake)
project(app)

find_package(SndFile REQUIRED)
target_link_libraries(app PRIVATE SndFile::sndfile)
```

That is the whole consumer side. libsndfile looks for ogg, vorbis, FLAC and
opus itself; those four calls are answered here rather than in your
CMakeLists. Nothing about them appears in your project.

## Why this is possible at all

CMake 3.24 added [dependency providers][provider]. A provider installed
through `CMAKE_PROJECT_TOP_LEVEL_INCLUDES` is offered **every**
`find_package()` in the configuration first -- including the ones made deep
inside a third-party project you are building. That is the difference between
this and a list of `CPMAddPackage` calls: with CPM alone, freetype's own
`find_package(ZLIB)` does not know about the zlib CPM added, so the consumer
ends up spelling out every intermediate dependency and wiring the variables
by hand.

A provider may only be installed from a file named by that variable, which is
why the consumer sets a variable rather than calling something. Inside a
provider, `find_package(... BYPASS_PROVIDER)` reaches the real
implementation, which is how the system copy is looked for without the search
coming straight back.

[provider]: https://cmake.org/cmake/help/latest/command/cmake_language.html#dependency-providers

## System first, source second

`CME_SYSTEM` decides:

| | |
| --- | --- |
| `AUTO` (default) | use the system copy when it is there and new enough, build otherwise |
| `ALWAYS` | never build; a missing package is an error |
| `NEVER` | build everything, ignore whatever is installed |

Per package: `-DCME_SYSTEM_ZLIB=OFF` builds that one and leaves the rest
alone. Every decision is written to `cme-lock.txt` in the build directory --
which package came from where, and at what version.

## Versions

`find_package(FLAC 1.4)` means 1.4 or newer, and it is treated that way:

* the system copy is accepted only if it satisfies the request -- the version
  goes into the `find_package` call and into the pkg-config query;
* the port is built only if what it pins satisfies the request. A port
  pinning 1.3.5 while something asks for 1.4 is an error naming both, not a
  build of 1.3.5 that fails much later as a missing symbol;
* a package already resolved cannot be resolved again, so a later caller
  asking for more than what is already in the build is told so;
* `EXACT` is honoured on all three paths.

A newer version wins where there is a choice: the system copy is tried first,
so an installed 1.5 is used rather than the 1.4 the port pins.

### Requirements are read before anything is built

A dependency can carry a floor, and that is data in the registry rather than
something only discovered by running a third-party CMakeLists:

```cmake
DEPENDS "ogg>=1.3" vorbis flac opus
```

When a package is asked for, the whole graph under it is walked first and
every floor in it raised, before a single `add_subdirectory` has run. So a
version needed by something deep in the graph is known while the shallow end
is still being decided, and a port whose pin is lower is built at the version
that satisfies everyone -- provided it says how a version becomes a tag.
Nothing is built twice and nothing ends up older than something else needed.

### A library under a name of its own

Skia includes itself as `"include/core/SkCanvas.h"`. That is a path with
nothing in it to say whose include directory it is, and a consumer that
writes it has not said which library it meant. So the port offers Skia's
include directory a second time under a name:

```cpp
#include <skia/core/SkCanvas.h>
```

Skia is unchanged and still compiles against its own spelling. Nothing is
copied and nothing is rewritten -- the name is a link, and the root of the
checkout stays on the interface too, so what lives outside `include/`, such
as `modules/skottie/include`, is still reachable.

### Versions as archives

A port can list its versions as archives with a digest of each, instead of
being cloned:

```cmake
cme_port_version(skia 153
  URL "https://codeload.github.com/google/skia/tar.gz/9d07e5ba..."
  SHA512 9c1682...)
```

Skia is fetched that way. Its history is several gigabytes and none of it is
read; an archive of one commit is 65 MiB and a fixed number of bytes that can
be checked. Ten milestones are listed, `cme_version(skia 148)` takes another,
and a number that is not listed is refused rather than guessed at -- there is
no digest for it.

Each line names a commit rather than the branch it was cut from. A branch
moves, and a digest of what it pointed at yesterday is a digest of nothing.

### A GN project

```cmake
GN_TARGETS "//:skia=Skia::skia"
GN_ARGS
  "cc=\"@CC@\"" "cxx=\"@CXX@\""
  "target_os=\"@TARGET_OS@\"" "target_cpu=\"@TARGET_CPU@\""
  "skia_use_vulkan=false"
  "extra_cflags=[@DEP_INCLUDES@]"
GN_CONFIRM "skia_use_vulkan=false"
```

GN is run once, at configure time, and only to describe the build:
`gn gen --ide=json` reports every source, define, include directory and
per-file compiler flag of every target, with the project's own hundred build
arguments already evaluated by the thing that understands them. That
description becomes ordinary CMake targets, compiled by your generator
alongside everything else. GN is not part of the build; it is part of the
configure.

A library name is not left bare. A project told to use the system's libpng
ends up asking the linker for `-lpng`, and the linker answers with whatever
it finds -- on a machine that has libpng installed, that is the system's
copy, with headers from this build and a library from somewhere else, and it
is silent about it. So a port says what it answers to:

```cmake
LINK_NAMES "png=PNG::PNG" "png16=PNG::PNG"
```

and a bare name that matches becomes that target. A target is an archive with
a path, and a path cannot be mistaken for something else.

`cmake/gn.cmake` knows nothing about any particular project. A port supplies
its project's own vocabulary -- one calls the compiler `cc`, the next calls
it `clang_path` -- and asks for the values it cannot know by placeholder:
`@CC@`, `@CXX@`, `@AR@`, `@SYSROOT@`, `@TARGET_OS@`, `@TARGET_CPU@`, and
`@DEP_INCLUDES@` / `@DEP_LIBDIRS@` for the libraries the registry built for
it. `GN_CONFIRM` reads back what GN actually settled on, because an argument
that is misspelled or overridden still reads correctly in the command line
that set it.

The alternative -- reading a project's source lists and re-stating its
conditions in CMake by hand -- is the same work again, done worse, once per
release. This way a new file arrives on its own and a new condition is
evaluated by GN.

What is fragile: `action()` steps become `add_custom_command`, and GN rebases
their script arguments against its build directory, so they are run from
there. `gn` has to be on `PATH` at configure time, or named with `-DCME_GN=`.

### Saying no, and saying it once

Everything above is additive: something asks, and the library gets it. A
project also needs to be able to refuse, and to state a policy rather than
repeat a decision:

```cmake
cme_features(skia gl -vulkan)          # this library: yes to one, never the other
set(CME_DEFAULT_FEATURES png -vulkan)  # every library that has a feature by that name
cme_profile(self-contained)            # a named file of these, beside the registry
```

A refusal is not a quiet override. If something in the graph genuinely needs
what was refused, the build stops and says so, naming both sides: one of the
two has to give.

A feature can also be on unless refused, which is how a port matches an
upstream default it agrees with -- `flac`'s Ogg support is on because
libFLAC's own build turns it on.

### Rules about a whole library

```cmake
cme_port_rule(skia AT_MOST_ONE_OF fontconfig fontmgr-directory)
cme_port_rule(skia AT_LEAST_ONE_OF gl vulkan)
cme_port_rule(skia EXACTLY_ONE_OF a b c)
cme_port_rule(skia WITHOUT zlib DEPENDS miniz)
```

The first can only be broken by turning something on, so it is checked while
the graph is walked and the error names what asked. The others can only be
broken by leaving something out, which is not known until nothing more can
ask, so they are checked when the library is about to be built. `WITHOUT` is
a dependency that exists because a feature is *off* -- the substitute for
something that was not enabled.

### Licences

A port says what its library is under, and a project can say what it will
accept:

```cmake
set(CME_ACCEPT_LICENSES "MIT;BSD-3-Clause;Zlib;Apache-2.0")
```

A library outside that list stops the build, naming what pulled it in --
which matters here, because a feature can bring a dependency the project
never mentioned. A port that does not say what it is under is refused too:
not saying is not the same as being permissive. With no list set, there is no
opinion and nothing is checked.

### Reading what was decided

```cmake
cme_report()
```

at the end of the top-level `CMakeLists.txt` prints every library that was
reached: where it came from, at what version, who asked for it, and each of
its features with whether it is on, who wanted it, and what it is for. The
same text is written beside the lock file.

### Whether a system copy has the features

A copy somebody else built does not record what it was built with anywhere a
build system can read. What can be read is whether the result has the thing
in it, and a feature says what to look for:

```cmake
cme_port_feature(flac ogg
  DEPENDS "ogg>=1.3"
  OPTIONS "WITH_OGG ON"
  SYSTEM_SYMBOLS "FLAC__stream_encoder_init_ogg_stream:FLAC/stream_encoder.h")
```

libFLAC compiles its Ogg entry points only when it was built with Ogg, so
looking for one answers the question. A system copy that fails the check is
not an error -- it is simply not the copy this build can use, and the port is
built instead, with a line saying which check failed and why that means what
it means.

### A requirement the registry could not have known

What that leaves is a request the consuming project makes itself, after the
package is already part of the configuration: `find_package(Ogg)` and then,
later, `find_package(Ogg 1.4)`. By then ogg is built and CMake has one
configure pass, so it cannot be un-built.

It is written down and the run stops:

```
Ogg is here as 1.3.5 and something now asks for 1.4, which is later than
anything the registry was told about. Written down -- run cmake again and it
will be resolved at 1.4 from the start.
```

The floor goes into the cache and into `cme-lock.txt`, so the next configure
resolves it correctly from the first call. Once per requirement, not once per
call.

To build a version other than the one the port pins:

```cmake
cme_version(flac 1.5.0)
```

The port says how a version becomes a tag, because one project tags `v1.3.5`
and the next tags `1.4.3`:

```cmake
GIT_TAG_TEMPLATE "v@VERSION@"
```

A port without one refuses the request instead of checking out something that
is not what was asked for.

## Features

A library is often not one thing. Skia with Vulkan and Skia without are the
same library built differently, and something deep in a dependency graph may
need the one with it while the project that started the build never mentioned
Vulkan at all.

So a port declares what its library can optionally be, in names that say what
they do rather than repeating the project's own argument spellings:

```cmake
cme_port_feature(skia vulkan
  SUMMARY "the Vulkan backend, in addition to GL"
  GN_ARGS "skia_use_vulkan=true")
```

A consumer asks for them either way round:

```cmake
find_package(Skia COMPONENTS vulkan)
cme_features(skia vulkan pdf)
```

`COMPONENTS` is shared ground, though: it is also how a third-party project
asks for parts of something in its own vocabulary -- libsndfile asks Vorbis
for `Enc` and `File`, which are nobody's features. So a component that the
port declares as a feature is read as one, and a component it does not is
answered as present, because a port that supplies a library supplies all of
it. `cme_features` is the unambiguous spelling: it is only ever about
features, and a name that is not one is refused.

and a port asks for them from another port in its dependency, which is where
this earns its keep:

```cmake
DEPENDS "skia[vulkan]>=2" "zlib"
```

Features compose by union, the way versions compose by maximum: if anything
in the build needs Skia with Vulkan, the one Skia in the build has Vulkan.
They are gathered in the same walk of the graph, before anything is built, so
a feature needed at the bottom is known while the top is still being decided.
A feature can bring dependencies of its own, and those are walked too.

A feature that does not exist is refused, with the list of the ones that do.
A feature asked for after the library is already built is written down and
the run stops, exactly as a version is -- the next configure builds it with
the feature from the start.

This is not the old grouping. `graphics` was a group of libraries and it was
wrong: a renderer can be built out of others. `vulkan` is one capability of
one library, and the library is the only thing that knows what turning it on
means.

### What a feature can say

```cmake
cme_port_feature(skia egl
  SUMMARY  "Ganesh on GL, reaching it through EGL"
  IMPLIES  gl                    # other features of this library
  CONFLICTS metal                # other features of this library
  DEPENDS  "libpng" "other[featured]>=2"   # libraries, with their features
  EXCLUDES "otherlib[bundled-zlib]"        # what cannot be in the build with it
  SYSTEM_HEADERS "EGL/egl.h"     # how to tell whether a copy somebody else
  SYSTEM_SYMBOLS "eglInitialize:EGL/egl.h" #   built has this feature in it
  GN_ARGS  "skia_use_egl=true"
  GN_CONFIRM "skia_use_egl=true")
```

`IMPLIES` is applied transitively: `fontconfig` implies `freetype`, which
implies `zlib`, so asking for the first brings all three and the zlib port
with them. `CONFLICTS` is checked as the graph is walked rather than at the
end, and the error names the two things that asked:

```
skia cannot have both vulkan and metal.
  vulkan was asked for by the project
  metal was asked for by fancylib[gpu]
```

`EXCLUDES` is the same across libraries rather than within one, and it is
checked from both ends, because the two sides can arrive in either order.

### A feature can need a library

Which is where this stops being a list of switches. A feature names what it
needs, and that dependency exists only when the feature is on:

```cmake
cme_port_feature(skia png
  DEPENDS libpng
  GN_ARGS "skia_use_libpng_decode=true" "skia_use_system_libpng=true")
```

`find_package(Skia)` builds no libpng. `find_package(Skia COMPONENTS png)`
builds libpng, and zlib under it, because that is what libpng needs. The
graph is walked with the features in hand, so a dependency that only exists
because of a feature is found at the same time as everything else, before
anything is built.

### Skia, as it is set up here

Nothing by default: the port with no features is Skia as a CPU rasteriser --
no GPU backend, no codecs, no fonts, no compression, no PDF, no SVG. A
consumer asks for what it uses:

```cmake
find_package(Skia COMPONENTS gl png freetype)
```

and nothing else is built. `gl`, `egl`, `vulkan`, `graphite`, `png`, `jpeg`,
`webp`, `zlib`, `freetype`, `fontconfig`, `fontmgr-directory`, `pdf`, `svg`
and `skottie` are the features; each says what it is for in a sentence.

Nothing bundled, ever. Skia carries copies of zlib, libpng, libjpeg-turbo,
libwebp, freetype and expat in `third_party/externals`, and every feature
that needs one turns on the matching `skia_use_system_*` and names the port
that supplies it. Those settings are read back out of GN afterwards rather
than assumed. And since this build never runs Skia's dependency sync,
`third_party/externals` is empty -- so a bundled path would not quietly
happen, it would fail to find its sources.

## Options for a library being built

```cmake
cme_options(flac "WITH_OGG OFF")
cme_options(libsndfile "ENABLE_MPEG ON")
```

Set in the same file that installs the provider, before the `find_package`
that first asks for the library. They are appended after the port's own
options, so they win. `-DCME_OPTIONS_flac="WITH_OGG OFF"` does the same from
the command line.

They apply only to a library that is being compiled. A copy taken from the
system is taken as it was built, and nothing here can change that -- which is
worth knowing rather than discovering.

## Why it built something you have installed

Most distributions ship a `.pc` file and no CMake config, and CMake has no
`FindOgg`, `FindVorbis`, `FindFLAC` or `FindSndFile` of its own. So a plain
`find_package(Ogg)` fails on a machine that has libogg installed, and without
help the port would be built for nothing.

A port therefore also names the pkg-config modules it can be satisfied by,
and the target each one should answer to:

```cmake
SYSTEM_PKGCONFIG
  "vorbis:Vorbis::vorbis"
  "vorbisenc:Vorbis::vorbisenc"
  "vorbisfile:Vorbis::vorbisfile"
```

The order is: CMake config or Find module, then pkg-config, then build it.
`cme-lock.txt` in the build directory says which of the three answered for
each package, so a build that took longer than expected can be read rather
than guessed at.

## A port

Adding a library is one directory in `registry/`. Everything except the
adapter is data:

```cmake
cme_declare_port(
  NAME libpng
  PROVIDES PNG               # the name projects write in find_package()
  VERSION 1.6.44
  GITHUB_REPOSITORY pnggroup/libpng
  GIT_TAG v1.6.44
  DEPENDS zlib
  OPTIONS "PNG_SHARED OFF" "PNG_TESTS OFF" "PNG_TOOLS OFF"
)

function(cme_adapt_libpng source binary)
  cme_alias(PNG::PNG png_static)
  cme_export_variable(PNG PNG_LIBRARIES PNG::PNG)
  cme_export_variable(PNG PNG_INCLUDE_DIRS "${source};${binary}")
  ...
endfunction()
```

The adapter is the part that cannot be generated, and it is the part that
makes the one call work. Upstream calls its target `png_static`; consumers
write `PNG::PNG`, and the older ones read `PNG_LIBRARIES` and
`PNG_PNG_INCLUDE_DIR` and nothing else. Exported variables are replayed into
the scope of every later `find_package` of that package, not just the first,
because a Find module sets its variables where it is called from and the
third project to ask needs them as much as the first.

## Old projects

CMake 4 refuses to configure a project whose `cmake_minimum_required` asks
for less than 3.5, and released libraries ask for less than that -- libogg
1.3.5 asks for 3.0. These are trees the registry did not write and cannot
correct, so ports are configured with `CMAKE_POLICY_VERSION_MINIMUM` set to
3.5. A port that needs another floor says `POLICY_MINIMUM` and gets it. The
floor applies to ports only: your own project is configured exactly as you
wrote it.

## Nothing of a dependency is installed

Ports are added with `EXCLUDE_FROM_ALL`, and the CMake documentation is
explicit about what that means: "Any install rules defined in the
subdirectory or below will be ignored when installing the parent directory."
A library this registry built is part of your build, not part of what you
ship: `make install` on your project installs your project.

That is not quite enough, though, and the difference is worth knowing.
CMake still *checks* an `install(EXPORT)` while generating, even one it will
never run -- so libpng, which exports its targets and links zlib, fails there
because zlib is in no export set of libpng's. The rules would never have run;
the check does not care. So ports are additionally given `SKIP_INSTALL_ALL`
and its three companions, which zlib introduced and libpng and freetype
followed. A project that has never heard of them ignores them.

Their headers are added with `SYSTEM` as well. Their warnings are not yours.

## Nothing is built at configure time

The `*-populate` steps in the log are FetchContent downloading, and they say
so themselves: no configure step, no build step, no install step. Every
library is added with `add_subdirectory` and compiled by ninja in the main
build, in parallel with everything else, with your flags and your generator.

A port pinned to a branch instead of a commit makes those download steps run
on every configure, because a moving ref has to be checked each time. That is
what "Fetching latest from the remote origin" was, and it is why ports name
commits or tags.

## A library with no CMake

`OVERLAY` says the upstream has no build system of its own. The sources are
downloaded and nothing is configured from them; the overlay directory in this
registry is a normal CMake project that reads them through
`CME_UPSTREAM_SOURCE_DIR` and builds what it likes. Nothing is written into
the fetched tree, so the checkout stays exactly as it was downloaded and the
overlay can be read as ordinary CMake.

`registry/minimp3` is the worked example: a library that is one header with
its implementation behind a macro, turned into a static library by a
three-line translation unit that lives in the overlay.

### How good a port is

Not every overlay is a full CMake build, and the ones that are not should say
so. Three shapes, best first:

**A CMake build.** The library is built by CMake, as targets in your graph,
with your flags, your toolchain and your generator, in parallel with the rest
of your project. This is the ideal and the only shape that composes properly.

**A CMake build generated from what upstream already declares.** A large
project usually keeps its source lists in machine-readable form -- Skia keeps
its in `gn/*.gni` -- and an overlay for one of those should read them at
configure time rather than copy them. Copied lists rot at the next release;
generated ones pick up new files on their own, and only new conditionals need
attention. The conditionals are the real work: a hundred build flags, the
per-file compiler flags a project like Skia sets for its SIMD translation
units, and whatever it generates during its own build. That work is done once
per configuration you promise to support -- which is why an overlay of this
kind should promise few.

**A wrapper around upstream's own build.** Its build system is run as a build
step and the result imported as a target. It is correct, and it is outside
your graph: it needs its own tools installed, it does not inherit your flags
or your toolchain, and it cannot be scheduled with the rest of your build as
one thing. Acceptable as a stage on the way, not as a destination -- and a
port that is one should say it in its first line, so nobody is surprised.

The same ordering applies to what upstream should do, which is the point of
the registry: a library that ships its own CMake needs no overlay at all.

## The point is for this to shrink

A library that ships CMake, resolves its own dependencies instead of calling
bare `find_package` and hoping, and exports namespaced targets needs nothing
from this registry. You write `CPMAddPackage` or `find_package` and it works,
in your project and in every project that depends on yours. That combination
-- CMake plus CPM.cmake plus exported targets -- is what this argues for, and
it is about thirty lines of work for a library to adopt.

So every port here is a note about exactly one of three things being absent
upstream:

| | what is missing | what the registry does |
| --- | --- | --- |
| 1 | no CMake at all | an overlay: a CMake project written here that builds the downloaded sources |
| 2 | CMake, but dependencies are looked for with bare `find_package` | the provider answers those calls |
| 3 | CMake, but no namespaced targets and no exported config | an adapter gives the result the names its consumers use |

Of the eight ports here, `ogg` and `opus` are already close to deletable:
they export `Ogg::ogg` and `Opus::opus` properly, and all that is left is
legacy variables that older revisions of *other* libraries read. `minimp3` is
case 1. The rest are case 2, case 3, or both.

A port deleted because upstream now ships CMake and declares its own
dependencies is this repository working, not this repository losing. The
success condition is an empty `registry/`.

Ports themselves have the same ladder: an overlay that wraps another build
system is worth less than one that builds the library with CMake, and a
generated CMake build is how a large project gets there without the lists
rotting. See [how good a port is](#how-good-a-port-is).

## What is here

zlib, libpng, libjpeg-turbo, libwebp, freetype, ogg, vorbis, FLAC,
opus, libsndfile, minimp3, Skia.

That is not a registry yet. It is enough to show the three shapes -- a
library with CMake, a library without one, and a library with a different
build system entirely -- and enough to prove the interesting case:
`find_package(SndFile)` alone brings four more.

## Checking it

```sh
test/run.sh               # everything that needs no more than a compiler
test/run.sh --with-skia   # and the one that needs gn and a long wait
```

Two kinds of check. The refusals configure a project against a registry of
libraries that do not exist -- every one of those errors is decided while the
graph is being walked, so nothing is ever fetched -- and each asserts not
only that the build stopped but *why*: a refusal for the wrong reason fails
the check, because the message is the feature.

The builds are real. `test/features` asks freetype for colour bitmap glyphs,
which brings libpng and zlib under it, and asks flac for nothing and gets its
Ogg support anyway because the port has that on unless refused. Each is run
twice, once taking what the system has and once with `CME_SYSTEM=NEVER`.

`test/skia` is separate because it needs `gn` and takes a while. With no
components it is Skia as a CPU rasteriser, which is the cheapest way to find
out whether the GN description was read correctly. Then:

```sh
cmake -S test/skia -B build/skia -G Ninja \
  -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=$PWD/cmake-everywhere.cmake \
  -DCME_FEATURES_skia="gl;png;freetype"
```

## Licence

MIT. This is build glue that is meant to be copied into other people's
projects, so it is licensed the way build glue is: the same as CPM.cmake,
compatible with everything including GPLv2.

No third-party source is redistributed here. A port is where a library comes
from, how to build it and what the result has to look like; the library
itself is downloaded at configure time and stays under its own licence. The
overlays -- the CMake written here for libraries that have none -- are part
of this repository and are MIT with the rest of it.
