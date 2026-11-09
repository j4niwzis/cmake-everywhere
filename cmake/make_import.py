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


def read_commands(path, build):
    """What make said it would do, one command to a line, each with the
    directory it is run in.

    Line continuations are joined. The lines make prints about itself are
    dropped -- but entering and leaving a directory are read first (make
    is run with -w): a project made recursively, automake's SUBDIRS as
    libX11 has them, runs each directory's commands from that directory,
    and a source named there is named from there. A recipe line that is
    several commands separated by && stays one line: it was written to be
    run by one shell and that is how it is run again.
    """
    with open(path) as handle:
        text = handle.read()
    text = re.sub(r"\\\n", " ", text)
    commands = []
    where = [build]
    for line in text.splitlines():
        line = line.strip()
        entering = re.match(r"^\S*make(\[\d+\])?: Entering directory [`'](.*)'$", line)
        if entering:
            where.append(entering.group(2))
            continue
        if re.match(r"^\S*make(\[\d+\])?: Leaving directory ", line):
            if len(where) > 1:
                where.pop()
            continue
        if not line or line.startswith("make"):
            continue
        commands.append((where[-1], line))
    return commands


def split(command):
    """A command line as words, or nothing when it is not one shell word."""
    try:
        return shlex.split(command)
    except ValueError:
        return []


def assembler(words):
    """Whether a command is NASM's (or yasm's), which assembles a .asm
    without the -c every compiler is given: FFmpeg's make runs
    nasm -f elf64 ... -o x.o x.asm, and read as a compile only where it said
    -c, every .asm of it was dropped while its C still called what they
    define -- ff_tx_fft*_asm_*, undefined at the link."""
    return bool(words) and os.path.basename(words[0]) in ("nasm", "yasm")


LIBTOOL_OPTIONS = ("--tag=", "--silent", "--quiet", "--no-silent", "--verbose", "--preserve-dup-deps")


def libtool_of(command):
    """A libtool command as its mode and the command it wraps.

    automake writes each compile as a shell line around libtool --
    `depbase=...; /bin/bash ../libtool --tag=CC --mode=compile clang ... &&
    mv -f $depbase.Tpo $depbase.Plo` -- so the libtool part is found among
    the line's commands, and what follows its options is the compiler's
    command line, or the link that makes a library of .lo objects."""
    for part in re.split(r"&&|;", command):
        if "--mode=" not in part:
            continue
        words = split(part.strip())
        for index, word in enumerate(words):
            if word.startswith("--mode="):
                mode = word[len("--mode="):]
                rest = words[index + 1:]
                while rest and rest[0].startswith(LIBTOOL_OPTIONS):
                    rest = rest[1:]
                return mode, rest
    return None, []


def libtool_archive_of(words, root):
    """libtool's link of a library (-o libfoo.la), as the archive it stands
    for and what goes into it: its objects (.lo), and the objects of the
    convenience libraries it takes whole (.la, libX11's xcms and xkb)."""
    output = None
    objects = []
    libraries = []
    installed = False
    index = 0
    while index < len(words):
        word = words[index]
        index += 1
        if word == "-o" and index < len(words):
            output = words[index]
            index += 1
            continue
        if word == "-rpath" and index < len(words):
            installed = True
            index += 1
            continue
        if word in ("-version-info", "-version-number", "-release", "-export-symbols", "-export-symbols-regex") and index < len(words):
            index += 1
            continue
        if word.startswith("-"):
            continue
        if word.endswith(".lo") or word.endswith(".o"):
            objects.append(os.path.normpath(os.path.join(root, word)))
        elif word.endswith(".la"):
            libraries.append(os.path.normpath(os.path.join(root, word)))
    if output is None or not output.endswith(".la"):
        return None
    return {"archive": os.path.normpath(os.path.join(root, output[:-3] + ".a")),
            "objects": objects,
            "libraries": [path[:-3] + ".a" for path in libraries],
            # An installed library is linked with -rpath; a convenience
            # library (noinst) without, and only that kind is taken whole.
            "installed": installed}


def compile_of(words, root):
    """A compile, as the source it reads and the object it writes."""
    nasm = assembler(words)
    if "-c" not in words and not nasm:
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
        if nasm:
            # The object format is this build's to say (it says -f for the
            # machine it builds for), and so is whether there is debug
            # information: both dropped, with their values.
            if word in ("-f", "-F") and index < len(words):
                index += 1
                continue
            if word.startswith(("-f", "-F")) and len(word) > 2:
                continue
            # A file included before the source -- FFmpeg's -Pconfig.asm --
            # named from where its make ran, which is not where nasm runs
            # here.
            if word.startswith("-P") and len(word) > 2:
                flags.append("-P" + os.path.normpath(os.path.join(root, word[2:])))
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


