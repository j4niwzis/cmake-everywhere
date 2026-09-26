"""Turn a configured make project into CMake data.

The third shape of the same idea. A project with a configure script of its
own -- FFmpeg's, which it wrote itself -- has no File API and no
introspection, but it has a build it can describe: `make -n` prints every
command it would run, in order, without running any of them.

So the description is those commands, sorted into the three things they can
be: a compile, an archive, and everything else. A compile says which source,
which flags and which object; an archive says which objects go into which
library; everything else is a custom command that makes a file. That is the
same description cmake_import.py writes, so the targets are made in one
place for all three.

What this does not do is guess. A file that is neither compiled nor
archived -- a header written from a template, assembly written by a perl
script, as OpenSSL makes half of what it compiles -- is made by the
project's own make, one file to a command, in this build's graph: which
files those are, and what each waits for, is read from make's database
(make -p), where every rule is, rather than from the dry run, where a
command is a line with no outputs named.
"""

import os
import re
import shlex
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from cmake_import import emit, quote  # noqa: E402


COMPILED = (".c", ".cc", ".cpp", ".cxx", ".m", ".mm", ".S", ".s", ".asm")

# Which compiler a source is given to, which is not the same question as
# which language it is written in.
#
# Assembly is the case that differs. A project's own build hands its .S
# files to the C compiler -- that is what the command lines read here say --
# and the compiler knows an assembler file when it sees one, running the
# preprocessor over the capital-S ones. Calling it ASM here would instead
# ask the consumer's build for a language it never enabled, and CMake stops
# at generate time over a variable nobody set:
#
#   Missing variable is: CMAKE_ASM_COMPILE_OBJECT
#
# A consumer cannot enable a language for a library it has not looked
# inside, so it is not asked to.
LANGUAGE = {".c": "C", ".cc": "CXX", ".cpp": "CXX", ".cxx": "CXX",
            ".m": "OBJC", ".mm": "OBJCXX", ".S": "C", ".s": "C",
            ".asm": "ASM_NASM"}


def read_commands(path):
    """What make said it would do, one command to a line.

    Line continuations are joined and the lines make prints about itself --
    entering a directory, nothing to be done -- are dropped. A recipe line
    that is several commands separated by && stays one line: it was written
    to be run by one shell and that is how it is run again.
    """
    with open(path) as handle:
        text = handle.read()
    text = re.sub(r"\\\n", " ", text)
    commands = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("make"):
            continue
        commands.append(line)
    return commands


def split(command):
    """A command line as words, or nothing when it is not one shell word."""
    try:
        return shlex.split(command)
    except ValueError:
        return []


def compile_of(words, root):
    """A compile, as the source it reads and the object it writes."""
    if "-c" not in words:
        return None
    source = None
    output = None
    flags = []
    defines = []
    includes = []
    index = 1
    while index < len(words):
        word = words[index]
        index += 1
        if word == "-c":
            continue
        if word == "-o" and index < len(words):
            output = words[index]
            index += 1
            continue
        if word.startswith("-D"):
            defines.append(word[2:])
            continue
        if word.startswith("-I"):
            includes.append(word[2:])
            continue
        # How a project writes down what a source included is that
        # project's business and not this build's: CMake writes its own -MD
        # -MT -MF, and the ones read here would be a second set naming files
        # in a directory this build does not use. Worse, the value of -MF
        # was dropped while the flag was kept, so a flag added after it --
        # the -x that says a .S is assembly -- became its argument, and
        # clang looked for a file called assembler-with-cpp.
        if word in ("-MD", "-MMD", "-MP", "-MG", "-M", "-MM"):
            continue
        if word in ("-MF", "-MT", "-MQ") and index < len(words):
            index += 1
            continue
        if word in ("-I", "-isystem", "-include") and index < len(words):
            if word == "-I":
                includes.append(words[index])
            else:
                flags.extend([word, words[index]])
            index += 1
            continue
        if word.startswith("-"):
            flags.append(word)
            continue
        if os.path.splitext(word)[1] in COMPILED:
            source = word
            continue
    if source is None or output is None:
        return None
    return {"source": os.path.normpath(os.path.join(root, source)),
            "object": os.path.normpath(os.path.join(root, output)),
            "language": LANGUAGE[os.path.splitext(source)[1]],
            "defines": defines,
            "includes": [os.path.normpath(os.path.join(root, i))
                         for i in includes],
            "flags": flags}


