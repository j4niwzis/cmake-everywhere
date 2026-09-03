"""Turn a configured CMake project into CMake data.

The same idea as gn_import.py, for a project that builds with CMake and will
not be a subdirectory: configure it somewhere on its own, ask it what it
would build, and build that here instead. libjpeg-turbo refuses
add_subdirectory in as many words, and this is the answer that does not
involve arguing with it.

Two sources, because one is not enough. The File API describes every target:
its sources, its defines, its include directories and the exact flags each
group of sources is compiled with. It does not describe custom commands at
all -- so those are read out of build.ninja, which is where the generator
wrote them down.
"""

import json
import os
import re
import sys


def read_reply(build):
    """The codemodel, through the index that names it."""
    reply = os.path.join(build, ".cmake", "api", "v1", "reply")
    index = sorted(f for f in os.listdir(reply) if f.startswith("index-"))
    if not index:
        raise SystemExit("cmake_import: no File API reply in " + reply)
    with open(os.path.join(reply, index[-1])) as handle:
        objects = json.load(handle)["objects"]
    for entry in objects:
        if entry["kind"] == "codemodel":
            with open(os.path.join(reply, entry["jsonFile"])) as handle:
                return reply, json.load(handle)
    raise SystemExit("cmake_import: the reply has no codemodel")


def resolve(path, source_root, build_root):
    """A path from the description as a real one.

    Paths are relative to the top-level source directory, except the ones
    that are not: a generated file is under the build directory. Trying both
    and keeping the one that exists is more reliable than believing either.
    """
    if os.path.isabs(path):
        return os.path.normpath(path)
    against_source = os.path.normpath(os.path.join(source_root, path))
    if os.path.exists(against_source):
        return against_source
    against_build = os.path.normpath(os.path.join(build_root, path))
    if os.path.exists(against_build):
        return against_build
    return against_source


def unescape_ninja(text):
    """Ninja's escaping, undone.

    A dollar is how ninja escapes anything: $: is a colon, $$ is a dollar,
    $<space> is a space, and a dollar at the end of a line joins it to the
    next.
    """
    text = re.sub(r"\$\n\s*", " ", text)
    out = []
    index = 0
    while index < len(text):
        character = text[index]
        if character == "$" and index + 1 < len(text):
            out.append(text[index + 1])
            index += 2
        else:
            out.append(character)
            index += 1
    return "".join(out)


def read_custom_commands(build, rules=("CUSTOM_COMMAND",)):
    """Every custom command in the generated build, by what it produces.

    build.ninja states them as a build edge using the CUSTOM_COMMAND rule
    with a COMMAND variable. That is the only place they are written down in
    a form anything else can read: the File API does not carry them.

    Which rules mean "a custom command" is the generator's business, so it
    is a parameter: meson writes CUSTOM_COMMAND_DEP as well, for the ones
    that leave a depfile. So is how far a variable line is indented -- CMake
    writes two spaces and meson writes one.
    """
    path = os.path.join(build, "build.ninja")
    if not os.path.exists(path):
        return {}
    with open(path) as handle:
        text = handle.read()
    text = re.sub(r"\$\n\s*", " ", text)

    commands = {}
    pattern = r"^build ([^\n]*?): (?:{})(?=[ \n])([^\n]*)\n((?:[ \t]+[^\n]*\n)*)".format(
        "|".join(re.escape(rule) for rule in rules))
    for match in re.finditer(pattern, text, re.M):
        # An edge can have implicit outputs, which ninja writes after a |
        # in the same list. They are outputs; the bar is not one, and
        # passing it on as a file name is a build file that ninja will not
        # read.
        outputs = [unescape_ninja(o) for o in match.group(1).split(" ")
                   if o and o not in ("|", "||")]
        inputs = [unescape_ninja(i) for i in match.group(2).split(" ")
                  if i and i not in ("|", "||")]
        # A name to type at a build tool is not a file that something
        # makes. CMake writes install, test, edit_cache and every utility
        # target as an edge producing <name>.util that nothing reads;
        # meson writes them with PHONY among the inputs. Neither generates
        # anything, and both name inputs that no rule makes.
        if "PHONY" in inputs or any(o.startswith("meson-internal__")
                                    for o in outputs):
            continue
        if outputs and all(o.endswith(".util") for o in outputs):
            continue
        body = match.group(3)
        command = re.search(r"^[ \t]+COMMAND = (.*)$", body, re.M)
        description = re.search(r"^[ \t]+DESC = (.*)$", body, re.M)
        if not command:
            continue
        commands[tuple(outputs)] = {
            "outputs": outputs,
            "inputs": inputs,
            "command": unescape_ninja(command.group(1)),
            "description": unescape_ninja(description.group(1)) if description else "",
        }
    return commands


def quote(value):
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'


def emit(out, name, values):
    out.write("set({} {})\n".format(name, " ".join(quote(v) for v in values)))


