#!/usr/bin/env python3
"""Write a port for every Boost library, out of what Boost already declares.

Boost is one release cut into 158 repositories, and every one of them says
in its own CMakeLists which targets it defines and which of the others it
links. That is the dependency graph, kept by the people who change it, so it
is read rather than copied: this writes registry/boost-<library>/port.cmake
from it, and the umbrella registry/boost/port.cmake beside them.

    python3 tools/boost-ports.py 1.92.0

A generated port is a port like any other -- nothing reads them differently
-- and this is run again when Boost is released, not maintained by hand.
"""
import concurrent.futures as futures
import json
import os
import re
import sys
import urllib.request

RAW = "https://raw.githubusercontent.com/boostorg"
RELEASES = "https://api.github.com/repos/boostorg/boost/releases/tags/boost-"
ARCHIVE = "boost-{version}-cmake.tar.xz"
# Two targets that are made by a function or by the superproject rather than
# by a plain add_library, so the file that defines them does not say so in a
# form this can read. Named here rather than dropped silently.
ALIASES = {"disable_autolinking": "config", "numeric_conversion": "numeric/conversion"}

# Libraries Boost itself will not build unless it is told the machine has
# what they need: BOOST_ENABLE_MPI and BOOST_ENABLE_PYTHON, both off by
# default. The lists are Boost's own, in boostorg/cmake.
#
# They are ports like any other and can be asked for by name. What they are
# not is a dependency of anything: odeint mentions Boost::mpi inside
# if(BOOST_ENABLE_MPI), and every reference in a file is a reference whether
# or not the branch it is in is taken -- so reading them as dependencies had
# odeint building MPI, and MPI failing on a header no machine here has.
BY_ARRANGEMENT = ["mpi", "graph_parallel", "property_map_parallel",
                  "python", "parameter_python"]


def fetch(url):
    with urllib.request.urlopen(url, timeout=60) as answer:
        return answer.read().decode()


def archive(version):
    """The one download that all of it is inside, and its digest, as the
    release itself publishes them."""
    release = json.loads(fetch(RELEASES + version))
    wanted = ARCHIVE.format(version=version)
    for asset in release["assets"]:
        if asset["name"] == wanted:
            digest = asset.get("digest", "")
            if not digest.startswith("sha256:"):
                raise SystemExit(f"{wanted} has no sha256 in the release")
            return asset["browser_download_url"], digest.split(":", 1)[1]
    raise SystemExit(f"the {version} release has no {wanted}")


def libraries(version):
    """Each library, and the repository it is in.

    The two are not always the same word: libs/numeric/conversion is
    boostorg/numeric_conversion, and taking the last part of the path would
    have cloned boostorg/conversion, which is a different repository that
    defines a differently named target. The .gitmodules file says which is
    which, so it is read rather than guessed at.
    """
    text = fetch(f"{RAW}/boost/boost-{version}/.gitmodules")
    found = {}
    for path, url in re.findall(r"path = libs/(\S+)\s+url = (\S+)", text):
        found[path] = url.rstrip("/").split("/")[-1].removesuffix(".git")
    return found


def cmakelists(version, modules):
    def one(module):
        try:
            return module, fetch(f"{RAW}/{modules[module]}/boost-{version}/CMakeLists.txt")
        except Exception as trouble:            # noqa: BLE001
            return module, f"# unreadable: {trouble}"
    with futures.ThreadPoolExecutor(16) as pool:
        return dict(pool.map(one, modules))


# The component name a project writes when the library is not called that.
# Boost.Test is the one: the module is test and the library everybody links
# is unit_test_framework, with two more beside it that FindBoost has always
# known by name.
PRIMARY = {"test": "unit_test_framework"}