def archive_of(words, root):
    """An archive, as the objects that go into it."""
    if not words:
        return None
    name = os.path.basename(words[0])
    # emar among them, which is emscripten's and is spelled without the
    # hyphen every other prefixed one has: without it a wasm build read 282
    # compiles and no archives at all, and the port was told it produces a
    # library its own description does not contain.
    known = ("ar", "gcc-ar", "llvm-ar", "emar")
    if name not in known and not name.endswith("-ar"):
        return None
    output = None
    objects = []
    for word in words[1:]:
        if word.startswith("-"):
            continue
        if word.endswith(".a") and output is None:
            output = word
            continue
        if word.endswith(".o"):
            objects.append(os.path.normpath(os.path.join(root, word)))
    if output is None:
        return None
    return {"archive": os.path.normpath(os.path.join(root, output)),
            "objects": objects}


def read_rules(path):
    """make's database: each file target with what it needs, whether it has
    a recipe, and whether it is phony; and the default goal.

    Only the section of files, and only what make says is a target: a line
    under "# Not a target:" is a file some rule named, not a rule.
    """
    rules = {}
    goal = None
    with open(path, errors="replace") as handle:
        lines = handle.read().splitlines()
    in_files = False
    not_a_target = False
    current = None
    for line in lines:
        if line.startswith(".DEFAULT_GOAL :="):
            goal = line.split(":=", 1)[1].strip()
            continue
        if line.startswith("# Files"):
            in_files = True
            continue
        if line.startswith("# files hash-table stats") or line.startswith("# VPATH Search Paths"):
            in_files = False
            current = None
            continue
        if not in_files:
            continue
        if line.startswith("# Not a target:"):
            not_a_target = True
            continue
        if line.startswith("\t"):
            if current is not None:
                rules[current]["recipe"] = True
            continue
        if line.startswith("#"):
            if current is not None and "Phony target" in line:
                rules[current]["phony"] = True
            continue
        if not line.strip():
            current = None
            continue
        match = re.match(r"^([^:#=\s][^:=]*?)::?(?![=])(.*)$", line)
        if not match:
            current = None
            continue
        if not_a_target:
            not_a_target = False
            current = None
            continue
        targets = match.group(1).split()
        needs = match.group(2).replace("|", " ").split()
        for target in targets:
            one = rules.setdefault(target, {"needs": [], "recipe": False, "phony": False})
            one["needs"] += needs
        current = targets[0] if len(targets) == 1 else None
    return rules, goal


def generated_files(rules, goal, build):
    """What make would make that is not an object or an archive: every file
    target reachable from the default goal that has a recipe and is not
    there yet."""
    made = []
    seen = set()
    pending = [goal] if goal else []
    while pending:
        one = pending.pop()
        if one in seen:
            continue
        seen.add(one)
        rule = rules.get(one)
        if rule is None:
            continue
        pending.extend(rule["needs"])
        if rule["phony"] or not rule["recipe"] or "%" in one:
            continue
        if one.endswith((".o", ".a", ".so", ".obj", ".lib", ".d")) or ".so." in one:
            continue
        if os.path.exists(os.path.join(build, one)):
            continue
        made.append(one)
    return made