def main(argv):
    if len(argv) != 4:
        sys.stderr.write(
            "usage: cmake_import.py <probe-build-dir> <source-dir> <out.cmake>\n")
        return 2
    build, source, output = argv[1], argv[2], argv[3]
    reply, codemodel = read_reply(build)
    source_root = codemodel["paths"]["source"]
    build_root = codemodel["paths"]["build"]
    configuration = codemodel["configurations"][0]
    commands = read_custom_commands(build)

    targets = []
    by_id = {}
    for entry in configuration["targets"]:
        with open(os.path.join(reply, entry["jsonFile"])) as handle:
            targets.append(json.load(handle))
        by_id[entry["id"]] = targets[-1]["name"]

    # An artifact belongs to the target that produces it, which is how a link
    # fragment naming a file becomes a link against a target.
    artifact_owner = {}
    for target in targets:
        for artifact in target.get("artifacts", []):
            artifact_owner[resolve(artifact["path"], source_root, build_root)] = \
                target["name"]

    with open(output, "w") as handle:
        handle.write("# Written by cmake_import.py from a File API reply.\n")
        handle.write("# Anything edited here is overwritten.\n\n")
        handle.write("set(CMAKE_IMPORT_SOURCE {})\n".format(quote(source_root)))
        handle.write("set(CMAKE_IMPORT_BUILD {})\n\n".format(quote(build_root)))

        names = [t["name"] for t in targets]
        emit(handle, "CMAKE_IMPORT_TARGETS", names)
        handle.write("\n")

        for target in targets:
            prefix = "CMAKE_IMPORT_{}".format(re.sub(r"[^A-Za-z0-9_]", "_",
                                                     target["name"]))
            handle.write("# {}\n".format(target["name"]))
            handle.write("set({}_NAME {})\n".format(prefix, quote(target["name"])))
            handle.write("set({}_TYPE {})\n".format(prefix, quote(target["type"])))

            groups = target.get("compileGroups", [])
            sources = target.get("sources", [])
            compiled = []
            for index, entry in enumerate(sources):
                group = entry.get("compileGroupIndex")
                if group is None:
                    continue
                path = resolve(entry["path"], source_root, build_root)
                compiled.append((path, group))
            emit(handle, prefix + "_SOURCES", [p for p, _ in compiled])

            handle.write("set({}_GROUPS {})\n".format(prefix, len(groups)))
            for index, group in enumerate(groups):
                emit(handle, "{}_GROUP{}_LANGUAGE".format(prefix, index),
                     [group.get("language", "")])
                emit(handle, "{}_GROUP{}_DEFINES".format(prefix, index),
                     [d["define"] for d in group.get("defines", [])])
                emit(handle, "{}_GROUP{}_INCLUDES".format(prefix, index),
                     [resolve(i["path"], source_root, build_root)
                      for i in group.get("includes", [])])
                emit(handle, "{}_GROUP{}_FLAGS".format(prefix, index),
                     [f["fragment"] for f in
                      group.get("compileCommandFragments", [])])

            link = target.get("link", {})
            libraries = []
            flags = []
            for fragment in link.get("commandFragments", []):
                role = fragment.get("role")
                text = fragment.get("fragment", "")
                if role == "libraries":
                    libraries.append(text)
                elif role in ("flags", "libraryPath"):
                    flags.append(text)
            emit(handle, prefix + "_LINK", libraries)
            emit(handle, prefix + "_LINK_FLAGS", flags)
            emit(handle, prefix + "_DEPENDS",
                 [by_id[d["id"]] for d in target.get("dependencies", [])
                  if d["id"] in by_id])
            emit(handle, prefix + "_ARTIFACTS",
                 [resolve(a["path"], source_root, build_root)
                  for a in target.get("artifacts", [])])
            handle.write("\n")

        # What a target's artifact path means, so a link fragment that names a
        # file can become a link against the target that makes it.
        emit(handle, "CMAKE_IMPORT_ARTIFACT_PATHS", list(artifact_owner))
        emit(handle, "CMAKE_IMPORT_ARTIFACT_OWNERS", list(artifact_owner.values()))
        handle.write("\n")

        handle.write("set(CMAKE_IMPORT_COMMANDS {})\n".format(len(commands)))
        for index, entry in enumerate(commands.values()):
            emit(handle, "CMAKE_IMPORT_COMMAND{}_OUTPUTS".format(index),
                 [resolve(o, source_root, build_root) for o in entry["outputs"]])
            emit(handle, "CMAKE_IMPORT_COMMAND{}_INPUTS".format(index),
                 [resolve(i, source_root, build_root) for i in entry["inputs"]])
            emit(handle, "CMAKE_IMPORT_COMMAND{}_LINE".format(index),
                 [entry["command"]])
            emit(handle, "CMAKE_IMPORT_COMMAND{}_DESC".format(index),
                 [entry["description"]])

    sys.stderr.write("cmake_import: {} targets, {} custom commands\n".format(
        len(targets), len(commands)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
