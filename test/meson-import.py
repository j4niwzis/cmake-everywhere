"""What meson_import.py makes of an answer, without meson.

The importer is read once and believed forever after, which is how it went
the last few times: it wrote nothing, or wrote a link against `csrD`, and
the build said something else. So the answer a Meson project gives is
written here by hand -- every shape that has to be handled at least once --
and what comes out of the importer is checked against what it means.

Nothing is compiled, nothing is downloaded, and meson is not needed, so
this runs everywhere in a second.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
IMPORTER = os.path.join(HERE, "..", "cmake", "meson_import.py")

TARGETS = [
    # A static library with sources of its own: parameters that are
    # defines, include directories and flags, and an ar command line whose
    # letters name no library.
    {"name": "basic", "id": "libbasic@sta", "type": "static library",
     "filename": ["@BUILD@/libbasic.a"], "depends": [],
     "target_sources": [
         {"language": "c", "compiler": ["cc"],
          "parameters": ["-Ibasic.p", "-I@SOURCE@/src", "-D_GNU_SOURCE",
                         "-D", "PACKAGE=1", "-isystem", "@BUILD@/incoming",
                         "-O2", "-include", "@BUILD@/config.h"],
          "sources": ["@SOURCE@/src/basic.c"], "generated_sources": []},
         {"linker": ["ar"], "parameters": ["csrD"]}]},
    # A static library built from a generated source, and against another
    # static library.
    {"name": "systemd_static", "id": "libsystemd@sta", "type": "static library",
     "filename": ["libsystemd_static.a"], "depends": ["gperf@cus"],
     "target_sources": [
         {"language": "c", "compiler": ["cc"], "parameters": ["-Isd.p"],
          "sources": ["@SOURCE@/src/sd-bus.c"],
          "generated_sources": ["@BUILD@/gperf.c"]},
         {"linker": ["ar"], "parameters": ["csrD"]}]},
    # A library with no sources at all: everything in it comes from the two
    # above, whose objects meson bundles into the archive.
    {"name": "basu", "id": "libbasu@sta", "type": "static library",
     "filename": ["@BUILD@/libbasu.a"], "depends": [], "target_sources": [
         {"linker": ["ar"], "parameters": ["csrD"]}]},
    # An executable, whose linker parameters are the only place a library
    # from outside the project is written down.
    {"name": "basuctl", "id": "basuctl@exe", "type": "executable",
     "filename": ["@BUILD@/basuctl"], "depends": [], "target_sources": [
         {"language": "c", "compiler": ["cc"], "parameters": [],
          "sources": ["@SOURCE@/src/busctl.c"], "generated_sources": []},
         {"linker": ["cc"], "parameters": ["-Wl,--as-needed", "libbasu.a",
                                           "-lrt", "@BUILD@/libextra.so.2"]}]},
    # A custom target: not built here, but what it produces is.
    {"name": "gperf", "id": "gperf@cus", "type": "custom",
     "filename": ["@BUILD@/gperf.c"], "depends": [], "target_sources": []},
    # A target in a language CMake has no compiler for.
    {"name": "rusty", "id": "rusty@sta", "type": "static library",
     "filename": ["@BUILD@/librusty.a"], "depends": [], "target_sources": [
         {"language": "rust", "compiler": ["rustc"], "parameters": [],
          "sources": ["@SOURCE@/src/lib.rs"], "generated_sources": []}]},
]

# Meson's ninja, with one space before a variable and a name to type at a
# build tool that produces no file.
NINJA = """rule CUSTOM_COMMAND
 command = $COMMAND
 description = $DESC

build gperf.c | gperf.h: CUSTOM_COMMAND @SOURCE@/src/keywords.gperf
 COMMAND = gperf @SOURCE@/src/keywords.gperf --output-file gperf.c
 DESC = Generating$ gperf.c$ with$ a$ custom$ command

build meson-internal__test: CUSTOM_COMMAND all meson-test-prereq PHONY
 COMMAND = meson test
 DESC = Running$ all$ tests

build CMakeFiles/install.util: CUSTOM_COMMAND all
 COMMAND = cmake -P cmake_install.cmake
 DESC = Install$ the$ project...

build libbasic.a: STATIC_LINKER libbasic.a.p/basic.c.o
 LINK_ARGS = csrD

build libsystemd_static.a: STATIC_LINKER libsystemd_static.a.p/sd-bus.c.o \
libsystemd_static.a.p/gperf.c.o | libbasic.a
 LINK_ARGS = csrD

build libbasu.a: STATIC_LINKER libbasic.a.p/basic.c.o \
libsystemd_static.a.p/sd-bus.c.o libsystemd_static.a.p/gperf.c.o
 LINK_ARGS = csrD

build basuctl: c_LINKER basuctl.p/busctl.c.o | libbasu.a
 LINK_ARGS = -Wl,--as-needed libbasu.a -lrt