# What a compile reads: the files a command made that are worth making
# here. A package description, a perl module or a phony target a make
# never marked as one is not, and running make for one of those is running
# the whole build of that project inside one command.
MADE_FOR_COMPILES = (".h", ".hh", ".hpp", ".hxx", ".inc", ".ipp", ".def",
                     ".c", ".cc", ".cpp", ".cxx", ".s", ".S", ".asm")


def rules_of(make, directory):
    """make's database for one directory's Makefile (make -p -q -n there)."""
    import subprocess
    import tempfile
    with tempfile.NamedTemporaryFile("w+", suffix=".txt", delete=False) as handle:
        path = handle.name
    with open(path, "w") as out:
        # MAKE=true: this directory's rules alone. A recursive make asked
        # for its database runs its sub-makes (-n runs what names $(MAKE)),
        # and theirs came out as this one's, under names relative to
        # another directory (libxcb's bigreq.c, made from the top).
        subprocess.run([make, "-p", "-q", "-n", "--no-print-directory", "V=1", "MAKE=true"],
                       cwd=directory, stdout=out, stderr=subprocess.DEVNULL)
    try:
        return read_rules(path)
    finally:
        os.unlink(path)


def generated_files(rules, goal, build, roots=()):
    """What make would make that a compile reads: every file reachable from
    the default goal, or from what is compiled and archived, that has a
    recipe, is a source or a header, and is not there yet.

    From both, because a project that makes itself recursively -- OpenSSL's
    `all` runs `$(MAKE) _build_libs` -- names its generated headers under
    the goal and its objects' own headers only under the objects."""
    made = []
    seen = set()
    pending = ([goal] if goal else []) + list(roots)
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
        if not one.endswith(MADE_FOR_COMPILES):
            continue
        if os.path.exists(os.path.join(build, one)):
            continue
        made.append(one)
    return made


def archives_made(dry, build):
    """Every library the dry run says a link makes, as a path: libtool's
    -o foo.la in the directory it ran in, and an archiver's foo.a."""
    made = []
    for where, command in read_commands(dry, build):
        mode, wrapped = libtool_of(command)
        if mode == "link":
            one = libtool_archive_of(wrapped, where)
            if one:
                made.append(one["archive"][:-2] + ".la")
            continue
        one = archive_of(split(command), where)
        if one:
            made.append(one["archive"])
    return made