# What a library needs that it does not say in Boost's own vocabulary, and
# what has to be decided for it because it cannot be found out.
#
# Boost.Iostreams looks for zlib, bzip2, lzma and zstd with find_package, so
# those arrive through the provider like anything else -- but it then asks
# whether liblzma has multithreading by compiling a program against
# LibLZMA::LibLZMA, and a try_compile is a separate project that cannot see a
# target this build is going to produce. A library built from source cannot
# answer a configure-time link probe; that is true of every such probe and
# not only this one. So the answer is given rather than measured, and it is
# the one that costs a feature rather than the one that costs a build: no
# multithreaded lzma.
EXTRA = {
    "iostreams": {
        "DEPENDS": ["zlib", "xz"],
        "OPTIONS": ['"BOOST_IOSTREAMS_HAS_LZMA_CPUTHREADS 0"'],
    },
}
ALSO = {"test": ["prg_exec_monitor", "test_exec_monitor"]}

# What somebody will otherwise work out again from the graph. Written into
# the port beside the dependencies it explains.
NOTES = {
    "asio": """# Boost::asio is three libraries: asio_core, which needs align, assert,
# config, system and throw_exception; asio_deadline_timer, which adds
# date_time; and asio_spawn, which adds context for stackful coroutines.
# Boost::asio itself is all three.
#
# Which of them Boost::asio is made of is a feature here, and the two that
# cost another library are off unless they are asked for. Linking
# Boost::asio_core instead would be the other way to say it, but it is not a
# way anything gets to choose: Beast names Boost::asio, and a project that
# uses Beast over a socket was building Boost.Context -- assembly per
# architecture -- for coroutines nothing in it calls.""",
}

# A library that is more than one library.
#
# Boost.Asio is four targets upstream: a core, deadline_timer, spawn, and one
# that is all of them. Only the last two need anything beyond the core --
# Date_Time for the timer, Context for the stackful coroutines -- and a
# project that names Boost::asio, which is what everything names, was
# building both.
#
# Each part is a port, so what a project asks for is what it gets and what it
# links keeps the name upstream gave it: Boost::asio is still all of Asio,
# and a project that expects Context from it still has Context. The parts
# share one download and one directory and are built separately, because a
# build with no Boost.Context in it cannot produce the target that links
# Boost.Context.
#
#   module: (patch, core target, [(feature, target, modules, switch)])
SPLIT = {
    "asio": (
        "0001-let-a-build-say-which-parts-of-asio-it-wants.patch",
        "asio_core",
        [
            ("deadline_timer", "asio_deadline_timer", ["date_time"],
             "BOOST_ASIO_DEADLINE_TIMER"),
            ("spawn", "asio_spawn", ["context"], "BOOST_ASIO_SPAWN"),
        ],
    ),
}


def made_by_hand(stripped):
    """Targets a file makes with a function of its own.

    Boost.Test writes add_library(boost_${name}) inside a function and then
    calls it three times. The names are in the calls, so they are read from
    there rather than from a list kept here.
    """
    made = set()
    for name, body in re.findall(r"function\(\s*(\w+)[^)]*\)(.*?)endfunction\(", stripped, re.S):
        if not re.search(r"add_library\(\s*boost_\$\{", body):
            continue
        for call in re.findall(rf"^\s*{name}\(\s*([A-Za-z0-9_]+)", stripped, re.M):
            made.add(call)
    return made


def graph(sources):
    """Which module defines which target, and which modules each one links."""
    defines, references, interface = {}, {}, {}
    for module, text in sources.items():
        stripped = re.sub(r"#[^\n]*", "", text)
        defines[module] = set(re.findall(r"add_library\(\s*boost_([A-Za-z0-9_]+)", stripped))
        defines[module] |= made_by_hand(stripped)
        # Header-only or compiled, which is what decides whether a machine
        # has this library as a thing of its own. A distribution installs a
        # config file for what it compiled and nothing for what is only
        # headers, so only the compiled ones are components in its
        # vocabulary.
        interface[module] = bool(re.search(
            r"add_library\(\s*boost_[A-Za-z0-9_]+\s+INTERFACE", stripped))
        references[module] = set(re.findall(r"Boost::([A-Za-z0-9_]+)", stripped))
    owner = {}
    for module, targets in defines.items():
        for target in targets:
            owner.setdefault(target, module)
    for name, module in ALIASES.items():
        owner.setdefault(name, module)

    unresolved = set()
    edges = {}
    for module in sources:
        needs = set()
        for target in references[module]:
            where = owner.get(target)
            if where is None:
                # A sub-target made by a function: boost_stacktrace_${suffix}
                # is stacktrace's, and the prefix is the only thing that says
                # so.
                for candidate in sorted(defines, key=len, reverse=True):
                    leaf = candidate.split("/")[-1]
                    if target.startswith(leaf + "_"):
                        where = candidate
                        break
            if where is None:
                if target != "boost":
                    unresolved.add(target)
                continue
            # An edge into one of those is dropped, unless it comes from
            # one of them: property_map_parallel links Boost::mpi and means
            # it, which is why they are a set rather than a list of things
            # nobody may depend on.
            if where == module:
                continue
            if key(where) in BY_ARRANGEMENT and key(module) not in BY_ARRANGEMENT:
                continue
            needs.add(where)
        edges[module] = sorted(needs)
    return edges, defines, unresolved, interface