"""


def written(path):
    """What the importer wrote, as names and lists of strings."""
    values = {}
    for match in re.finditer(r"^set\((\S+)([^\n]*)\)$", open(path).read(),
                             re.M):
        values[match.group(1)] = re.findall(r'"((?:\\.|[^"\\])*)"',
                                            match.group(2))
    return values


def main():
    problems = []
    with tempfile.TemporaryDirectory() as root:
        source = os.path.join(root, "source")
        build = os.path.join(root, "build")
        os.makedirs(os.path.join(source, "src"))
        os.makedirs(os.path.join(build, "meson-info"))
        for name in ("basic.c", "sd-bus.c", "busctl.c", "lib.rs"):
            open(os.path.join(source, "src", name), "w").close()
        open(os.path.join(build, "gperf.c"), "w").close()
        open(os.path.join(build, "libextra.so.2"), "w").close()

        def fill(text):
            return text.replace("@SOURCE@", source).replace("@BUILD@", build)

        with open(os.path.join(build, "meson-info", "intro-targets.json"),
                  "w") as handle:
            handle.write(fill(json.dumps(TARGETS)))
        with open(os.path.join(build, "build.ninja"), "w") as handle:
            handle.write(fill(NINJA))

        output = os.path.join(root, "targets.cmake")
        result = subprocess.run(
            [sys.executable, IMPORTER, "meson", build, source, output],
            stderr=subprocess.PIPE)
        if result.returncode != 0:
            print(result.stderr.decode())
            return 1
        said = result.stderr.decode().strip()
        values = written(output)

        def check(what, got, want):
            if got != want:
                problems.append("{}:\n  is   {}\n  want {}".format(
                    what, got, want))

        check("the targets", values["CMAKE_IMPORT_TARGETS"],
              ["basic", "systemd_static", "basu", "basuctl"])
        check("a library with sources is a library",
              values["CMAKE_IMPORT_basic_TYPE"], ["STATIC_LIBRARY"])
        check("a library with none is what its parts are",
              values["CMAKE_IMPORT_basu_TYPE"], ["INTERFACE_LIBRARY"])
        check("and links the targets whose objects it holds",
              sorted(values["CMAKE_IMPORT_basu_LINK"]),
              sorted([os.path.join(build, "libbasic.a"),
                      os.path.join(build, "libsystemd_static.a")]))

        check("defines, both spellings",
              values["CMAKE_IMPORT_basic_GROUP0_DEFINES"],
              ["_GNU_SOURCE", "PACKAGE=1"])
        check("include directories, relative to the build directory",
              values["CMAKE_IMPORT_basic_GROUP0_INCLUDES"],
              [os.path.join(build, "basic.p"),
               os.path.join(source, "src"),
               os.path.join(build, "incoming")])
        check("everything else is a flag, in the order it was given",
              values["CMAKE_IMPORT_basic_GROUP0_FLAGS"],
              ["-O2", "-include", os.path.join(build, "config.h")])
        check("ar's letters are not libraries",
              values["CMAKE_IMPORT_basic_LINK"], [])

        check("a generated source is a source",
              values["CMAKE_IMPORT_systemd_static_SOURCES"],
              [os.path.join(source, "src", "sd-bus.c"),
               os.path.join(build, "gperf.c")])
        check("an archive against an archive",
              values["CMAKE_IMPORT_systemd_static_LINK"],
              [os.path.join(build, "libbasic.a")])
        check("what a custom target makes is depended on by name",
              values["CMAKE_IMPORT_systemd_static_DEPENDS"], ["gperf"])

        check("a library this project builds, named as a file",
              values["CMAKE_IMPORT_basuctl_LINK"],
              [os.path.join(build, "libbasu.a"), "-lrt",
               os.path.join(build, "libextra.so.2")])
        check("a linker flag is not a library",
              values["CMAKE_IMPORT_basuctl_LINK_FLAGS"], ["-Wl,--as-needed"])
        check("a link a linker stated has an order",
              values["CMAKE_IMPORT_basuctl_LINK_GROUP"], [])
        check("a link read from an archive has none",
              values["CMAKE_IMPORT_basu_LINK_GROUP"], ["RESCAN"])
        check("and so does an archive built against an archive",
              values["CMAKE_IMPORT_systemd_static_LINK_GROUP"], ["RESCAN"])

        check("one custom command, and not the phony ones",
              values["CMAKE_IMPORT_COMMAND0_OUTPUTS"],
              [os.path.join(build, "gperf.c"),
               os.path.join(build, "gperf.h")])
        check("its description, unescaped",
              values["CMAKE_IMPORT_COMMAND0_DESC"],
              ["Generating gperf.c with a custom command"])
        if "CMAKE_IMPORT_COMMAND1_OUTPUTS" in values:
            problems.append("a name to type at ninja was imported as a "
                            "file: " + str(values["CMAKE_IMPORT_COMMAND1_OUTPUTS"]))
        if "rust" not in said:
            problems.append("a target in a language with no compiler here "
                            "was skipped without saying so: " + said)

    for problem in problems:
        print(problem)
    print("{} checks, {} problems".format(17, len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
