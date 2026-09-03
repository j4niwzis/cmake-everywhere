# cmake-everywhere

One `find_package()` in your project, and everything underneath it resolved:
from the system when it is there, built from a pinned source when it is not,
and given a CMake build when upstream has none.

```cmake
set(CMAKE_PROJECT_TOP_LEVEL_INCLUDES ${CMAKE_CURRENT_LIST_DIR}/cmake/get_cme.cmake)
project(app)

find_package(SndFile REQUIRED)
target_link_libraries(app PRIVATE SndFile::sndfile)
```

That is the whole consumer side. libsndfile looks for ogg, vorbis, FLAC and
opus itself; those four calls are answered here rather than in your
CMakeLists. Nothing about them appears in your project.

## A library nobody has ported

The reason to use CPM is not that it is CMake and convenient. It is that
nobody has to agree: a git URL and a tag are enough, the repository already
exists, and a project can depend on it this afternoon. An index that has to
accept a library first turns that into a queue.

So the registry in this repository is a default, not a gate, and the ordinary
case is a port written where it is used.

### What a consumer has to say, which is two things

A name, and where it is:

```cmake
cme_declare_port(NAME hello PROVIDES Hello
                 GIT_REPOSITORY https://example.invalid/hello.git
                 GIT_TAG v1.4.0)

find_package(Hello REQUIRED)
```

That is enough for the whole sequence. The name is looked for in the system
first; if it is not there, or not good enough, the URL is fetched, and the
port is then taken from the library itself -- its version, its licence, its
features, what it needs. Only if the library says nothing about itself does
the consumer write a full port, and it writes one here, in its own
CMakeLists, for as long as that library has not adopted anything.

What the consumer said stands: it chose the library, so it decides which one
and where from. Everything it did not say, the library says.

### What a library needs is the library's to say

A port written where it is used would stop being an answer at the second
library: if `hello` needs two libraries nobody has ported either, every
project that uses `hello` would have to declare those too, and their names
would appear in CMakeLists files that have nothing to do with them.

They do not have to. A library says what it needs, and whoever fetches it
reads that after the fetch and before the tree is configured -- which is
before the library's own `find_package` calls happen:

* **a library that uses this says it in its own CMakeLists.** Its
  `cme_declare_port` calls run when its directory is added, which is exactly
  when they are needed. There is no extra file, no convention to adopt, and
  nothing to keep in sync: using this *is* the declaration.
* **a library that has never heard of this** can carry a `cme-port.cmake` or
  `cme-ports.cmake` (or the same under `.cme/`), which is those calls and
  nothing else.
* **a library you do not control** can have one attached to it by whoever
  declares it: `PORTS_FROM ports/hello-deps.cmake`, a path of yours, because
  it is your file.

Fetching and configuring are two steps for this reason. CPM is asked for the
tree and nothing else; the library's own port is read; and then what would
have been decided against a description that did not exist yet -- rules,
licence, version, dependencies, options -- is decided with it in hand, before
the tree is added.

### What a library knows about itself, and what it does not

```cmake
project(hello VERSION 1.4.0 LANGUAGES CXX)

cme_declare_port(NAME hello PROVIDES Hello LICENSE MIT)
```

That is a whole self-description. The version comes from `project()`. What it
needs is learned while it is built and written into its exported port, so
nobody keeps a list by hand and nobody keeps a wrong one.

There is no URL in it, and there should not be. A library's own repository
address is right until somebody forks it, mirrors it, or builds it from a
tarball, and then it is a lie that has been committed. Where to get a library
is whoever wants it from source's to say:

```cmake
cme_port_source(hello GITHUB_REPOSITORY me/hello GIT_TAG v1.4.0)
```

Said separately, field by field, first to say wins. A port with nothing to
say about where it comes from is a perfectly good port for a library that is
installed or in the store; it becomes a problem only when something has to
fetch it, and then the message says what to add.

`cme_port_needs(<port> <what>...)` adds to what a port needs without
redeclaring it. It is what an exported port is written with.

### A library's own features

A library declares what it can optionally be in its own CMakeLists, in the
same call it would use anywhere:

```cmake
cme_port_feature(hello vorbis
  SUMMARY "reads Ogg Vorbis"
  DEPENDS "vorbis>=1.3"
  OPTIONS "HELLO_VORBIS ON")

option(HELLO_VORBIS "read Ogg Vorbis" OFF)
if(HELLO_VORBIS)
  target_sources(hello PRIVATE src/vorbis.cc)
endif()
```

Nothing is repeated between the two. When a consumer asks for
`find_package(Hello COMPONENTS vorbis)`, or when something deeper in the
graph asks for `hello[vorbis]`, the feature's `OPTIONS` are set before the
library's own CMakeLists is added -- so the library reads its own option, the
way it does when somebody builds it by hand. The feature is what other
projects say; the option is what the library reads. `cme_features(hello
vorbis)` in the library's own CMakeLists turns one on for the library's own
build.

**What it was built with is baked into the install.** Every exported port
carries a line about the copy it was installed beside:

```cmake
cme_installed_with(hello VERSION "1.4.0" FEATURES "vorbis" NEEDED "vorbis")
```

So the one question that used to be guesswork -- does the copy on this
machine have the feature this build needs -- is answered by the copy. Without
it, all a build can do is look for a symbol the feature is assumed to add
(`SYSTEM_SYMBOLS`, below), which can only find a feature that changes the
interface and is blind to one that changes behaviour. With it, a copy built
without `vorbis` is passed over and the port is built, and the build says
which feature was missing.

That line is honoured only from a port read out of a prefix. In a source tree
it is a statement about somebody else's machine.

### A port that never gets as far as the repository

A port declared in a project is a whole port, so it can also say where the
library can be found instead of being built. Then the URL is what happens if
none of that works:

```cmake
cme_declare_port(NAME hello PROVIDES Hello
  SYSTEM_PACKAGE HelloLib                # if its CMake config is named that
  SYSTEM_PKGCONFIG "hello:Hello::Hello"  # or if it ships a .pc
  GIT_REPOSITORY https://example.invalid/hello.git
  GIT_TAG v1.4.0)
```

The order is a CMake config or Find module, then pkg-config, then build it,
and only the last of those fetches anything. On a machine that has the
library installed with a `.pc`, nothing is cloned, nothing is compiled, and
the report says `Hello pkg-config 1.4.0`.