def key(module):
    return module.replace("/", "_")


def port(module):
    return "boost-" + key(module).replace("_", "-")


def target(module, defines):
    """The one a consumer links: the target named after the library."""
    if module in PRIMARY:
        return PRIMARY[module]
    name = key(module)
    if name in defines[module]:
        return name
    leaf = module.split("/")[-1]
    if leaf in defines[module]:
        return leaf
    return sorted(defines[module], key=len)[0] if defines[module] else name


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as file:
        file.write(text)


def main(version):
    major, minor, patch = (version.split(".") + ["0", "0"])[:3]
    macro = int(major) * 100000 + int(minor) * 100 + int(patch)
    url, digest = archive(version)
    modules = libraries(version)
    sources = cmakelists(version, modules)
    edges, defines, unresolved, interface = graph(sources)
    # The parts a library only links for a piece of itself are not
    # dependencies of the library, so they are not in the graph the ports and
    # the umbrella are written from.
    for module, (_, _, pieces) in SPLIT.items():
        if module not in edges:
            continue
        moved = {name for _, _, names, _ in pieces for name in names}
        edges[module] = [other for other in edges[module] if other not in moved]
    if unresolved:
        print("targets nothing was found to define:", ", ".join(sorted(unresolved)))

    for module in modules:
        if not defines.get(module):
            print(f"{module}: no library target, no port")
            continue
        name = target(module, defines)
        # A library that needs something of the machine's, said in the port
        # rather than left for the build to discover. Boost will not build
        # these unless it is told, and nothing that lists all of Boost should
        # list them.
        arrangement = ""
        if key(module) in BY_ARRANGEMENT:
            switch = "BOOST_ENABLE_PYTHON" if "python" in key(module) \
                     else "BOOST_ENABLE_MPI"
            arrangement = f"\n  ARRANGEMENT {switch}"
        depends = " ".join(port(other) for other in edges[module])
        extra = EXTRA.get(module, {})
        if extra.get("DEPENDS"):
            depends = (depends + " " + " ".join(extra["DEPENDS"])).strip()
        added = ""
        if depends:
            added += f"\n  DEPENDS {depends}"
        if extra.get("OPTIONS"):
            added += "\n  OPTIONS " + " ".join(extra["OPTIONS"])
        split = SPLIT.get(module)
        switches = ""
        patches = ""
        virtual = ""
        if split:
            _, core_target, pieces = split
            # The whole of the library is its parts, and it says so by naming
            # them. Which feature a part is turned on by is the part'''s own
            # business and is written down once, where the part is; naming
            # the features here would be the same knowledge in two places,
            # and a graph that says asio is made of a core rather than of the
            # parts it is actually made of.
            wanted = " ".join(
                f"{port(module)}-{feature.replace('_', '-')}"
                for feature, _, _, _ in pieces)
            added = f"\n  DEPENDS {wanted}"
            virtual = "\n  VIRTUAL YES"
        note = NOTES.get(module, "")
        if note:
            note = "#\n" + note + "\n"
        text = f"""# Written by tools/boost-ports.py from what boostorg/{modules[module]}
# declares. Do not edit: run the script again.
#
# One library out of Boost, on its own. FAMILY is what keeps it from being
# half of one Boost and half of another: every Boost port in a build is
# answered the same way, from the same place, at the same version.
{note}cme_declare_port(
  NAME {port(module)}
  PROVIDES boost_{key(module)} Boost{key(module).title().replace("_", "")}
  VERSION {version}
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_{key(module)}
  TARGETS Boost::{name}{arrangement}{virtual}{added}{switches}{patches}
)

# Where the sources come from, which is the one thing about a Boost library
# that is worth a choice. One repository each is the small download when a
# project uses one or two of them; the release archive is one download of
# everything, which is faster from about the tenth library and is the whole
# of it either way.
if(CME_BOOST_ARCHIVE)
  cme_port_source({port(module)}
    SOURCE_FROM boost-archive SOURCE_SUBDIR libs/{module})
else()
  cme_port_source({port(module)}
    GITHUB_REPOSITORY boostorg/{modules[module]}
    GIT_TAG boost-{version}
    GIT_TAG_TEMPLATE "boost-@VERSION@")
endif()
"""
        write(f"registry/{port(module)}/port.cmake", text)

        if not split:
            continue

        # The library itself: built once, with a feature per part. The parts
        # are its own targets upstream, so what a feature adds is a target
        # and what it costs is the library that target links.
        patch, core_target, pieces = split
        core = f"{port(module)}-core"
        core_depends = " ".join(port(other) for other in edges[module])
        core_switches = " ".join(
            f'"{switch} OFF"' for _, _, _, switch in pieces)
        features = ""
        for feature, part_target, brings, switch in pieces:
            features += f"""
cme_port_feature({core} {feature}
  SUMMARY "Boost::{part_target}"
  DEFAULT NO
  DEPENDS {" ".join(port(name) for name in brings)}
  OPTIONS "{switch} ON"
  TARGETS Boost::{part_target})
"""
        write(f"registry/{core}/{patch}", open(f"registry/{port(module)}/{patch}").read())
        write(f"registry/{core}/port.cmake", f"""# Written by tools/boost-ports.py. Do not edit: run the script again.
#
# Boost.{key(module).title()}, which upstream builds as four targets: this one, a part
# apiece for the two that need another library, and one that is all of them.
# The parts are features here -- they are built when they are asked for, and
# what they need comes with them -- so a project that asks for the core
# builds neither of the two.
cme_declare_port(
  NAME {core}
  PROVIDES boost_{core_target} Boost{core_target.title().replace("_", "")}
  VERSION {version}
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_{core_target}
  TARGETS Boost::{core_target}
  DEPENDS {core_depends}
  OPTIONS {core_switches}
  PATCHES {patch}
)
{features}
# Where the sources come from, the same choice as every other Boost port.
if(CME_BOOST_ARCHIVE)
  cme_port_source({core}
    SOURCE_FROM boost-archive SOURCE_SUBDIR libs/{module})
else()
  cme_port_source({core}
    GITHUB_REPOSITORY boostorg/{modules[module]}
    GIT_TAG boost-{version}
    GIT_TAG_TEMPLATE "boost-@VERSION@")
endif()
""")
        # And a name for each part, which is the core with that part asked
        # for. Nothing is built and nothing is added: the target it hands
        # back is the one the core produces when the feature is on.
        for feature, part_target, _, _ in pieces:
            part = f"{port(module)}-{feature.replace('_', '-')}"
            write(f"registry/{part}/port.cmake", f"""# Written by tools/boost-ports.py. Do not edit: run the script again.
#
# A name for one part of Boost.{key(module).title()}: the library with that part asked
# for. It builds nothing -- the part is a feature of {core}, and the
# target below is what that port produces when it is on.
cme_declare_port(
  NAME {part}
  PROVIDES boost_{part_target} Boost{part_target.title().replace("_", "")}
  VERSION {version}
  VIRTUAL YES
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_{part_target}
  TARGETS Boost::{part_target}
  DEPENDS {core}[{feature}]
)
""")

    # A component brings the components it is built on. The member ports say
    # the same thing in their DEPENDS, and saying it here too is not a
    # duplicate: a project that refuses a component and asks for one that
    # needs it has to be told, and a refusal that is quietly worked around by
    # a dependency further down is not a refusal.
    def implied(module):
        names = " ".join(target(other, defines) for other in edges[module]
                         if defines.get(other))
        return f"\n  IMPLIES {names}" if names else ""

    write("registry/boost-archive/port.cmake", f"""# Written by tools/boost-ports.py. Do not edit: run the script again.
#
# All of Boost as it is published, in one file. Nothing is built from this
# port and nothing asks for it by name: it is what the other Boost ports say
# their sources are inside of, when CME_BOOST_ARCHIVE is on.
cme_declare_port(
  NAME boost-archive
  PROVIDES boost_archive
  VERSION {version}
  SOURCE_ONLY YES
  LICENSE BSL-1.0
  URL "{url}"
  URL_HASH "SHA256={digest}"
)
""")

    # A component is what a project writes in find_package(Boost COMPONENTS
    # ...), which is the library's name and not always the module's.
    lines = []
    for module in modules:
        if not defines.get(module):
            continue
        for component in [target(module, defines)] + ALSO.get(module, []):
            separate = "" if interface.get(module) else "\n  SYSTEM_COMPONENT YES"
            lines.append(
                f"cme_port_feature(boost {component}\n"
                f"  SUMMARY \"Boost.{component.replace('_', ' ')}\""
                f"{implied(module)}{separate}\n"
                f"  DEPENDS {port(module)})")
        # The parts of a library that is more than one are components too,
        # so asking for one of them is find_package(Boost COMPONENTS
        # asio_spawn) and nothing else: no call this registry invented.
        split = SPLIT.get(module)
        if split:
            core_target, pieces = split[1], split[2]
            lines.append(
                f"cme_port_feature(boost {core_target}\n"
                f"  SUMMARY \"Boost.{core_target.replace('_', ' ')}\""
                f"{implied(module)}\n"
                f"  DEPENDS {port(module)}-core)")
            for feature, part_target, _, _ in pieces:
                lines.append(
                    f"cme_port_feature(boost {part_target}\n"
                    f"  SUMMARY \"Boost.{part_target.replace('_', ' ')}\""
                    f"{implied(module)}\n"
                    f"  DEPENDS {port(module)}-{feature.replace('_', '-')})")
    features = "\n".join(lines)
    write("registry/boost/port.cmake", f"""# Written by tools/boost-ports.py. Do not edit: run the script again.
#
# Boost as one name, for the projects that write find_package(Boost) and name
# what they use as components. Every component is one of the ports beside
# this one, which is where the library actually comes from; this port is the
# name they are asked for by.
#
# It builds nothing itself. Asking for Boost and no components is asking for
# no Boost libraries, which is what Boost's own CMake does with an empty
# BOOST_INCLUDE_LIBRARIES.
# One download of everything instead of one repository each. Worth it from
# about the tenth Boost library a build uses, and the same libraries either
# way.
option(CME_BOOST_ARCHIVE
  "Take Boost as the one release archive rather than a repository per library"
  OFF)

cme_declare_port(
  NAME boost
  PROVIDES Boost boost
  VERSION {version}
  VIRTUAL YES
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE Boost
  # What an installed Boost calls the target that is only its headers. A
  # member the installed copy has no separate target for -- every
  # header-only library, on every distribution that ships configs for the
  # compiled ones alone -- is that target.
  SYSTEM_HEADER_TARGET Boost::headers
  TARGETS Boost::boost
)

{features}

# The rest of what find_package(Boost) hands back, which is a good deal more
# than a target. Projects written against FindBoost read these variables and
# nothing else, and a library that only exports targets correctly leaves them
# unset -- which is a build failing on a bare Boost_INCLUDE_DIRS rather than
# on anything to do with Boost.
function(cme_adapt_boost source binary)
  get_property(parts GLOBAL PROPERTY CME_VIRTUAL_PARTS_boost)
  get_property(trees GLOBAL PROPERTY CME_VIRTUAL_TREES_boost)
  cme_enabled_features(boost enabled)

  set(includes "")
  foreach(tree IN LISTS trees)
    if(EXISTS "${{tree}}/include")
      list(APPEND includes "${{tree}}/include")
    endif()
  endforeach()

  # The four that FindBoost makes beside the libraries. Two of them are about
  # linking Boost as shared libraries and one is about MSVC's autolinking;
  # this builds static archives with no autolinking, so they exist, name what
  # they are, and carry nothing.
  #
  # Made here only when nothing else made them. Boost::headers is a library
  # of Boost's own, so when anything asked for it there is already a target
  # by that name -- an alias to a real one, which nothing may set a property
  # on, and which needs nothing set on it because it is the real thing.
  set(made "")
  foreach(name Boost::headers Boost::diagnostic_definitions
               Boost::disable_autolinking Boost::dynamic_linking)
    if(NOT TARGET ${{name}})
      add_library(${{name}} INTERFACE IMPORTED GLOBAL)
      list(APPEND made ${{name}})
    endif()
  endforeach()
  if(includes AND "Boost::headers" IN_LIST made)
    set_property(TARGET Boost::headers PROPERTY
                 INTERFACE_INCLUDE_DIRECTORIES ${{includes}})
  endif()

  cme_export_variable(Boost Boost_FOUND TRUE)
  cme_export_variable(Boost Boost_INCLUDE_DIRS "${{includes}}")
  cme_export_variable(Boost Boost_INCLUDE_DIR "${{includes}}")
  cme_export_variable(Boost Boost_LIBRARIES "${{parts}}")
  cme_export_variable(Boost Boost_LIBRARY_DIRS "")
  cme_export_variable(Boost Boost_VERSION "{version}")
  cme_export_variable(Boost Boost_VERSION_STRING "{version}")
  cme_export_variable(Boost Boost_VERSION_MACRO {macro})
  cme_export_variable(Boost Boost_MAJOR_VERSION {major})
  cme_export_variable(Boost Boost_MINOR_VERSION {minor})
  cme_export_variable(Boost Boost_SUBMINOR_VERSION {patch})
  cme_export_variable(Boost Boost_LIB_VERSION "{major}_{minor}")
  foreach(component IN LISTS enabled)
    string(TOUPPER "${{component}}" upper)
    cme_export_variable(Boost Boost_${{upper}}_FOUND TRUE)
    cme_export_variable(Boost Boost_${{component}}_FOUND TRUE)
  endforeach()

  # Said rather than ignored: this cannot be answered, and a project that
  # asked for it would otherwise link static archives while believing it had
  # shared ones.
  if(DEFINED Boost_USE_STATIC_LIBS AND NOT Boost_USE_STATIC_LIBS)
    message(WARNING
      "cmake-everywhere: this project sets Boost_USE_STATIC_LIBS OFF, and "
      "every library built here is a static archive. What you get is the "
      "static one.")
  endif()
endfunction()
""")
    # The libraries that have broken here, and the ones the other checks
    # already name. A sample is only worth having if it is made of the
    # places things went wrong rather than of the first few alphabetically:
    #
    #   asio, beast, cobalt        a repository whose name is not its path
    #   dll, gil                   a stored entry naming its own target
    #   thread, fiber, process     a stored entry pointing at absent sources
    #   atomic, date-time, chrono  the entries that pointed
    #   iostreams                  a probe a source build cannot answer
    #   locale                     a dependency's tests
    #   numeric-odeint             a reference inside an if
    #   static-string              a library asking for the umbrella mid-build
    #   functional                 a red job that was apt having a bad day
    #   container                  compiled, deep, and under half of Boost
    #   mp11, system, filesystem   what the per-port checks name
    #
    # The umbrella is not here because there is no job for it here: it is a
    # name for other ports rather than a library, and check.yml asks about
    # it, from the archive and from the system.
    SAMPLE = {
        "boost-mp11", "boost-system", "boost-filesystem",
        "boost-asio", "boost-beast", "boost-cobalt", "boost-dll", "boost-gil",
        "boost-thread", "boost-fiber", "boost-process", "boost-atomic",
        "boost-date-time", "boost-chrono", "boost-iostreams", "boost-locale",
        "boost-numeric-odeint", "boost-static-string", "boost-functional",
        "boost-container",
    }

    # And the build that checks them, one job per library, each waiting for
    # the libraries it is built on.
    #
    # A job apiece says which library broke rather than which build did, and
    # the waiting is what keeps one broken leaf from turning into a hundred
    # and fifty red jobs: what is built on it is skipped instead, which is
    # the truth about what was and was not checked.
    def part_jobs(module):
        split = SPLIT.get(module)
        if not split:
            return []
        out = [f"""  {port(module)}-core:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/boost-library
        with:
          port: {port(module)}-core
          package: boost_{split[1]}
          target: Boost::{split[1]}"""]
        for feature, part_target, brings, _ in split[2]:
            part = f"{port(module)}-{feature.replace(chr(95), chr(45))}"
            needs = [f"{port(module)}-core"]
            needs += [port(name) for name in brings if defines.get(name)]
            waits = ""
            if needs:
                waits = "    needs: [" + ", ".join(sorted(needs)) + "]\n"
            out.append(f"""  {part}:
{waits}    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/boost-library
        with:
          port: {part}
          package: boost_{part_target}
          target: Boost::{part_target}""")
        return out

    jobs = []
    for module in modules:
        if not defines.get(module):
            continue
        # No job for a library that needs MPI or Python: a runner has
        # neither, and a red job for a machine that was never going to have
        # what it needs says nothing about the port.
        if key(module) in BY_ARRANGEMENT:
            continue
        needs = [port(other) for other in edges[module] if defines.get(other)]
        waits = ""
        if needs:
            waits = "    needs: [" + ", ".join(sorted(needs)) + "]\n"
        jobs.append(f"""  {port(module)}:
{waits}    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/boost-library
        with:
          port: {port(module)}
          package: boost_{key(module)}
          target: Boost::{target(module, defines)}""")

    def workflow(name, chosen, trigger, why):
        # A job may only wait for a job that is here, so in the sample the
        # waiting is on the sample.
        kept = []
        for module in modules:
            if not defines.get(module) or key(module) in BY_ARRANGEMENT:
                continue
            if chosen is not None and port(module) not in chosen:
                continue
            needs = [port(other) for other in edges[module]
                     if defines.get(other)
                     and (chosen is None or port(other) in chosen)]
            waits = ""
            if needs:
                waits = "    needs: [" + ", ".join(sorted(needs)) + "]\n"
            kept.append(f"""  {port(module)}:
{waits}    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/boost-library
        with:
          port: {port(module)}
          package: boost_{key(module)}
          target: Boost::{target(module, defines)}""")
            # A library that is more than one port is checked part by part.
            # The core is the interesting one: it is what says that asking
            # for it builds neither Boost.Context nor Boost.Date_Time.
            for job in part_jobs(module):
                kept.append(job)
        write(f".github/workflows/{name}.yml", f"""# Written by tools/boost-ports.py. Do not edit: run the script again.
#
# {why}
#
# One job per Boost library, each waiting for the libraries it is built on,
# in the order Boost's own dependency graph gives. A job apiece says which
# library broke rather than which build did; the waiting means a broken leaf
# skips what is above it instead of failing it many times over.
name: {name}

on:
{trigger}  workflow_dispatch:

jobs:
{chr(10).join(kept)}
""")

    # Two of them, because the two things that change are different sizes.
    # A change to the machinery can break Boost, and when it does the places
    # it breaks are the places it has broken before; a change to the ports or
    # to the script that writes them changes all hundred and fifty-three at
    # once, and nothing smaller than all of them says whether that worked.
    #
    # Nothing weekly. The ports name one release by commit and by digest, so
    # a run next Sunday builds exactly what a run today built.
    workflow("boost", SAMPLE,
             """  push:
    paths:
      - 'cmake-everywhere.cmake'
      - 'cmake/**'
      - '.github/actions/boost-library/**'
      - '.github/workflows/boost.yml'
""",
             "The Boost libraries that have broken here, for a change to the "
             "machinery rather than to the ports.")
    workflow("boost-all", None,
             """  push:
    paths:
      - 'registry/boost*/**'
      - 'tools/boost-ports.py'
      - '.github/workflows/boost-all.yml'
""",
             "Every Boost library there is a port for, for a change to the "
             "ports or to the script that writes them.")

    print(f"{sum(1 for m in modules if defines.get(m))} ports, the umbrella, "
          f"and a job for each, at {version}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "1.92.0")