def main(argv):
    if len(argv) == 4 and argv[1] == "--archives":
        for path in archives_made(argv[2], os.path.abspath(argv[3])):
            print(path)
        return 0
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
    whole = {}
    installable = set()
    directories = {build}
    for where, command in read_commands(dry, build):
        directories.add(where)
        mode, wrapped = libtool_of(command)
        if mode == "compile":
            # libtool names the object itself where the command does not
            # (-c foo.c makes foo.lo, in the directory it runs in), as
            # libiconv's hand-written Makefiles leave it to.
            if "-o" not in wrapped:
                sources = [w for w in wrapped if os.path.splitext(w)[1] in COMPILED]
                if sources:
                    stem = os.path.splitext(os.path.basename(sources[-1]))[0]
                    wrapped = wrapped + ["-o", stem + ".lo"]
            one = compile_of(wrapped, where)
            if one:
                compiles[one["object"]] = one
                continue
        if mode == "link":
            one = libtool_archive_of(wrapped, where)
            if one:
                kept = archives.setdefault(one["archive"], [])
                kept.extend(o for o in one["objects"] if o not in kept)
                whole.setdefault(one["archive"], []).extend(one["libraries"])
                if one["installed"]:
                    installable.add(one["archive"])
                continue
        if mode is not None:
            other.append(command)
            continue
        words = split(command)
        one = compile_of(words, where)
        if one:
            compiles[one["object"]] = one
            continue
        # One archive, however many commands add to it: OpenSSL makes
        # libcrypto.a with several, each appending what the one before did
        # not.
        one = archive_of(words, where)
        if one:
            kept = archives.setdefault(one["archive"], [])
            kept.extend(o for o in one["objects"] if o not in kept)
            continue
        other.append(command)

    # A convenience library (libtool's noinst .la) is not a target of its
    # own: its objects are in every library that takes it.
    # An installed library it names is not taken whole: it is what it links
    # (libxcb-xkb.la names libxcb.la), said as its link.
    convenience = set()
    links = {}
    for archive, libraries in whole.items():
        pending = list(libraries)
        while pending:
            library = pending.pop()
            if library not in archives:
                continue
            if library in installable:
                links.setdefault(archive, []).append(library)
                continue
            convenience.add(library)
            kept = archives[archive]
            kept.extend(o for o in archives[library] if o not in kept)
            pending.extend(whole.get(library, []))
    for library in convenience:
        archives.pop(library, None)

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
        # One target compiles a language one way: where the project compiles
        # it several ways -- libX11 builds xim_trans.c with -DXIM_t and
        # x11_trans.c with -DX11_t, each including Xtrans with its own
        # meaning -- every way but the first is an object library of its
        # own, with its own flags, whose objects go into the archive.
        # Flattened into one, every file got every define, and Xtrans was
        # defined twice over.
        kept_groups = {}
        split_off = []
        languages = set()
        for key, files in groups.items():
            if key[0] in languages:
                split_off.append((key, files))
            else:
                languages.add(key[0])
                kept_groups[key] = files
        parts = []
        for index, (key, files) in enumerate(split_off):
            part = "{}__part{}".format(name, index)
            artifact = archive["archive"] + ".part{}".format(index)
            targets.append({"name": part, "archive": artifact,
                            "groups": {key: files}, "type": "OBJECT_LIBRARY"})
            parts.append(artifact)
        targets.append({"name": name, "archive": archive["archive"],
                        "groups": kept_groups, "parts": parts})

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
            handle.write("set({}_TYPE \"{}\")\n".format(prefix, target.get("type", "STATIC_LIBRARY")))
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
            emit(handle, prefix + "_LINK", target.get("parts", []) + links.get(target["archive"], []))
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
        # The files made some other way, each by the project's make, run for
        # that file alone from the directory whose Makefile has its rule --
        # a recursive build (libxcb's src) has each directory's rules in
        # its own Makefile, and only there.
        def inside(path, directory):
            relative = os.path.relpath(path, directory)
            return None if relative.startswith("..") else relative

        def deepest(path):
            best = None
            for directory in directories:
                if inside(path, directory) is not None and (best is None or len(directory) > len(best)):
                    best = directory
            return best

        made = []  # (directory, relative file, its rules, files made with it)
        for directory in sorted(directories):
            if not make:
                break
            d_rules, d_goal = rules_of(make, directory)
            roots = [r for r in (inside(p, directory) for p in list(compiles) + list(archives)) if r]
            files = generated_files(d_rules, d_goal, directory, roots)
            # And every source a compile reads that is not there yet, whatever
            # the rules say: a file made by a pattern rule is not a target in
            # make's database until something has asked for it, and asking
            # make for it by name, where its Makefile is, is how it is made.
            for one in compiles.values():
                source = one["source"]
                if os.path.exists(source) or deepest(source) != directory:
                    continue
                relative = inside(source, directory)
                if relative and relative not in files:
                    files.append(relative)
            # A header nothing has a rule for, needed by the build and not
            # there, beside a source that is made: made by the same command
            # -- libxcb's c_client.py writes xproto.c and xproto.h at once,
            # and make's database names only the .c.
            orphans = {}
            for target, rule in d_rules.items():
                for need in rule["needs"]:
                    if not need.endswith(".h") or need in d_rules:
                        continue
                    if os.path.exists(os.path.join(directory, need)):
                        continue
                    for source in (need[:-2] + ".c", need[:-2] + ".cc"):
                        if source in files:
                            orphans.setdefault(source, set()).add(need)
            for one in files:
                made.append((directory, one, d_rules, sorted(orphans.get(one, ()))))
        generated = [os.path.relpath(os.path.join(d, f), build) for d, f, _, _ in made]
        known = {os.path.normpath(os.path.join(d, f)) for d, f, _, _ in made}
        handle.write("set(CMAKE_IMPORT_COMMANDS {})\n".format(len(made)))
        for index, (directory, one, d_rules, also) in enumerate(made):
            prefix = "CMAKE_IMPORT_COMMAND{}".format(index)
            inputs = []
            for need in d_rules.get(one, {"needs": []})["needs"]:
                path = os.path.normpath(os.path.join(directory, need))
                if path in known or os.path.exists(path):
                    inputs.append(path)
            emit(handle, prefix + "_OUTPUTS", [os.path.normpath(os.path.join(directory, one))] +
                 [os.path.normpath(os.path.join(directory, a)) for a in also])
            emit(handle, prefix + "_INPUTS", inputs)
            handle.write("set({}_LINE {})\n".format(
                prefix, quote("{} -C {} --no-print-directory V=1 {}".format(
                    shlex.quote(make), shlex.quote(directory), shlex.quote(one)))))
            handle.write("set({}_DESC {})\n".format(prefix, quote("making " + os.path.relpath(os.path.join(directory, one), build))))
        emit(handle, "CMAKE_IMPORT_GENERATED_BY_TOOLS", [])

    sys.stderr.write(
        "make_import: {} targets, {} compiles, {} files made by make ({}), "
        "{} commands not read\n".format(
            len(targets), len(compiles), len(generated),
            ", ".join(generated[:6]) + (", ..." if len(generated) > 6 else ""), len(other)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
