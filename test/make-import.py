"""What make_import.py makes of a dry run, without make.

The commands a project would run are written here by hand -- a compile, an
archive, a generated file, a line make prints about itself -- and what comes
out is checked against what they mean. No compiler, no make, no project.
"""
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
IMPORTER = os.path.join(HERE, "..", "cmake", "make_import.py")

DRY = """make: Entering directory '/b'
cc -I. -I@BUILD@/libavutil -DHAVE_AV_CONFIG_H -O3 -std=c11 -c -o libavutil/mem.o @BUILD@/libavutil/mem.c
cc -I. -DHAVE_AV_CONFIG_H -O3 -std=c11 -c -o libavutil/log.o @BUILD@/libavutil/log.c
c++ -I. -O2 -c -o libavcodec/dct.o @BUILD@/libavcodec/dct.cc
./version.sh @BUILD@ libavutil/ffversion.h
cc -I. -DHAVE_AV_CONFIG_H -O3 -std=c11 -c -o libavutil/extra.o @BUILD@/libavutil/extra.c
ar rc libavutil/libavutil.a libavutil/mem.o libavutil/log.o
ar rc libavcodec/libavcodec.a libavcodec/dct.o
ar r libavutil/libavutil.a libavutil/extra.o
"""

# What make -p says of the same project: the default goal, a phony target,
# a header made by a script from a file that is there, and a file that is
# named and is not a target.
RULES = """# GNU Make 4.3
.DEFAULT_GOAL := all
# Files

all: libavutil/libavutil.a libavutil/ffversion.h
#  Phony target (prerequisite of .PHONY).
#  Implicit rule search has not been done.

libavutil/ffversion.h: version.sh
#  Implicit rule search has not been done.
#  recipe to execute (from 'Makefile', line 9):
\t./version.sh . libavutil/ffversion.h

# Not a target:
version.sh:
#  Implicit rule search has not been done.

libavutil/libavutil.a: libavutil/mem.o libavutil/log.o
#  recipe to execute (from 'Makefile', line 12):
\tar rc $@ $^

# files hash-table stats:
"""


def written(path):
    values = {}
    for match in re.finditer(r"^set\((\S+)([^\n]*)\)$", open(path).read(), re.M):
        values[match.group(1)] = re.findall(r'"((?:\\.|[^"\\])*)"', match.group(2))
    return values


def main():
    problems = []
    with tempfile.TemporaryDirectory() as root:
        build = os.path.join(root, "build")
        os.makedirs(build)
        dry = os.path.join(root, "dry.txt")
        with open(dry, "w") as handle:
            handle.write(DRY.replace("@BUILD@", build))
        out = os.path.join(root, "targets.cmake")
        rules = os.path.join(root, "rules.txt")
        with open(rules, "w") as handle:
            handle.write(RULES)
        open(os.path.join(build, "version.sh"), "w").close()
        result = subprocess.run([sys.executable, IMPORTER, dry, build, out, rules, "/usr/bin/make"],
                                stderr=subprocess.PIPE)
        if result.returncode != 0:
            print(result.stderr.decode())
            return 1
        said = result.stderr.decode().strip()
        values = written(out)

        def check(what, got, want):
            if got != want:
                problems.append("{}:\n  is   {}\n  want {}".format(what, got, want))

        check("an archive is a target, named as the library is",
              sorted(values["CMAKE_IMPORT_TARGETS"]), ["avcodec", "avutil"])
        check("its sources are the sources of the objects in it",
              sorted(values["CMAKE_IMPORT_avutil_SOURCES"]),
              sorted([os.path.join(build, "libavutil", "mem.c"),
                      os.path.join(build, "libavutil", "log.c"),
                      os.path.join(build, "libavutil", "extra.c")]))
        # A count is written as a number rather than a string, so it is
        # looked for as one.
        if "set(CMAKE_IMPORT_avutil_GROUPS 2)" not in open(out).read():
            problems.append("two objects compiled with different -I are one "
                            "group, and their flags would be the union")
        check("the language comes from the source",
              values["CMAKE_IMPORT_avcodec_GROUP0_LANGUAGE"], ["CXX"])
        check("defines are read out of the command",
              values["CMAKE_IMPORT_avcodec_GROUP0_DEFINES"], [])
        check("the archive is where the target says it is",
              values["CMAKE_IMPORT_avutil_ARTIFACTS"],
              [os.path.join(build, "libavutil", "libavutil.a")])
        if "1 commands not read" not in said:
            problems.append("a command that is neither a compile nor an "
                            "archive was not counted: " + said)
        check("a file made some other way is made by make, from the build directory",
              values.get("CMAKE_IMPORT_COMMAND0_OUTPUTS"), [os.path.join(build, "libavutil", "ffversion.h")])
        check("and after what it needs",
              values.get("CMAKE_IMPORT_COMMAND0_INPUTS"), [os.path.join(build, "version.sh")])
        check("by the project's make, for that file alone",
              values.get("CMAKE_IMPORT_COMMAND0_LINE"), ["/usr/bin/make --no-print-directory V=1 libavutil/ffversion.h"])
        if "set(CMAKE_IMPORT_COMMANDS 1)" not in open(out).read():
            problems.append("an archive or a phony target was taken for a file to make")

    for problem in problems:
        print(problem)
    print("{} checks, {} problems".format(10, len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