def main(argv):
    if len(argv) not in (4, 6):
        sys.stderr.write("usage: make_import.py <dry-run> <build-dir> <out> [<rules> <make>]\n")
        return 2
    dry, build, output = argv[1], os.path.abspath(argv[2]), argv[3]
    rules, goal, make = {}, None, None
    if len(argv) == 6:
        rules, goal = read_rules(argv[4])
        make = argv[5]

    compiles = {}
    archives = {}
    other = []
    for command in read_commands(dry):
        words = split(command)
        one = compile_of(words, build)
        if one:
            compiles[one["object"]] = one
            continue
        # One archive, however many commands add to it: OpenSSL makes
        # libcrypto.a with several, each appending what the one before did
        # not.
        one = archive_of(words, build)
        if one:
            kept = archives.setdefault(one["archive"], [])
            kept.extend(o for o in one["objects"] if o not in kept)
            continue
        other.append(command)

    # A target is an archive, and its sources are the sources of the objects
    # in it. An object nothing archives belongs to no target here.
    targets = []
    for path_of_archive, objects in archives.items():
        archive = {"archive": path_of_archive, "objects": objects}
        name = os.path.basename(archive["archive"])
        name = re.sub(r"^lib|\.a$", "", name)
        groups = {}
        for path in archive["objects"]:
            one = compiles.get(path)
            if one is None:
                continue
            key = (one["language"], tuple(one["defines"]),
                   tuple(one["includes"]), tuple(one["flags"]))
            groups.setdefault(key, []).append(one["source"])
        if not groups:
            continue
        targets.append({"name": name, "archive": archive["archive"],
                        "groups": groups})

    with open(output, "w") as handle:
        handle.write("# Written by make_import.py from a make dry run.\n")
        handle.write("# Anything edited here is overwritten.\n\n")
        handle.write("set(CMAKE_IMPORT_SOURCE {})\n".format(quote(build)))
        handle.write("set(CMAKE_IMPORT_BUILD {})\n\n".format(quote(build)))
        emit(handle, "CMAKE_IMPORT_TARGETS", [t["name"] for t in targets])
        handle.write("\n")

        for target in targets:
            prefix = "CMAKE_IMPORT_{}".format(
                re.sub(r"[^A-Za-z0-9_]", "_", target["name"]))
            sources = []
            for files in target["groups"].values():
                sources.extend(files)
            handle.write("# {}\n".format(target["name"]))
            handle.write("set({}_NAME {})\n".format(prefix,
                                                    quote(target["name"])))
            handle.write("set({}_TYPE \"STATIC_LIBRARY\")\n".format(prefix))
            emit(handle, prefix + "_SOURCES", sources)
            handle.write("set({}_GROUPS {})\n".format(prefix,
                                                      len(target["groups"])))
            for index, key in enumerate(target["groups"]):
                language, defines, includes, flags = key
                emit(handle, "{}_GROUP{}_LANGUAGE".format(prefix, index),
                     [language])
                emit(handle, "{}_GROUP{}_DEFINES".format(prefix, index),
                     list(defines))
                emit(handle, "{}_GROUP{}_INCLUDES".format(prefix, index),
                     list(includes))
                emit(handle, "{}_GROUP{}_FLAGS".format(prefix, index),
                     list(flags))
            emit(handle, prefix + "_LINK", [])
            emit(handle, prefix + "_LINK_GROUP", [])
            emit(handle, prefix + "_DEPENDS", [])
            emit(handle, prefix + "_ARTIFACTS", [target["archive"]])
            handle.write("\n")

        emit(handle, "CMAKE_IMPORT_ARTIFACT_PATHS",
             [t["archive"] for t in targets])
        emit(handle, "CMAKE_IMPORT_ARTIFACT_OWNERS",
             [t["name"] for t in targets])
        handle.write("\n")
        # The files made some other way, each by the project's make, run for
        # that file alone, from its build directory, after what it needs.
        generated = generated_files(rules, goal, build) if make else []
        known = set(generated)
        handle.write("set(CMAKE_IMPORT_COMMANDS {})\n".format(len(generated)))
        for index, one in enumerate(generated):
            prefix = "CMAKE_IMPORT_COMMAND{}".format(index)
            inputs = []
            for need in rules[one]["needs"]:
                if need in known or os.path.exists(os.path.join(build, need)):
                    inputs.append(os.path.normpath(os.path.join(build, need)))
            emit(handle, prefix + "_OUTPUTS", [os.path.normpath(os.path.join(build, one))])
            emit(handle, prefix + "_INPUTS", inputs)
            handle.write("set({}_LINE {})\n".format(
                prefix, quote("{} --no-print-directory V=1 {}".format(shlex.quote(make), shlex.quote(one)))))
            handle.write("set({}_DESC {})\n".format(prefix, quote("making " + one)))
        emit(handle, "CMAKE_IMPORT_GENERATED_BY_TOOLS", [])

    sys.stderr.write(
        "make_import: {} targets, {} compiles, {} files made by make, "
        "{} commands not read\n".format(
            len(targets), len(compiles), len(generated), len(other)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