The version request is carried into all three: `find_package(Hello 1.4)`
becomes `hello >= 1.4` in the pkg-config query, and `EXACT` becomes `=`.
Features are checked on the installed copy too -- by what the copy says about
itself if it says anything, and by looking for headers and symbols if it does
not.

### Two shapes of the same thing

There is one command and there are two things a project does with it.

**Saying which library and where**, which is the ordinary case above: a name,
a `PROVIDES`, and coordinates. That is not half a port -- it is the whole of
what a project is in a position to know. Everything else arrives with the
tree.

**Describing the library**, which is what you write when the library says
nothing about itself: version, licence, features, dependencies, options, an
adapter. A registry port is this, and so is a port you write in your own
CMakeLists for a library that has never heard of any of this.

A second declaration of a port fills in what the first did not say and
changes nothing that it did, so the two compose without either being a
special case. And there is one exception, which is the rule underneath both:

**Where a library is, and which library it is, are the project's to say. What
the tree turns out to be is the tree's.** A project that names a tag and
guesses the version has guessed; when the tree that was fetched says which
version it is, that is what is being built, and the build says so:

```
hello was declared with VERSION 0.9.0 and the tree that was fetched says
1.0.0; the tree is what is being built
```

The same for the licence. Everything else a project says stands, because the
project chose the library.

### Where a port can come from

| | |
| --- | --- |
| the project | `cme_declare_port()` in your own CMakeLists |
| a fetched source | what the library itself says it needs |
| an overlay | in the order the overlays are named |
| the system | `share/cmake-everywhere/ports` in the prefixes |
| the registry | the ports that come with this |

The first one that names a port is the one that is read, and the build says
so: `beta comes from the overlay ...; the registry only fills in what it did
not say`. `cme_report()` names, for every library in the build, who ported
it.

Explicit before ambient, and yours before anybody's: an overlay can correct a
port here without waiting for us to merge anything, and a project can correct
an overlay without waiting for whoever keeps it.

### Without cloning anything

Finding out what a library needs by cloning the library is backwards when the
question is whether this machine already has it. So what a project declares
is installed beside the project:

```
${prefix}/share/cmake-everywhere/ports/<name>/port.cmake
```

A library that uses this writes nothing to make that happen -- it declared
the ports already, and installing the library installs them. Any prefix in
`CMAKE_PREFIX_PATH` is then a place ports come from: no index, no server, no
clone, and the metadata arrives with the package it describes. A distribution
that packages a library can ship its port in the package; `make install` into
your own prefix shares your declarations with your next project.

`CME_EXPORT_PORTS=OFF` if you would rather your package did not carry them,
`CME_SYSTEM_PORTS=OFF` if you would rather this build did not read them,
`CME_EXPORT_DESTINATION` to put them somewhere else under the prefix.

**An installed port says what that copy is, not what the library can be.**
It was written beside one version, built one way, with some features on and
others off. So a version in it is the version that is here, not a ceiling:
when something asks for more and there is a tag to fetch, it is fetched, and
the question is asked again against what the library itself says it is. And
what a library needed is only written down when it was built with nothing
turned on -- otherwise it is a fact about that build, and declaring it would
make the next project build a dependency it never asked for. When a
description that came from an installed copy is the reason something is
refused, the message says so, because "the copy here will not do" is a
different statement from "this library cannot".

### Overlays

An **overlay** is a directory of ports, laid out the way `registry/` is --
one directory per port, each with a `port.cmake`. Name as many as you like,
as paths or as URLs:

```
-DCME_OVERLAYS="/home/me/ports;https://example.invalid/our-ports.git#stable"
```

A URL is cloned once into `~/.cache/cmake-everywhere/overlays` and then left
alone; `#ref` pins it to a branch or a tag, and `-DCME_OVERLAY_REFRESH=ON`
updates the ones that are not pinned. A dependency tree that quietly changes
under a project between two configures of the same source is worse than one
that is out of date, and out of date is one flag away. This is for an
organisation with its own libraries, not for the ordinary case.

### A port from a URL

One file, from anywhere:

```cmake
cme_port_from_url(https://example.invalid/ports/hello.cmake SHA256 3f2a9c...)
```

The digest is not optional, because that file is CMake this build reads from
a machine that is not yours. `UNVERIFIED` takes it without one and is meant
to be written while working something out and then removed. Either way the
file's digest goes into the lock, so a file that changes under a project
stops the build rather than changing it.

### A lock you commit

A port that came from somewhere else is two things this project does not
contain: code the build reads, and a library the build fetches. Both can
change without a line of this project changing -- a tag moves, a branch
certainly moves, an archive is replaced, a port file is edited in the overlay
it lives in. So both are written into `cme-lock.json` beside your CMakeLists:

```json
{
  "lock": 1,
  "ports": {
    "hello": {
      "commit": "6f1c0e5a2b...",       // what was fetched, not the tag
      "port": [ "3f2a9c..." ],         // a port file that came from elsewhere
      "version": "1.0.0"
    },
    "zlib": { "archive": "SHA256=...", "version": "1.3.1" }
  }
}
```

On the next build every one of those has to still be true, and if one is not
the build stops and names it. Ports the project declares itself are not in
it: they are in the project, which is what the lock is for.

**Writing it is its own run.** An ordinary build does not fetch what it does
not need: a library the system has is never downloaded, one already in the
store is not either, and a lock written by such a build has holes in it. So
such a build says which holes it left, by name, and there is a run that
leaves none:

```sh
cmake -S . -B build/lock -DCME_LOCK_ALL=ON \
  -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=.../cmake-everywhere.cmake
```

Nothing from the system, nothing from the store, every library fetched and
every port read. Commit what it writes.

**Updating one library does not re-pin the others.** A blanket update takes
whatever every library happens to be today and writes all of it down as
intended, in one commit, under the heading of updating one thing -- so a tag
that was repointed under another library, or a port file edited in an
overlay, is re-pinned in the same breath and reviewed as part of somebody
else's change. So an update names what it is updating:

```sh
cmake -S . -B build -DCME_RELOCK=hello   -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=.../cmake-everywhere.cmake
```

