"""What another build would run, as steps of this one.

The problem this solves has one shape and many instances: a build needs a
program that has to run on the machine doing the building, while everything
around it is compiled for somewhere else. A CMake target cannot be it -- a
build tree has one compiler -- and building it in a step of its own puts a
whole build inside one edge of this one, where it is neither parallel with
anything nor visible as anything but "Performing build step".

So the other project is configured with its own toolchain, for Ninja, and
what its generator wrote is read here: a rule is a command template, an edge
is inputs, outputs and the bindings that fill the template in. Each edge
becomes a command of this build, with the compiler it names -- which is why
it does not matter that the other project is gcc and this one is clang, or
that one is for the phone and the other for the machine at hand. A command
carries its own compiler.

Two things are resolved before the conversion rather than during the build.
C++ modules are wired by a scanner whose answer ninja loads as a dyndep file;
that scan is run here, and what it says becomes ordinary dependencies. And a
response file is written now, because its content is in the description.

What that costs is stated plainly: the description is read once, when this
build is configured. A source that starts importing a different module -- or
a new file appearing in a glob -- is a description that has changed, and the
build has to be configured again to see it. That is the same bargain every
other import in this repository makes.
"""

import argparse
import os
import re
import subprocess
import sys


def unescape(text):
    return text.replace("$:", ":").replace("$ ", " ").replace("$$", "$")


class Ninja:
    """A ninja file, as rules and edges."""

    def __init__(self):
        self.variables = {}
        self.rules = {}
        self.edges = []

    def read(self, path, root):
        with open(path, encoding="utf-8") as file:
            text = file.read()
        # A line continued with a trailing $ is one line.
        text = re.sub(r"\$\n\s*", " ", text)
        current = None      # the rule or edge indented lines belong to
        for line in text.splitlines():
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            if line[0] in " \t":
                if current is None:
                    continue
                name, _, value = line.strip().partition("=")
                current[name.strip()] = value.strip()
                continue
            current = None
            words = line.split()
            if words[0] == "rule":
                current = {}
                self.rules[words[1]] = current
            elif words[0] == "build":
                edge = self.edge(line, root)
                if edge is not None:
                    current = edge["bindings"]
            elif words[0] in ("include", "subninja"):
                self.read(os.path.join(root, unescape(words[1])), root)
            elif words[0] == "default":
                continue
            elif "=" in line:
                name, _, value = line.partition("=")
                self.variables[name.strip()] = value.strip()
        return self

    def edge(self, line, root):
        """build <outputs> [| <implicit outputs>]: <rule> <inputs> ..."""
        head, _, tail = line[len("build "):].partition(":")
        if not tail:
            return None
        outputs, _, implicit_outputs = head.partition(" | ")
        words = tail.split()
        if not words:
            return None
        rule = words[0]
        inputs, implicit, order = [], [], []
        where = inputs
        for word in words[1:]:
            if word == "|":
                where = implicit
            elif word == "||":
                where = order
            else:
                where.append(unescape(word))
        edge = {
            "rule": rule,
            "outputs": [unescape(w) for w in outputs.split()],
            "implicit_outputs": [unescape(w) for w in implicit_outputs.split()],
            "inputs": inputs,
            "implicit": implicit,
            "order": order,
            "bindings": {},
        }
        self.edges.append(edge)
        return edge

    def value(self, edge, name):
        if name in edge["bindings"]:
            return self.expand(edge["bindings"][name], edge)
        rule = self.rules.get(edge["rule"], {})
        if name in rule:
            return self.expand(rule[name], edge)
        return self.variables.get(name, "")

    def expand(self, text, edge, depth=0):
        if depth > 8:
            return text
        def one(match):
            name = match.group(1) or match.group(2)
            if name == "in":
                return " ".join(edge["inputs"])
            if name == "in_newline":
                return "\n".join(edge["inputs"])
            if name == "out":
                return " ".join(edge["outputs"])
            if name in edge["bindings"]:
                return self.expand(edge["bindings"][name], edge, depth + 1)
            rule = self.rules.get(edge["rule"], {})
            if name in rule:
                return self.expand(rule[name], edge, depth + 1)
            return self.expand(self.variables.get(name, ""), edge, depth + 1)
        text = re.sub(r"\$\{([A-Za-z0-9_.]+)\}|\$([A-Za-z0-9_.]+)", one, text)
        return text.replace("$$", "$").replace("$ ", " ").replace("$:", ":")


# What is about the other build's own housekeeping rather than about what it
# produces: regenerating its ninja file, its aliases, and asking it questions.
HOUSEKEEPING = {"RERUN_CMAKE", "CLEAN", "HELP", "phony"}


def quote(text):
    return '"' + str(text).replace("\\", "\\\\").replace('"', '\\"') + '"'


