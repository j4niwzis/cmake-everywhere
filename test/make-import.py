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
ar rc libavutil/libavutil.a libavutil/mem.o libavutil/log.o
ar rc libavcodec/libavcodec.a libavcodec/dct.o
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
        result = subprocess.run([sys.executable, IMPORTER, dry, build, out],
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
                      os.path.join(build, "libavutil", "log.c")]))
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

    for problem in problems:
        print(problem)
    print("{} checks, {} problems".format(6, len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
