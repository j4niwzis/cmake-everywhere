"""Turn a configured Meson project into CMake data.

The same idea as cmake_import.py, for a project that builds with Meson:
configure it somewhere on its own, ask it what it would build, and build
that here instead. basu and most of the wayland world build no other way,
and this is the answer that does not involve installing them first.

Two sources, because one is not enough. meson-info/intro-targets.json,
written by `meson setup`, describes every target: its sources, the exact
parameters each group of sources is compiled with, and the parameters its
linker is given. It does not describe custom commands -- so those are read
out of build.ninja, which is where the generator wrote them down, by the
same reader the CMake importer uses.

What comes out is the description cmakeproject.cmake already knows how to
read, so the targets are made in one place for both.
"""

import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from cmake_import import emit, quote, read_custom_commands, unescape_ninja  # noqa: E402


# What Meson calls a target and what CMake calls it. A type that is not
# here is not a target CMake can be told to build.
TYPES = {
    "executable": "EXECUTABLE",
    "static library": "STATIC_LIBRARY",
    "shared library": "SHARED_LIBRARY",
    "shared module": "MODULE_LIBRARY",
}

# What Meson calls a language and what CMake calls it. A language that is
# not here is one CMake has no compiler for, and a target written in it is
# left alone rather than half-imported.
LANGUAGES = {
    "c": "C",
    "cpp": "CXX",
    "objc": "OBJC",
    "objcpp": "OBJCXX",
    "fortran": "Fortran",
    "cuda": "CUDA",
    "assembly": "ASM",
    "nasm": "ASM_NASM",
}


def read_targets(meson, build):
    """What the project said it would build.

    `meson setup` leaves the answer in meson-info; asking again costs a
    process and gives the same file back, so it is only done when the file
    is not there.
    """
    path = os.path.join(build, "meson-info", "intro-targets.json")
    if os.path.exists(path):
        with open(path) as handle:
            return json.load(handle)
    result = subprocess.run([meson, "introspect", "--targets", build],
                            stdout=subprocess.PIPE)
    if result.returncode != 0:
        raise SystemExit("meson_import: cannot introspect " + build)
    return json.loads(result.stdout.decode())


def read_link_inputs(build):
    """What each link edge in the generated build was given, by output.

    Meson's introspection states the parameters a target's linker gets,
    which for a static library are ar's letters and name nothing. What a
    static library is built against is only in build.ninja, as the inputs
    of the archiving edge.
    """
    path = os.path.join(build, "build.ninja")
    if not os.path.exists(path):
        return {}
    with open(path) as handle:
        text = handle.read()
    text = re.sub(r"\$\n\s*", " ", text)

    inputs = {}
    for match in re.finditer(
            r"^build ([^\n]*?): [A-Za-z0-9_]*LINKER([^\n]*)$", text, re.M):
        outputs = [unescape_ninja(o) for o in match.group(1).split(" ") if o]
        given = [unescape_ninja(i) for i in match.group(2).split(" ")
                 if i and i not in ("|", "||")]
        for output in outputs:
            inputs[resolve(output, build)] = given
    return inputs


def resolve(path, build_root):
    """A path from the description as a real one.

    Meson states compile parameters and sources as absolute paths and
    linker parameters as whatever it hands the linker, which runs from the
    build directory.
    """
    if os.path.isabs(path):
        return os.path.normpath(path)
    return os.path.normpath(os.path.join(build_root, path))


def split_parameters(parameters, build_root):
    """Compile parameters as defines, include directories and flags."""
    defines = []
    includes = []
    flags = []
    index = 0
    while index < len(parameters):
        parameter = parameters[index]
        index += 1
        if parameter.startswith("-D"):
            if parameter == "-D" and index < len(parameters):
                defines.append(parameters[index])
                index += 1
            else:
                defines.append(parameter[2:])
        elif parameter in ("-I", "-isystem", "-idirafter", "-iquote"):
            if index < len(parameters):
                includes.append(resolve(parameters[index], build_root))
                index += 1
        elif parameter.startswith("-I"):
            includes.append(resolve(parameter[2:], build_root))
        elif parameter.startswith("-isystem"):
            includes.append(resolve(parameter[len("-isystem"):], build_root))
        else:
            flags.append(parameter)
    return defines, includes, flags


def split_link(parameters, build_root, artifacts):
    """Linker parameters as libraries and as flags.

    A static library's linker is ar, whose parameters are letters like
    `csrD`. Those name no library, and the caller does not ask about static
    libraries at all; for the rest, a parameter is a library when it is -l,
    when it names a file this project builds or one that is there, or when
    it is a path spelled like a library. Everything else is a flag, which
    is dropped rather than guessed at.
    """
    libraries = []
    flags = []
    for parameter in parameters:
        if parameter.startswith("-l"):
            libraries.append(parameter)
            continue
        if parameter.startswith("-"):
            flags.append(parameter)
            continue
        path = resolve(parameter, build_root)
        if path in artifacts or os.path.exists(path) or \
                re.search(r"\.(a|so|dylib|tbd)(\.[0-9.]+)?$", path):
            libraries.append(path)
        else:
            flags.append(parameter)
    return libraries, flags