def absolute(path, root):
    if os.path.isabs(path):
        return os.path.normpath(path)
    return os.path.normpath(os.path.join(root, path))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", required=True,
                        help="where the other project was configured")
    parser.add_argument("--out", required=True, help="the CMake to write")
    parser.add_argument("--port", required=True)
    parser.add_argument("--ninja", default="ninja",
                        help="what runs the scan the module wiring needs")
    parser.add_argument("--want", action="append", default=[],
                        help="what is wanted out of that build; only the "
                             "steps that lead to it are taken")
    arguments = parser.parse_args()
    root = os.path.abspath(arguments.build)

    ninja = Ninja().read(os.path.join(root, "build.ninja"), root)

    # The module wiring, resolved now. The scanner and the step that reads it
    # are the other build's own; they are run there, once, and what they wrote
    # becomes dependencies here.
    dyndeps = sorted({edge["bindings"]["dyndep"]
                      for edge in ninja.edges if "dyndep" in edge["bindings"]})
    if dyndeps:
        done = subprocess.run([arguments.ninja, "-C", root] + dyndeps,
                              capture_output=True, text=True, check=False)
        if done.returncode != 0:
            print(done.stdout + done.stderr, file=sys.stderr)
            return 1

    # A dyndep file is a ninja file too: it says which modules an object
    # needs and which it produces.
    extra_inputs, extra_outputs = {}, {}
    for name in dyndeps:
        path = absolute(name, root)
        if not os.path.exists(path):
            continue
        loaded = Ninja().read(path, root)
        for edge in loaded.edges:
            for output in edge["outputs"]:
                extra_inputs.setdefault(output, []).extend(edge["implicit"])
                extra_outputs.setdefault(output, []).extend(
                    edge["implicit_outputs"])

    # Aliases: a phony edge is another name for what it depends on.
    phony = {}
    for edge in ninja.edges:
        if edge["rule"] == "phony":
            for output in edge["outputs"]:
                phony[output] = edge["inputs"] + edge["implicit"]

    def resolve(names, seen=None):
        seen = seen or set()
        out = []
        for name in names:
            if name in seen:
                continue
            seen.add(name)
            if name in phony:
                out += resolve(phony[name], seen)
            else:
                out.append(name)
        return out

    # Only what leads to what was asked for. A generated build has edges
    # that are about itself -- an alias, a cache editor, a rule to write the
    # build file again -- and none of them are steps in making the thing this
    # build wants.
    makes = {}
    for edge in ninja.edges:
        for output in edge["outputs"] + edge["implicit_outputs"]:
            makes.setdefault(output, edge)
    wanted, pending = set(), list(arguments.want)
    while pending:
        name = pending.pop()
        for real in resolve([name]):
            edge = makes.get(real)
            if edge is None or id(edge) in wanted:
                continue
            wanted.add(id(edge))
            for output in edge["outputs"]:
                pending += extra_inputs.get(output, [])
            pending += edge["inputs"] + edge["implicit"] + edge["order"]
    if not arguments.want:
        wanted = {id(edge) for edge in ninja.edges}

    lines = [f"# Written by ninja_import.py from what {arguments.port} said",
             "# it would run, in the build directory it was configured in.",
             "# One command per edge, with the compiler that edge names."]
    produced = []
    for edge in ninja.edges:
        rule = edge["rule"]
        if rule in HOUSEKEEPING or id(edge) not in wanted:
            continue
        if any(o.endswith((".ninja", ".ninja.stamp")) for o in edge["outputs"]):
            continue
        # The scan and what reads it have already run; their answers are in
        # the dependencies below.
        if "SCAN" in rule or "DYNDEP" in rule:
            continue
        command = ninja.value(edge, "command")
        if not command.strip():
            continue

        # A response file is written now: what goes in it is in the
        # description, and nothing about it changes at build time.
        rspfile = ninja.value(edge, "rspfile")
        if rspfile:
            content = ninja.value(edge, "rspfile_content")
            path = absolute(rspfile, root)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as file:
                file.write(content)

        outputs = [absolute(o, root)
                   for o in edge["outputs"] + edge["implicit_outputs"]]
        for output in edge["outputs"]:
            outputs += [absolute(x, root)
                        for x in extra_outputs.get(output, [])]
        depends = []
        for name in resolve(edge["inputs"] + edge["implicit"] + edge["order"]):
            depends.append(absolute(name, root))
        for output in edge["outputs"]:
            for name in resolve(extra_inputs.get(output, [])):
                depends.append(absolute(name, root))
        outputs = list(dict.fromkeys(outputs))
        depends = [d for d in dict.fromkeys(depends) if d not in outputs]
        if not outputs:
            continue
        produced += outputs

        description = ninja.value(edge, "description") or rule
        lines.append("")
        lines.append("add_custom_command(")
        lines.append("  OUTPUT " + " ".join(quote(o) for o in outputs))
        # Directories the other build would have made itself.
        for directory in sorted({os.path.dirname(o) for o in outputs}):
            lines.append("  COMMAND \"${CMAKE_COMMAND}\" -E make_directory " +
                         quote(directory))
        # A command out of a ninja file is a line for a shell -- it has &&
        # and redirection in it -- so it is given to one.
        lines.append("  COMMAND \"${CME_SHELL}\" -c " + quote(command))
        if depends:
            lines.append("  DEPENDS " + " ".join(quote(d) for d in depends))
        lines.append("  WORKING_DIRECTORY " + quote(root))
        lines.append("  COMMENT " + quote(f"{arguments.port}: {description}"))
        lines.append("  VERBATIM)")

    lines.append("")
    lines.append("set(CME_NINJA_OUTPUTS " +
                 " ".join(quote(o) for o in dict.fromkeys(produced)) + ")")
    with open(arguments.out, "w", encoding="utf-8") as file:
        file.write("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
