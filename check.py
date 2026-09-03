"""What can be checked about this registry without building anything.

Every cme_ command that is called has to be defined somewhere -- written
after an edit removed a function and left its calls behind, which took a
download, a gn run and a configure to find out. Every port has to say what it
is under and what it produces, because nothing else will notice a port that
forgets.

With --matrix it prints the ports as JSON instead, for a build that runs one
job per library.
"""
import glob, json, os, re, shlex, sys


def code(path):
    """A file with its strings and comments taken out, in that order.

    In that order because a # inside a quoted argument is not a comment, and
    taking comments out first ate the rest of the line -- including a closing
    parenthesis -- and reported an imbalance that was not there.
    """
    text = open(path).read()
    text = re.sub(r'"(\\.|[^"\\])*"', '""', text, flags=re.S)
    return re.sub(r"#[^\n]*", "", text)


def declaration_keywords():
    """The words cme_declare_port treats as keys, read from where it says so.

    Guessing them by shape does not work: LICENSE MIT, LICENSE FTL and
    LICENSE IJG all have a value that looks exactly like a keyword, and this
    read three ports as having no licence at all.
    """
    text = open("cmake-everywhere.cmake").read()
    body = text[text.index("function(cme_declare_port"):]
    body = body[:body.index("endfunction")]
    words = set()
    for match in re.finditer(r"set\((?:one|many)\s+(.*?)\)", body, re.S):
        words |= set(match.group(1).split())
    return words


def ports():
    """Each port as its directory, the name to look for, and its targets."""
    keywords = declaration_keywords()
    found = []
    for path in sorted(glob.glob("registry/*/port.cmake")):
        text = code(path)
        call = re.search(r"cme_declare_port\s*\((.*?)\n\)", text, re.S)
        if not call:
            continue
        tokens = shlex.split(call.group(1))
        fields = {}
        key = None
        for token in tokens:
            if token in keywords:
                key = token
                fields.setdefault(key, [])
            elif key:
                fields[key].append(token)
        found.append({
            "port": path.split("/")[1],
            "package": (fields.get("PROVIDES") or [path.split("/")[1]])[0],
            "targets": ";".join(fields.get("TARGETS", [])),
            "licence": " ".join(fields.get("LICENSE", [])),
            # Empty means anywhere. A build that is not one of these skips
            # the port rather than failing it.
            "systems": ";".join(fields.get("SYSTEMS", [])),
            "family": (fields.get("FAMILY") or [""])[0],
            "source_only": bool(fields.get("SOURCE_ONLY")),
            # The header a consumer includes, when the port names one. A
            # port that does not is checked by linking alone, which is the
            # weaker question.
            "header": (fields.get("CHECK_HEADER") or [""])[0],
            # What the machine has to have been told, when the library needs
            # something no build can find out on its own.
            "arrangement": (fields.get("ARRANGEMENT") or [""])[0],
        })
    return found


# One job per port is the point of the matrix, and one job per Boost library
# is 158 jobs saying the same thing about the same release. A family is
# checked by a sample of it: the umbrella, a header-only leaf, and the one
# with the most underneath it. What is left out is said out loud rather than
# looking like coverage.
SAMPLE = {"boost": ["boost", "boost-mp11", "boost-system", "boost-filesystem"]}


def sampled(all_ports):
    kept, dropped = [], []
    for entry in all_ports:
        if entry["source_only"]:
            continue
        family = entry["family"]
        if not family or entry["port"] in SAMPLE.get(family, []):
            kept.append(entry)
        else:
            dropped.append(entry["port"])
    return kept, dropped


if "--boost-ports" in sys.argv:
    # One entry per Boost library, for a job apiece.
    print(json.dumps([p for p in ports()
                      if p["family"] == "boost" and not p["source_only"]
                      and p["port"] != "boost"]))
    raise SystemExit(0)

if "--boost-components" in sys.argv:
    # Every component the umbrella declares, which is every Boost library
    # there is a port for. What a build asking for all of Boost asks for.
    text = code("registry/boost/port.cmake")
    # Without the ones that need an arrangement about the machine -- MPI,
    # Python. Asking for all of Boost is asking for what a machine can have
    # without being told anything, and those can still be asked for by name.
    arranged = {p["port"] for p in ports() if p["arrangement"]}
    names = []
    for block in re.findall(r"cme_port_feature\(boost\s+(\S+)(.*?)\)", text, re.S):
        feature, body = block
        wanted = re.search(r"DEPENDS\s+(\S+)", body)
        if wanted and wanted.group(1) in arranged:
            continue
        names.append(feature)
    print(";".join(sorted(set(names))))
    raise SystemExit(0)

if "--matrix" in sys.argv:
    kept, _ = sampled(ports())
    print(json.dumps(kept))
    raise SystemExit(0)


defined = set()
called = {}
files = (["cmake-everywhere.cmake"]
         # Everything here except CPM, which is somebody else's.
         + [f for f in sorted(glob.glob("cmake/*.cmake"))
            if os.path.basename(f) != "CPM.cmake"]
         + sorted(glob.glob("registry/*/*.cmake"))
         + sorted(glob.glob("test/registry/*/*.cmake"))
         + sorted(glob.glob("profiles/*.cmake")))
for path in files:
    text = code(path)
    defined |= set(re.findall(r"(?:function|macro)\(\s*(cme_[A-Za-z0-9_]+)", text))
    for name in re.findall(r"\b(cme_[A-Za-z0-9_]+)\s*\(", text):
        called.setdefault(name, path)

problems = 0
for name, where in sorted(called.items()):
    if name not in defined:
        print(f"  called and never defined: {name}  ({where})")
        problems += 1
for path in files:
    text = code(path)
    if text.count("(") != text.count(")"):
        print(f"  unbalanced parentheses: {path}")
        problems += 1

# A port that says nothing about what it produces cannot be checked by
# anything but a person reading it.
for entry in ports():
    if entry["source_only"]:
        # A download that other ports live inside produces nothing and is
        # never asked for by name, so there is nothing for it to say.
        continue
    for field in ("targets", "licence"):
        if not entry[field]:
            print(f"  {entry['port']} says nothing about its {field}")
            problems += 1
_, left_out = sampled(ports())
if left_out:
    print(f"  {len(left_out)} ports are family members and are not each given a "
          f"job of their own: {left_out[0]} ... {left_out[-1]}")
print(f"{len(defined)} commands defined, {len(called)} called, {problems} problems")
sys.exit(1 if problems else 0)