Only `hello` may come out different; everything else is still held to what
the lock says, and the build stops if it is not. A refusal names that flag,
so the way to accept a change is written in the message that reports it. The
two combine: `-DCME_LOCK_ALL=ON -DCME_RELOCK=hello` reaches everything, so
the lock comes out whole, and still lets only `hello` change.

`-DCME_LOCK_UPDATE=ON` is the blanket version, for the first time a lock is
written or when you mean all of it; `-DCME_LOCK=` (empty) turns the whole
thing off.

`-DCME_UNLOCKED=hello;wibble` says those two are being followed rather than
pinned. The same thing said where the port is written, which is usually the
better place for it:

```cmake
cme_declare_port(NAME hello PROVIDES Hello UNLOCKED YES
                 GIT_REPOSITORY https://example.invalid/hello.git
                 GIT_TAG main)
```

The rule is the same for everyone, a project and a library alike: **you may
say it about yourself, and about a port you declared.** A library that
declares where its own unported dependency comes from may say that one is
followed rather than pinned, because it is the one saying where it comes
from. It may not say it about a port somebody else declared -- it cannot
unpin the registry's zlib because it happens to use it. Anything wider than
that is the project's to say on the command line. A port asked about by
someone with no standing to ask stays pinned, and the build says so rather
than quietly obeying.

### The registry is the part that should shrink

Everything above is what makes the registry in this repository a fallback.
The number of ports in it is how much work is left, not how much is done: a
port exists because a library has not adopted this, and adopting it is a
handful of lines in the library's own CMakeLists, for which the library gets
its own dependencies resolved the same way. When that happens the port here
should shrink to nothing and then be deleted.

## Asked the other way round

A dependency provider is offered `find_package` and nothing else, so a
project -- or a library this build added -- that asks pkg-config instead goes
straight past all of this. It finds the system's copy or it finds nothing,
and nothing here hears the question. That is a hole of the same shape as a
system config file resolving its own components, and it is closed the same
way:

```cmake
find_package(PkgConfig REQUIRED)
pkg_check_modules(ZLIB REQUIRED IMPORTED_TARGET zlib)
target_link_libraries(app PRIVATE PkgConfig::ZLIB)
```

That is answered by the zlib port, from the system when the system has it and
from source when it does not, and the variables the caller reads afterwards
are set to what a target makes of them. `SYSTEM_PKGCONFIG` is what makes it
possible: a port already says which pkg-config modules a machine may have it
as, and read backwards that says which port a module is.

Those are two questions, though, and a port can answer one and not the
other. *Which module names mean this library* is a fact about the library.
*Which of them may answer for it* is a judgement about copies of it this
build did not make. Skia is where they come apart: what an installed Skia was
compiled with cannot be read from its `.pc` file, and this port's features
are exactly that, so it will not take a system copy -- and the module `skia`
still means it. `PKGCONFIG_NAMES` says the first without the second:

```cmake
PKGCONFIG_NAMES skia
```

Without it, a library inside the build that asks pkg-config for `skia` --
skiff does -- links the machine's Skia while everything else links the one
built here, and nothing says so.

**Only a `REQUIRED` call.** Without `REQUIRED` the question is "does this
machine have it", and answering that by building the library answers a
different question -- an optional dependency would become a compulsory
download. Those go to pkg-config as they always did, as does any module no
port answers for.

FindPkgConfig defines `pkg_check_modules` when it is included, and it is
included by `find_package(PkgConfig)`, which comes through the provider. So
that is where the real one is stepped in front of, and it stays reachable
under the name CMake leaves it at.

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
alone. Every decision is written to `cme-report.txt` in the build directory --
which package came from where, at what version, and who ported it. That file
is a report of one build; `cme-lock.json`, above, is the pinning you commit.

### Why it built something you have installed

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
The report says which of the three answered for each package, so a build that
took longer than expected can be read rather than guessed at.

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

## Versions

`find_package(FLAC 1.4)` means 1.4 or newer, and it is treated that way:

* the system copy is accepted only if it satisfies the request -- the version
  goes into the `find_package` call and into the pkg-config query;
* the port is built only if what it can produce satisfies the request. A port
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

`@VERSION_UNDERSCORE@` and `@VERSION_DASH@` exist for the projects that spell
it those ways. A port without a template refuses the request instead of
checking out something that is not what was asked for -- unless the version
it is being held to came from a copy installed on this machine, which is not
the library speaking and cannot refuse a fetch.

### Requirements are read before anything is built

A dependency can carry a floor, and that is data in the port rather than
something only discovered by running a third-party CMakeLists:

```cmake
DEPENDS "ogg>=1.3" vorbis flac opus
```

When a package is asked for, the whole graph under it is walked first and
every floor in it raised, before a single `add_subdirectory` has run. So a
version needed by something deep in the graph is known while the shallow end
is still being decided, and a port whose pin is lower is built at the version
that satisfies everyone. Nothing is built twice and nothing ends up older
than something else needed.

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

The floor goes into the cache and into the report, so the next configure
resolves it correctly from the first call. Once per requirement, not once per
call.

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

A port asks for them from another port in its dependencies, which is where
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

This is not a grouping of libraries. `graphics` would be a group and it would
be wrong: a renderer can be built out of others. `vulkan` is one capability
of one library, and the library is the only thing that knows what turning it
on means.

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
  DEFAULT  YES                   # on unless something refuses it
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
`DEFAULT` is how a port matches an upstream default it agrees with --
`flac`'s Ogg support is on because libFLAC's own build turns it on.

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

## Licences

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

One thing does not reach a library that describes itself: this is checked
before the fetch, so a library whose only licence statement is in its own
port is refused before it can make it. Whoever sets that variable has to say
`LICENSE` in the declaration as well.

## Reading what was decided

```cmake
cme_report()
```

at the end of the top-level `CMakeLists.txt` prints every library that was
reached: where it came from, at what version, who asked for it, who ported
it, and each of its features with whether it is on, who wanted it, and what
it is for. The same text is written to `cme-report.txt` in the build directory.

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

## One way of building, for all of them at once

```cmake
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)
set(CMAKE_BUILD_TYPE Release)
```

before `project()`, and every library the build reaches is built that way --
with link-time optimisation, in release. Not each one configured by hand with
whatever it happens to call the option, because a port is added inside this
build and inherits it, one built on its own is handed it, and a GN project is
told it in its own vocabulary.