def owner_of(path, artifacts):
    """The target a file belongs to, if one does.

    An artifact belongs to the target that produces it. So does an object
    file: Meson compiles a target's objects into a directory named after
    the artifact with `.p` on the end, which is how a static library that
    bundles another one names what it bundled.
    """
    if path in artifacts:
        return artifacts[path]
    directory = os.path.dirname(path)
    while directory.endswith(".p"):
        if directory[:-2] in artifacts:
            return artifacts[directory[:-2]]
        directory = os.path.dirname(directory)
    return None


def main(argv):
    if len(argv) != 5:
        sys.stderr.write(
            "usage: meson_import.py <meson> <build-dir> <source-dir> <out.cmake>\n")
        return 2
    meson, build, source, output = argv[1], argv[2], argv[3], argv[4]
    build_root = os.path.abspath(build)
    source_root = os.path.abspath(source)
    described = read_targets(meson, build_root)
    commands = read_custom_commands(
        build_root, rules=("CUSTOM_COMMAND", "CUSTOM_COMMAND_DEP"))
    link_inputs = read_link_inputs(build_root)

    # An artifact belongs to the target that produces it, which is how a
    # linker parameter naming a file becomes a link against a target.
    artifact_owner = {}
    for target in described:
        if TYPES.get(target["type"]) is None:
            continue
        for artifact in target.get("filename", []):
            artifact_owner[resolve(artifact, build_root)] = target["name"]

    # Meson names targets per directory, so two can share a name. The name
    # is what a port asks for, so a shared one is refused here rather than
    # silently answered with whichever came last.
    seen = {}
    for target in described:
        if TYPES.get(target["type"]) is None:
            continue
        seen.setdefault(target["name"], []).append(target["id"])
    duplicated = sorted(name for name, ids in seen.items() if len(ids) > 1)

    by_id = {t["id"]: t["name"] for t in described}

    # The first artifact of a target, by target: what a link against it is.
    artifacts_of = {}
    for path, owner in artifact_owner.items():
        artifacts_of.setdefault(owner, path)

    targets = []
    skipped = []
    for target in described:
        kind = TYPES.get(target["type"])
        if kind is None:
            continue
        if target["name"] in duplicated:
            skipped.append("{} ({} targets share the name)".format(
                target["name"], len(seen[target["name"]])))
            continue

        groups = []
        sources = []
        link = []
        link_flags = []
        unknown = ""
        # Whether the order of what it links is known. It is not, when it
        # was worked out from the objects an archive holds: Meson states
        # what a static library is built against nowhere, so which archives
        # belong together can be read and their order cannot.
        ordered = True
        if kind == "STATIC_LIBRARY":
            # An archive is not linked, so what it is in is read from the
            # edge that archives it: every input that another target
            # produced. Meson bundles the objects of a static library that
            # a static library links, and those objects arrive here as the
            # target they were compiled for. What the archive needs from
            # outside the project is written down nowhere, and the port
            # says it.
            for artifact in target.get("filename", []):
                for name in link_inputs.get(resolve(artifact, build_root), []):
                    owner = owner_of(resolve(name, build_root), artifact_owner)
                    if owner and owner != target["name"] and \
                            owner not in duplicated:
                        artifact = artifacts_of.get(owner)
                        if artifact and artifact not in link:
                            link.append(artifact)
                            ordered = False

        for block in target.get("target_sources", []):
            if "linker" in block:
                if kind == "STATIC_LIBRARY":
                    continue
                found, dropped = split_link(block.get("parameters", []),
                                            build_root, artifact_owner)
                link.extend(found)
                link_flags.extend(dropped)
                continue
            language = LANGUAGES.get(block.get("language", ""))
            if language is None:
                unknown = block.get("language", "")
                break
            files = [resolve(s, build_root) for s in block.get("sources", [])]
            files += [resolve(s, build_root)
                      for s in block.get("generated_sources", [])]
            if not files:
                continue
            defines, includes, flags = split_parameters(
                block.get("parameters", []), build_root)
            sources.extend(files)
            groups.append({"language": language, "defines": defines,
                           "includes": includes, "flags": flags})
        if unknown:
            skipped.append("{} (written in {})".format(target["name"], unknown))
            continue
        if not sources:
            # A library with no sources of its own is what its parts make
            # it. Meson's `library()` is written this way when everything
            # in it comes from static libraries it bundles; there is
            # nothing to compile and nothing to archive here, so it is the
            # name of those parts together.
            if kind == "EXECUTABLE":
                skipped.append("{} (nothing to compile)".format(target["name"]))
                continue
            kind = "INTERFACE_LIBRARY"
            for artifact in target.get("filename", []):
                for name in link_inputs.get(resolve(artifact, build_root), []):
                    owner = owner_of(resolve(name, build_root), artifact_owner)
                    if owner and owner != target["name"] and \
                            owner not in duplicated:
                        found = artifacts_of.get(owner)
                        if found and found not in link:
                            link.append(found)
                            ordered = False
            if not link:
                skipped.append("{} (nothing to compile, nothing in it)".format(
                    target["name"]))
                continue

        targets.append({
            "name": target["name"],
            "type": kind,
            "sources": sources,
            "groups": groups,
            "link": link,
            "link_flags": link_flags,
            "ordered": ordered,
            "depends": [by_id[d] for d in target.get("depends", [])
                        if d in by_id and by_id[d] not in duplicated],
            "artifacts": [resolve(a, build_root)
                          for a in target.get("filename", [])],
        })

    # A command that runs something this project builds runs it from the
    # directory it was written for, where nothing is built. That is said
    # out loud, because the build failure it causes says something else.
    tools = set()
    for entry in commands.values():
        for name in entry["inputs"]:
            owner = artifact_owner.get(resolve(name, build_root))
            if owner:
                tools.add(owner)

    with open(output, "w") as handle:
        handle.write("# Written by meson_import.py from meson introspection.\n")
        handle.write("# Anything edited here is overwritten.\n\n")
        handle.write("set(CMAKE_IMPORT_SOURCE {})\n".format(quote(source_root)))
        handle.write("set(CMAKE_IMPORT_BUILD {})\n\n".format(quote(build_root)))

        emit(handle, "CMAKE_IMPORT_TARGETS", [t["name"] for t in targets])
        handle.write("\n")

        for target in targets:
            prefix = "CMAKE_IMPORT_{}".format(
                re.sub(r"[^A-Za-z0-9_]", "_", target["name"]))
            handle.write("# {}\n".format(target["name"]))
            handle.write("set({}_NAME {})\n".format(prefix,
                                                    quote(target["name"])))
            handle.write("set({}_TYPE {})\n".format(prefix,
                                                    quote(target["type"])))
            emit(handle, prefix + "_SOURCES", target["sources"])
            handle.write("set({}_GROUPS {})\n".format(prefix,
                                                      len(target["groups"])))
            for index, group in enumerate(target["groups"]):
                emit(handle, "{}_GROUP{}_LANGUAGE".format(prefix, index),
                     [group["language"]])
                emit(handle, "{}_GROUP{}_DEFINES".format(prefix, index),
                     group["defines"])
                emit(handle, "{}_GROUP{}_INCLUDES".format(prefix, index),
                     group["includes"])
                emit(handle, "{}_GROUP{}_FLAGS".format(prefix, index),
                     group["flags"])
            emit(handle, prefix + "_LINK", target["link"])
            emit(handle, prefix + "_LINK_GROUP",
                 [] if target["ordered"] else ["RESCAN"])
            emit(handle, prefix + "_LINK_FLAGS", target["link_flags"])
            emit(handle, prefix + "_DEPENDS", target["depends"])
            emit(handle, prefix + "_ARTIFACTS", target["artifacts"])
            handle.write("\n")

        emit(handle, "CMAKE_IMPORT_ARTIFACT_PATHS", list(artifact_owner))
        emit(handle, "CMAKE_IMPORT_ARTIFACT_OWNERS",
             list(artifact_owner.values()))
        handle.write("\n")

        handle.write("set(CMAKE_IMPORT_COMMANDS {})\n".format(len(commands)))
        for index, entry in enumerate(commands.values()):
            emit(handle, "CMAKE_IMPORT_COMMAND{}_OUTPUTS".format(index),
                 [resolve(o, build_root) for o in entry["outputs"]])
            emit(handle, "CMAKE_IMPORT_COMMAND{}_INPUTS".format(index),
                 [resolve(i, build_root) for i in entry["inputs"]])
            emit(handle, "CMAKE_IMPORT_COMMAND{}_LINE".format(index),
                 [entry["command"]])
            emit(handle, "CMAKE_IMPORT_COMMAND{}_DESC".format(index),
                 [entry["description"]])
        handle.write("\n")
        emit(handle, "CMAKE_IMPORT_GENERATED_BY_TOOLS", sorted(tools))

    sys.stderr.write("meson_import: {} targets, {} custom commands{}\n".format(
        len(targets), len(commands),
        ", skipped " + ", ".join(skipped) if skipped else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
