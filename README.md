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

## What is here

zlib, libpng, ogg, vorbis, FLAC, opus, libsndfile, minimp3.

Eight is not a registry yet. It is enough to show the two shapes -- a library
with CMake and a library without -- and enough to prove the interesting case:
`find_package(SndFile)` alone brings four more.

## Trying it

```sh
test/build.sh                                  # system where possible
test/build.sh build/from-source -DCME_SYSTEM=NEVER
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