A port is always a static archive, compiled position independent, and that
one is not a choice. It is the only shape this can keep and hand back: a
store entry is archives, and a shared library is a file that has to be found
again at run time by something that installed it, which this does not do.
Position independent because a consumer building a shared library out of
these needs it and one that is not loses nothing.

Both of those are part of what an entry in the store is named after: objects
compiled for link-time optimisation are not the same objects, and a library
built one way is not the library built the other. A build with LTO and a
build without do not share a copy.

And none of it takes away the system: `CME_SYSTEM=AUTO` still uses what is
installed where the request allows it. Which is the combination that is
awkward to get elsewhere -- most package managers pick one side of it. Meson
comes closest, with a system dependency and a wrap to fall back to; Spack has
external packages you declare; Conan has system recipes for some things.
vcpkg and Nix build everything on purpose and do not offer the choice at all.

## Writing a port

A port is one directory in `registry/`, or one call in your own CMakeLists,
or one file a library carries. Everything except the adapter is data:

```cmake
cme_declare_port(
  NAME libpng
  PROVIDES PNG               # the name projects write in find_package()
  VERSION 1.6.44
  GITHUB_REPOSITORY pnggroup/libpng
  GIT_TAG v1.6.44
  DEPENDS zlib
  LICENSE Libpng
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

An adapter lives beside a `port.cmake` in a directory. A port declared in a
CMakeLists can have one too -- it is an ordinary function -- but a port with
`OVERLAY` cannot be exported, because an overlay is a directory and a
declaration in a CMakeLists has none.

### The names a library is known by

```cmake
PROVIDES Ogg ogg OGG
```

`find_package` is called all three ways by real projects, and the port
answers to each.

### Headers under the name they are used by

A library's include directory in its own checkout and the same directory once
it is installed are often not the same shape, and everything that consumes
the library was written against the installed one.

Opus keeps its headers flat, at `include/opus.h`, and puts them under `opus/`
when it installs them -- so libsndfile's `#include <opus/opus.h>` compiles
against an installed Opus and not against a checkout of it. Skia includes
itself as `"include/core/SkCanvas.h"`, a path with nothing in it to say whose
include directory that is.

A port offers the directory a second time under the name consumers use:

```cmake
cme_header_prefix(prefix opus "${source}/include")
```

```cpp
#include <opus/opus.h>
#include <skia/core/SkCanvas.h>
```

Nothing is copied and nothing is rewritten. The name is a link, and the
original directory stays on the interface too, so the library's own spelling
keeps working -- which matters, because the library compiles itself with it.

### What a bare library name means

A project told to use the system's libpng ends up asking the linker for
`-lpng`, and the linker answers with whatever it finds -- on a machine that
has libpng installed, that is the system's copy, with headers from this build
and a library from somewhere else, and it is silent about it. So a port says
what it answers to:

```cmake
LINK_NAMES "png=PNG::PNG" "png16=PNG::PNG"
```

and a bare name that matches becomes that target. A target is an archive with
a path, and a path cannot be mistaken for something else.

### A port that is only for somewhere

```cmake
SYSTEMS Android
```

Oboe is Android's, and its build says so by compiling with warning flags only
Clang has. A port that names the systems it is for is refused anywhere else,
at the point somebody asks for it rather than at the first flag the compiler
does not recognise. The build that checks the registry skips it rather than
failing it.

### Old projects

CMake 4 refuses to configure a project whose `cmake_minimum_required` asks
for less than 3.5, and released libraries ask for less than that -- libogg
1.3.5 asks for 3.0. These are trees this did not write and cannot correct, so
ports are configured with `CMAKE_POLICY_VERSION_MINIMUM` set to 3.5
(`CME_POLICY_VERSION_MINIMUM` to change it). A port that needs another floor
says `POLICY_MINIMUM` and gets it. The floor applies to ports only: your own
project is configured exactly as you wrote it.

### Nothing of a dependency is installed

Ports are added with `EXCLUDE_FROM_ALL`, and the CMake documentation is
explicit about what that means: "Any install rules defined in the
subdirectory or below will be ignored when installing the parent directory."
A library this built is part of your build, not part of what you ship:
`make install` on your project installs your project.

That is not quite enough, though, and the difference is worth knowing. CMake
still *checks* an `install(EXPORT)` while generating, even one it will never
run -- so libpng, which exports its targets and links zlib, fails there
because zlib is in no export set of libpng's. The rules would never have run;
the check does not care. So ports are additionally given `SKIP_INSTALL_ALL`
and its three companions, which zlib introduced and libpng and freetype
followed. A project that has never heard of them ignores them.

Their headers are added with `SYSTEM` as well. Their warnings are not yours.

### Nothing is built at configure time

The `*-populate` steps in the log are FetchContent downloading, and they say
so themselves: no configure step, no build step, no install step. Every
library is added with `add_subdirectory` and compiled by ninja in the main
build, in parallel with everything else, with your flags and your generator.

A port pinned to a branch instead of a commit makes those download steps run
on every configure, because a moving ref has to be checked each time. That is
why ports name commits or tags -- and why the lock records the commit that
was actually fetched.

## Libraries that are not a CMake subdirectory

### A library with no CMake

`OVERLAY` says the upstream has no build system of its own. The sources are
downloaded and nothing is configured from them; the overlay directory beside
the port is a normal CMake project that reads them through
`CME_UPSTREAM_SOURCE_DIR` and builds what it likes. Nothing is written into
the fetched tree, so the checkout stays exactly as it was downloaded and the
overlay can be read as ordinary CMake.

`registry/minimp3` is the worked example: a library that is one header with
its implementation behind a macro, turned into a static library by a
three-line translation unit that lives in the overlay.

### A library that refuses to be a subdirectory

Some libraries will not be added to another build. libjpeg-turbo says so in
as many words and stops: an upstream build system cannot anticipate every
downstream one, and it would rather not try. That is a fair position, and it
needs a different mechanism rather than an argument.

So it is not made one:

```cmake
IMPORT cmake
IMPORT_TARGETS "jpeg-static=JPEG::JPEG"
```

It is configured on its own, asked what it would build, and that is built
here -- in your graph, with your generator, beside everything else. The same
idea as the GN ports and for the same reason: a build system describes a
build far better than it can be guessed at.

