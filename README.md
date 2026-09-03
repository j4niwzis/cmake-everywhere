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

It also removes a failure that has nothing to do with installing. libpng
exports its targets, `png_static` links zlib, and zlib is in no export set of
libpng's -- so a build that added both failed at generate time over an
install neither of them was going to perform.

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
