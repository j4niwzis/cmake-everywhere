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
    text = fetch(f"{RAW}/boost/boost-{version}/.gitmodules")
    return re.findall(r"path = libs/(\S+)", text)


def cmakelists(version, modules):
    def one(module):
        leaf = module.split("/")[-1]
        try:
            return module, fetch(f"{RAW}/{leaf}/boost-{version}/CMakeLists.txt")
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
    defines, references = {}, {}
    for module, text in sources.items():
        stripped = re.sub(r"#[^\n]*", "", text)
        defines[module] = set(re.findall(r"add_library\(\s*boost_([A-Za-z0-9_]+)", stripped))
        defines[module] |= made_by_hand(stripped)
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
            if where != module:
                needs.add(where)
        edges[module] = sorted(needs)
    return edges, defines, unresolved


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
    edges, defines, unresolved = graph(sources)
    if unresolved:
        print("targets nothing was found to define:", ", ".join(sorted(unresolved)))

    for module in modules:
        if not defines.get(module):
            print(f"{module}: no library target, no port")
            continue
        name = target(module, defines)
        depends = " ".join(port(other) for other in edges[module])
        text = f"""# Written by tools/boost-ports.py from what boostorg/{module.split("/")[-1]}
# declares. Do not edit: run the script again.
#
# One library out of Boost, on its own. FAMILY is what keeps it from being
# half of one Boost and half of another: every Boost port in a build is
# answered the same way, from the same place, at the same version.
cme_declare_port(
  NAME {port(module)}
  PROVIDES boost_{key(module)} Boost{key(module).title().replace("_", "")}
  VERSION {version}
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_{key(module)}
  TARGETS Boost::{name}
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
    GITHUB_REPOSITORY boostorg/{module.split("/")[-1]}
    GIT_TAG boost-{version}
    GIT_TAG_TEMPLATE "boost-@VERSION@")
endif()
"""
        extra = EXTRA.get(module, {})
        if extra.get("DEPENDS"):
            depends = (depends + " " + " ".join(extra["DEPENDS"])).strip()
        added = ""
        if depends:
            added += f"  DEPENDS {depends}\n"
        if extra.get("OPTIONS"):
            added += "  OPTIONS " + " ".join(extra["OPTIONS"]) + "\n"
        if added:
            text = text.replace("  TARGETS Boost::" + name + "\n",
                                f"  TARGETS Boost::{name}\n{added}")
        write(f"registry/{port(module)}/port.cmake", text)

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
            lines.append(
                f"cme_port_feature(boost {component}\n"
                f"  SUMMARY \"Boost.{component.replace('_', ' ')}\"{implied(module)}\n"
                f"  DEPENDS {port(module)})")
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
  foreach(name Boost::headers Boost::diagnostic_definitions
               Boost::disable_autolinking Boost::dynamic_linking)
    if(NOT TARGET ${{name}})
      add_library(${{name}} INTERFACE IMPORTED GLOBAL)
    endif()
  endforeach()
  if(includes)
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
    print(f"{sum(1 for m in modules if defines.get(m))} ports and the umbrella, at {version}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "1.92.0")