Two sources, because one is not enough. CMake's File API describes every
target: its sources, its defines, its include directories, and the exact
flags each *group* of sources is compiled with, so a project that compiles
one file differently from the rest still does. It does not describe custom
commands at all, so those are read out of `build.ninja`, which is where the
generator wrote them down, and run the way it would have run them: through a
shell, from the directory they were written for. Reproducing them any other
way is guessing.

`EXTERNAL YES` still exists and is the escape hatch: configure, build and
install on its own, and take the install prefix. Nothing uses it now.

### A library that builds with Meson

```cmake
IMPORT meson
IMPORT_TARGETS "basu=basu::basu"
```

The same mechanism, for a project with no CMake at all. `meson setup` runs
at configure time -- with your compiler, your flags and, when you are
cross-compiling, a cross file written from your toolchain -- and writes down
what it would build in `meson-info`. That is read into the same description
the CMake importer produces, so the targets are made in one place for both:
ordinary CMake targets in your graph, built by your generator.

What Meson states and what it does not is the whole difficulty. Every
target's sources and the exact parameters each group of them is compiled
with are there, and so are the parameters its *linker* gets, which is where
a library from outside the project is named. What is not there:

- **What an archive is built against.** Meson does not put a static
  library's dependencies on its own command line; it appends them where the
  library is used. What the archive holds is read from the edge that
  archives it, so a static library built against another one still links
  against it here. What it needs from outside the project is written down
  nowhere, and the port says it -- `registry/basu` is the worked example.
- **Custom commands**, which are read out of `build.ninja` by the same
  reader the CMake importer uses. A name to type at a build tool -- `test`,
  `install`, a run target -- is written the same way there and is not a file
  anything makes, so it is skipped.
- **A library with no sources of its own.** `library()` with everything in
  it coming from static libraries it bundles is common; Meson puts those
  targets' *objects* in the archive, and the objects say which target they
  were compiled for by the directory they are in. Such a target becomes an
  interface library over the ones it is made of.

A target written in a language CMake has no compiler for is skipped and said
out loud, as is a name two targets share.

`registry/basu` is the worked example: sd-bus taken out of systemd, so a
program that talks to D-Bus can be built on a machine that runs none of it.
Its port asks the system for `basu`, `libelogind` and `libsystemd` in that
order first -- an installed one answers, and only a machine with none of
the three builds anything.

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

`cmake/gn.cmake` knows nothing about any particular project. A port supplies
its project's own vocabulary -- one calls the compiler `cc`, the next calls
it `clang_path` -- and asks for the values it cannot know by placeholder:
`@CC@`, `@CXX@`, `@AR@`, `@SYSROOT@`, `@TARGET_OS@`, `@TARGET_CPU@`, and
`@DEP_INCLUDES@` / `@DEP_LIBDIRS@` for the libraries this built for it.
`GN_CONFIRM` reads back what GN actually settled on, because an argument that
is misspelled or overridden still reads correctly in the command line that
set it.

The alternative -- reading a project's source lists and re-stating its
conditions in CMake by hand -- is the same work again, done worse, once per
release. This way a new file arrives on its own and a new condition is
evaluated by GN.

What is fragile: `action()` steps become `add_custom_command`, and GN rebases
their script arguments against its build directory, so they are run from
there. `gn` has to be on `PATH` at configure time, or named with `-DCME_GN=`.

### How good a port is

Not every port is a full CMake build, and the ones that are not should say
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
all this: a library that ships its own CMake needs no port at all.

## What a port still is, when nothing is missing

A library that ships CMake, resolves its own dependencies instead of calling
bare `find_package` and hoping, and exports namespaced targets needs nothing
from this registry to *build*. That combination -- CMake plus CPM.cmake plus
exported targets -- is what this argues for, and it is about thirty lines of
work for a library to adopt.

So most of a port is a note about one of three things being absent upstream:

| | what is missing | what is done about it |
| --- | --- | --- |
| 1 | no CMake at all | an overlay: a CMake project written here that builds the downloaded sources |
| 2 | CMake, but dependencies are looked for with bare `find_package` | the provider answers those calls |
| 3 | CMake, but no namespaced targets and no exported config | an adapter gives the result the names its consumers use |

Those three shrink to nothing as upstreams improve, and a port deleted for
that reason is this repository working rather than losing.

But a port is not only those three, and this is worth being clear about,
because it is easy to think a well-behaved library needs no entry anywhere at
all. What remains even when nothing is missing:

* **Features.** A library has its own options -- `WITH_OGG`, `PNG_SHARED` --
  and nothing in it maps them to a name shared with other libraries, knows
  that one implies another, brings a dependency into *this* resolution when
  one is on, or says how to tell whether a copy somebody else built has it.
* **Versions with digests.** An archive and a hash of it, so a build is the
  same build tomorrow.
* **Where it can be found instead.** CMake has no `FindOgg`, so somebody has
  to say that the pkg-config module `ogg` is this target -- however good
  libogg's own CMake is.
* **What it answers to.** A bare `-lpng` finds whatever is installed, and
  only a port can say which target that name means here.
* **The names it is known by.** `Ogg`, `ogg`, `OGG`, `SndFile`, `sndfile`.
* **What it is under**, so a project can refuse a licence it cannot carry.
* **Variables its consumers read.** Exporting `Freetype::Freetype` correctly
  does not set the `FREETYPE_LIBRARIES` that some *other* library reads.

`ogg` and `opus` are the shape a finished port has: no overlay, no adapter
worth the name, and a dozen lines of the list above. That is the success
condition -- ports that are thin, and most of them living with the library
they describe rather than here.

## A library that is many libraries

Boost is one release cut into 158 repositories. ICU is three libraries that
have to agree with each other. Qt is dozens. A project usually wants one
piece -- `boost_mp11` is a megabyte and the superproject archive is a hundred
-- so each piece is its own port:

```cmake
find_package(boost_filesystem REQUIRED)
target_link_libraries(app PRIVATE Boost::filesystem)
```

and there is an umbrella for the projects that write `find_package(Boost)`
and name what they use as components:

```cmake
find_package(Boost COMPONENTS filesystem asio REQUIRED)
```

The umbrella builds nothing: each component is one of the ports beside it,
which is where the library actually comes from. Asking for Boost and no
components asks for no Boost libraries, which is what Boost's own CMake does
with an empty `BOOST_INCLUDE_LIBRARIES`.

### The family

Which raises the question those 158 ports would otherwise get wrong. If
`boost_mp11` comes from the system at 1.83 and `boost_filesystem` is built
here at 1.92 -- because the system's is too old -- the build has two versions
of one library, with headers from one and symbols from the other, and it
fails as a constructor reading the wrong offset. There is no diagnosing that
from the message.

So a port can name a **family**, and the first member of it to be answered
decides for the rest: from the system or built, and at which version.

```cmake
FAMILY boost
```

A member that cannot be had the way the first one was is an error naming both
and saying what to do about it, rather than a build that mixes them. It is
not a Boost mechanism: anything released as a set of libraries that must
match wants it.

### One download or a hundred and fifty-seven

Where the sources come from is the one thing about a Boost library worth a
choice, and it is one switch:

```
-DCME_BOOST_ARCHIVE=ON
```

Off, every library is its own repository, which is the small download when a
project uses one or two of them. On, all of it is the release archive that
Boost publishes, fetched once, and every port is a directory inside it --
which is faster from about the tenth library and is the same libraries
either way.

Underneath it is not a Boost mechanism: `SOURCE_FROM` says a port's sources
are a directory inside another port's, and that other port is fetched once
and never built. Anything published both as many repositories and as one
archive can say the same.

### Written from what Boost declares

Every one of those repositories says in its own CMakeLists which targets it
defines and which of the others it links. That is the dependency graph, kept
by the people who change it, so `tools/boost-ports.py` reads it and writes
the ports:

```sh
python3 tools/boost-ports.py 1.92.0
```

The generated ports are ports like any other -- nothing reads them
differently -- and the script is run again when Boost is released rather than
maintained by hand. A hand-written copy of that graph would be a hundred and
fifty-eight files that rot at the next release, which is the failure this
repository keeps warning about in other people's build systems.

The per-port CI does not run a job for each of them: a family is checked by a
sample, and what is left out is printed rather than left looking like
coverage.

## What is here

zlib, libpng, libjpeg-turbo, libwebp, freetype, expat, xz, libzip, ogg,
vorbis, FLAC, opus, libsndfile, minimp3, mpg123, openal-soft, oboe, glfw,
Skia, and Boost -- 157 of it, one port per library, plus the umbrella.

That is not a registry yet, and it is not trying to become one. It is enough
to show the shapes -- a library with CMake, a library without one, a library
that refuses to be a subdirectory, an autotools library that carries a CMake
build of its own, and a library with a different build system entirely --
and enough to prove the interesting case: `find_package(SndFile)` alone
brings four more.

`mpg123` is the autotools one, and it is worth reading as a port because
what it needed was not an overlay. mpg123 carries a CMake build under
`ports/cmake` that upstream maintains, so the library is built in your graph
by your compiler; what the port supplies is the release archive with a
digest, a namespaced target, and one line of adapter, because that CMake
build puts only its binary directory on the interface and the header a
consumer includes is a file in the source tree it installs from there.

`glfw` is the one to read for features that are not about codecs: `x11` and
`wayland` are what a window library is built for, both on by default the way
glfw's own build has them, and a machine with one set of headers and not the
other can turn the other off and still have the library it can use.

## Not building the same thing twice

A library that has been built before, from the same sources with the same
features by the same compiler for the same target, is not built again. It is
kept in `~/.cache/cmake-everywhere/store` under a name that is a hash of all
of that -- and of everything underneath it, so a change to zlib changes the
name of everything above zlib.

```
store/skia/153-4f2b9c1ea3d07e58/
  use.cmake        what the library is and how to use it
  lib/*.a          the archives
  environment.txt  what it was built with, in full
  complete         written last, and the only thing a later build looks for
```

Static archives, not object files -- but *all* of the archives. A static
library does not contain the other static libraries it links and an interface
library contains nothing at all, so what is kept is worked out by walking
what the exported target links: every archive from this port is copied, and
anything from outside it is written down by name and resolved again by
whoever reads the entry. Object files are the exception and are not kept,
because they are already inside the archive of whatever linked them.

This works for a library built by GN and for one added as a subdirectory
alike: what is kept is the port's targets, whatever made them. Two things
have to travel with the archives for that to be true. The headers a library
generates while configuring -- `zconf.h`, `pnglibconf.h` -- live in a build
directory the next build will not have, so they are copied beside the
archives and the paths rewritten. And the variables a consumer reads are
written into the entry as well, because the adapter that set them does not
run on a hit.

A later configure that computes the same name reads `use.cmake` and has its
targets in a second: no fetch, no `gn gen`, no five hundred compiles.

How much has to match is a choice, because two different things are mixed
together in what decides a build. What the library *is* -- which library, at
which version, from which sources, with which features and options, and what
every declaration that contributed to its port said -- is its identity, and a
difference there is a different library whatever you say. The rest is the
machine it was built on, and how much of that matters is a judgement:

| `CME_STORE_MATCH` | what has to match |
| --- | --- |
| `EXACT` | everything, down to the exact flags |
| `COMPATIBLE` (default) | what decides whether objects link and behave: the compiler and its major version, the target, the sysroot, the toolchain file, position independence, the C++ standard, the build type |
| `LOOSE` | only what makes the objects usable at all: the target and which compiler it was |

One thing is in the name in every mode, including the loosest: a digest of
this repository's own code. What a port says is already part of the entry's
identity; what *reads* the port decides what a build contains just as much,
and it is not something about the machine that a build can be forgiving
about. Without it, a fix to an importer -- one that put objects into an
archive they had been missing from -- left the name exactly as it was, and a
build that had just been fixed was answered with the library from before the
fix, out of a path with `store` in it. The cost is that updating this
repository rebuilds what it had built; the alternative is a cache that
answers with the bug you just fixed.

`COMPATIBLE` means a patch release of the same compiler, a changed warning
flag or a different `-O` is a hit rather than half an hour. In every mode the
whole environment is recorded next to the library and compared on the way
back in, and everything that differs is printed:

```
-- cmake-everywhere: skia 153 is already built
-- cmake-everywhere: reusing it across 2 difference(s), because CME_STORE_MATCH is COMPATIBLE
--     CMAKE_CXX_FLAGS: built with [-O2], now [-O2 -march=native]
--     CMAKE_CXX_COMPILER_VERSION: built with [19.1.7], now [19.1.9]
```

A reuse that is not exact is a decision, and a decision nobody is told about
is a surprise later.

The store is asked twice, before the fetch and after it, and the first ask is
what keeps a build with a warm store from downloading anything at all. The
second is for a port that was only a name and a URL until the tree arrived:
what a library says about itself is part of what it is, and so part of the
name its build is kept under.

Two things this is careful about. The archives are copied when the build has
made them and the stamp is written last, so an interrupted build leaves an
entry that is ignored rather than one that is half true. And when in doubt an
input goes into the hash: a hash that is too specific costs a rebuild, and
one that is not specific enough costs an afternoon of looking for why a
library behaves as though it were built with something else.

An entry is filled under a name nobody reads and moved into place in one
step, because a reader cannot tell a directory being written from a finished
one and a rename is the only way to say "now". Two builds that finish the
same entry at the same time are finishing the same thing -- the name is a
hash of everything that decides what is in it -- so the second one throws its
copy away rather than replacing a directory somebody may be reading.

What it does not do, said here rather than found out. Nothing is ever
removed: the store grows until somebody deletes a directory in it. And a
library that writes its headers while building rather than while configuring
is not kept at all -- it says so and is built each time, which is the honest
answer, since keeping it would keep something that cannot be compiled
against.

Turn it off with `-DCME_STORE=` (empty), or point it somewhere else with
`-DCME_STORE=/path`. There is a compiler cache as well, used when one is
installed (`CME_COMPILER_CACHE`), but it is the smaller half: it makes
compiling cheaper, while this skips the compiling, the generating and the
linking together.

## A build with no network

Some builders take the network away on purpose -- flatpak-builder does -- and
a build that reaches for it there does not fail cleanly, it hangs and then
fails obscurely. So fetching and building are separable.

On a machine that has a network:

```sh
cmake -S tools/prefetch -B build/prefetch \
  -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=$PWD/cmake-everywhere.cmake \
  -DCPM_SOURCE_CACHE=$PWD/vendor \
  -DCME_PREFETCH="skia;openal-soft;libsndfile" \
  -DCME_FEATURES_skia="gl;png;freetype"
```

Nothing is compiled; every library named, and everything underneath it, is
fetched into `vendor/` and left there. Ask for the same features the real
build will ask for -- a feature is what brings a dependency, so fetching Skia
without `png` does not fetch libpng, and the offline build would stop at the
first thing it could not reach. `CME_FETCH_ONLY` is the same thing for a
project that declares its own ports: it fetches and builds none of it.

Then, wherever there is no network:

```sh
cmake -S . -B build -G Ninja \
  -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=.../cmake-everywhere.cmake \
  -DCPM_SOURCE_CACHE=/path/to/vendor \
  -DCME_OFFLINE=ON
```

`CME_OFFLINE` refuses to fetch rather than failing to: what is not in the
cache is an error naming what is missing, not a timeout.

Both halves are checked on a machine with no `/usr`. Nothing here looks for a
library by path -- the system is asked through `find_package` and pkg-config,
which read `CMAKE_PREFIX_PATH` and `PKG_CONFIG_PATH` -- and Nix, where every
package lives in a directory of its own with a hash in the name, is where
that stops being a claim: a build with a `/usr` in it anywhere fails there
and nowhere else. The offline half runs in a network namespace of its own, so
"it did not reach for the network" is a fact rather than a hope. Guix asks
the same two questions weekly.

### The lock is the list a sandbox needs

A build that cannot reach the network has to be handed its sources by
whatever is running it, and what that wants is exactly what the lock already
holds: where each library came from, at which commit, or which archive with
which digest.

```sh
python3 tools/lock-to-nix.py cme-lock.json > sources.nix
python3 tools/lock-to-guix.py cme-lock.json > sources.scm
```

A repository comes out as `builtins.fetchGit`, which needs no separate hash
because a full revision pins it; an archive comes out as `fetchurl` with the
digest the lock has. Guix wants the digest of a checkout's *contents* for a
repository, and nothing but fetching produces that, so those come out with
the place to put it and the command that says what to put there. A generated
file that filled it in with something plausible would be worse than one that
says it does not know.

With the source cache at hand both fill in the digest of the contents, which
is the thing neither a commit nor an archive digest can be turned into:
`tools/nar-hash.py` computes it the way Nix and Guix do, and a repository
then comes out as a complete `fetchgit` or a complete `git-fetch` origin.

That computation is somebody else's format, so it is compared with theirs
rather than trusted: the Nix job checks it against `nix hash path` and the
Guix job against `guix hash -r`, on a tree with a subdirectory, an executable
and a symlink, because those are the three things the format says something
about. And the generated file is then handed to Nix, which fetches every
source in it and checks every digest itself -- so a hash computed wrongly is
a build failure rather than a plausible string in a file nobody ran.

The same project, the same code, both ways round -- which is the point. A
project should not need one dependency arrangement for a normal build and
another one for a builder that unplugs the network.

## Configuring until it settles

One configure pass cannot un-build a library, so a request that arrives after
the library it is about -- a component asked for by a third-party CMakeLists
this build added, a version needed by something deep in the graph -- is
written into the cache and the run stops, saying so. The next configure has
it from the start.

That is one round per requirement of this kind, and a project with several is
several rounds, which is a poor thing to ask a person to do by hand:

```sh
tools/configure -S . -B build -G Ninja   -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=.../cmake-everywhere.cmake
```

Everything after the name goes to `cmake` unchanged. It stops on the first
configure that succeeds, on a failure that is not this one -- it looks for
the message, not for failure in general -- and on the ceiling, `CME_ROUNDS`,
four by default, because a project that has not settled in four rounds is not
going to.

## Checking it

There is a build that runs one job per library, so a port that has rotted is
named rather than being one line in somebody else's log. It reuses three
things, because the expensive part is compiling rather than downloading:
sources are cached against the port's pins, object files are cached by
ccache, and the runs that can reuse nothing -- every library from source, and
Skia with features -- happen weekly rather than on every push. The weekly one
is the point: it is what finds a library whose upstream moved under a port
nobody touched.

Locally:

```sh
python3 check.py          # nothing is fetched: names, licences, targets
test/decentral.sh         # a library nobody has ported, used every way there is
test/store.sh             # built once, found again, not found when it should not be
test/run.sh               # everything that needs no more than a compiler
test/run.sh --with-skia-features   # and the ones that need gn and a wait
```

Boost is also taken from the system once, which is the path a distribution's
user takes: the family agreeing to come from the installed copy, the
per-library config files a distribution ships, and the umbrella reporting
what the family settled on. The assertion that matters there is that nothing
was fetched -- a build that quietly downloaded and built Boost beside an
installed one would pass every other check.

Every Boost library there is a port for is built, both ways round. All of it
in one build from the archive, because the archive is one download of
everything and that is the shape of that path; and a job apiece from the
repositories, in `.github/workflows/boost.yml`, which is generated by the
same script that writes the ports and out of the same graph. Each of those
jobs waits for the libraries its own is built on, so a broken leaf skips what
is above it rather than failing a hundred and fifty times -- and what is
skipped is the truth about what this run did and did not check.

Waiting is also what makes the store worth using there. Every job keeps what
it built as an artifact, and takes the ones the jobs before it left; those
are the libraries it is built on, checked by their own jobs, so a hit is
their answer rather than a way around this job's question. Its own library is
never in what it downloads, which is the line to hold: a job whose question
is "does this library build" must not be answered by not building it. The
archive job keeps the store off entirely, because in one build there is
nothing that has already been checked.

Those entries are written with `CME_STORE_PORTABLE=ON`, which copies the
headers an entry needs into it instead of pointing at the source tree it was
built from. That is what a store has to be to travel at all -- to another
machine, into a container, or between two jobs -- and it costs disk, so it is
a choice rather than the default. Between runs it is ccache and the source cache.

### What a source build cannot answer

A library that asks a question at configure time by compiling a program
against one of its dependencies cannot be answered by a dependency this build
is going to produce. `try_compile` generates a separate project, which can be
handed imported targets but not targets that do not exist yet -- so a system
copy answers such a probe and a source build cannot.

Boost.Iostreams is the worked example: it asks whether liblzma has
multithreading by compiling against `LibLZMA::LibLZMA`, and the answer, when
that liblzma is being built here, is a CMake error rather than yes or no. So
its port gives the answer instead of letting it be measured, and gives the
one that costs a feature rather than the one that costs a build. Any port
whose library probes this way needs the same, and the message it fails with
names the target, which is how you find it.

`test/decentral.sh` builds an upstream repository, an overlay directory and
an overlay repository a minute before using them, and then uses a library
that is in no registry anywhere: declared by the project, read from an
overlay directory, read from an overlay repository, carried by the library
that needs it, installed into a prefix and read back from there, described in
one place and located in another, and refused when nothing says where it
comes from. It also asks the lock its questions: a run that reaches
everything writes down the commit that was actually fetched and the digest of
every port file, a commit that moved stops the build, and a port that is
followed rather than pinned does not.

`test/store.sh` asks the store three questions, and none of them is "was it
faster" -- a timing is not an answer. Every build writes down where each
library came from, so the questions are asked of that: a library nobody has
built is *built*; the same library in another build directory comes from the
*store*; the same library with a difference the mode does not allow is
*built* again, and with one the mode does allow it is found.

Two kinds of check in `test/run.sh`. The refusals configure a project against
a registry of libraries that do not exist -- every one of those errors is
decided while the graph is being walked, so nothing is ever fetched -- and
each asserts not only that the build stopped but *why*: a refusal for the
wrong reason fails the check, because the message is the feature.

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

## Every knob

| | |
| --- | --- |
| `CME_SYSTEM` | `AUTO`, `ALWAYS`, `NEVER` |
| `CME_SYSTEM_<PACKAGE>` | the same, for one package |
| `CME_REGISTRY` | the ports that come with this |
| `CME_OVERLAYS` | directories of ports, or URLs of repositories of them |
| `CME_OVERLAY_CACHE` | where overlay repositories are cloned |
| `CME_OVERLAY_REFRESH` | update the overlays that are not pinned |
| `CME_SOURCE_PORTS` | read what a fetched library says about itself |
| `CME_SYSTEM_PORTS` | read ports installed in the prefixes |
| `CME_EXPORT_PORTS` | install the ports this project declares |
| `CME_EXPORT_DESTINATION` | where, under the prefix |
| `CME_LOCK` | the lock file to write and be held to |
| `CME_LOCK_ALL` | reach everything and write a whole lock |
| `CME_LOCK_UPDATE` | take what this build resolved to as the new lock, for everything |
| `CME_RELOCK` | the ports this build may write new facts about |
| `CME_VERSION_<port>` | the version to build, and what a family's decision sets |
| `CME_BOOST_ARCHIVE` | take Boost as one archive rather than a repository per library |
| `CME_UNLOCKED` | ports being followed rather than pinned |
| `CME_LOCK_FILE` | where the report of one build is written |
| `CME_STORE` | where built libraries are kept, or empty for none |
| `CME_STORE_MATCH` | `EXACT`, `COMPATIBLE`, `LOOSE` |
| `CME_STORE_PORTABLE` | copy the headers an entry needs into it, so it can be used elsewhere |
| `CME_COMPILER_CACHE` | the compiler cache to give ports, or `OFF` |
| `CME_FEATURES_<port>` | features wanted |
| `CME_FEATURES_OFF_<port>` | features refused |
| `CME_DEFAULT_FEATURES` | features wanted, or refused with `-`, wherever they exist |
| `CME_OPTIONS_<port>` | options for one library being built |
| `CME_GN_ARGS_<port>` | GN arguments for one GN library |
| `CME_VERSION_<port>` | the version to build |
| `CME_ACCEPT_LICENSES` | the licences this build will carry |
| `CME_POLICY_VERSION_MINIMUM` | the policy floor ports are configured with |
| `CME_OFFLINE` | refuse to fetch |
| `CME_FETCH_ONLY` | fetch and build nothing |
| `CME_GN` | the `gn` to use |

## Licence

MIT. This is build glue that is meant to be copied into other people's
projects, so it is licensed the way build glue is: the same as CPM.cmake,
compatible with everything including GPLv2.

No third-party source is redistributed here. A port is where a library comes
from, how to build it and what the result has to look like; the library
itself is downloaded at configure time and stays under its own licence. The
overlays -- the CMake written here for libraries that have none -- are part
of this repository and are MIT with the rest of it.
