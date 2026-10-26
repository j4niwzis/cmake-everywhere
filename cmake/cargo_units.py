"""What cargo_record.py wrote down, as the plan cargo_plan.py reads.

Cargo ran in a scratch directory, so that configuring touches nothing the
build made; every path in what it said is moved to the real one here. Then
three kinds of command:

- each crate: rustc itself, as cargo called it, and -- where the crate has
  a build script -- `@` the arguments file its run wrote;
- each build script's run (cargo_run.py run), after the script is compiled
  and after the runs of the packages it gets DEP_ variables from;
- for each static library a program links, what it needs from the system
  (cargo_run.py native), from rustc's own list.

Each comes after the commands that make the files it names: the --extern
paths, the script it runs, the arguments file it reads.
"""

import argparse
import json
import os
import sys


def moved(value, scratch, real):
    if isinstance(value, str):
        return value.replace(scratch, real)
    if isinstance(value, list):
        return [moved(one, scratch, real) for one in value]
    if isinstance(value, dict):
        return {key: moved(one, scratch, real) for key, one in value.items()}
    return value


# Cargo's conversation with the compiler and the recorder's own: nothing a
# command run later needs, and the jobserver's descriptors are long closed.
NOT_PASSED = {"RUSTC_WRAPPER", "RUSTC_WORKSPACE_WRAPPER", "CME_CARGO_UNITS",
              "CARGO_MAKEFLAGS", "MAKEFLAGS", "MFLAGS"}


def passed(env):
    return {name: value for name, value in env.items()
            if name not in NOT_PASSED and os.environ.get(name) != value}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--units", required=True)
    parser.add_argument("--scratch", required=True, help="where cargo ran")
    parser.add_argument("--target-dir", required=True, help="where the build puts it")
    parser.add_argument("--python", required=True)
    parser.add_argument("--runner", required=True, help="cargo_run.py")
    parser.add_argument("--native", required=True, help="the response file to write")
    parser.add_argument("--plan", required=True)
    arguments = parser.parse_args()

    scratch = os.path.abspath(arguments.scratch)
    real = os.path.abspath(arguments.target_dir)
    records = []
    for name in sorted(os.listdir(arguments.units)):
        if name.endswith(".json"):
            with open(os.path.join(arguments.units, name), encoding="utf-8") as file:
                records.append(moved(json.load(file), scratch, real))
    compiles = [one for one in records if one["kind"] == "rustc"]
    runs = [one for one in records if one["kind"] == "run"]
    if not compiles:
        print("cargo compiled nothing", file=sys.stderr)
        return 1

    def output_of(run):
        return os.path.join(os.path.dirname(run["env"]["OUT_DIR"]), "cme-output")

    # Which compile made a script: the one whose program sits where cargo
    # ran it from (it runs the copy beside what rustc wrote).
    script_of = {}
    for one in compiles:
        if one.get("program_output"):
            script_of[os.path.dirname(one["program_output"])] = one["program_output"]
    run_of_out_dir = {run["env"]["OUT_DIR"]: run for run in runs}

    # The packages a run's package depends on, by its crate's --extern.
    maker = {out: one for one in compiles for out in one["outputs"]}

    def externs(one):
        named = {arg.split("=", 1)[1] if "=" in arg else arg for arg in one["args"]}
        return [maker[path] for path in named if path in maker]

    invocations = []
    for run in runs:
        env = run["env"]
        script = script_of.get(os.path.dirname(run["program"]))
        if not script:
            print(f"no compiled script for the run in {env.get('OUT_DIR')}", file=sys.stderr)
            return 1
        package_dir = env.get("CARGO_MANIFEST_DIR")
        deps = []
        for crate in compiles:
            if crate["env"].get("CARGO_MANIFEST_DIR") != package_dir or crate.get("program_output"):
                continue
            if crate["env"].get("OUT_DIR") != env["OUT_DIR"]:
                continue
            for dep in externs(crate):
                other = run_of_out_dir.get(dep["env"].get("OUT_DIR"))
                if other and other["env"].get("CARGO_MANIFEST_LINKS"):
                    deps.append(f"{other['env']['CARGO_MANIFEST_LINKS']}={output_of(other)}")
        command = [arguments.runner, "run", "--script", script, "--output", output_of(run)]
        for dep in dict.fromkeys(deps):
            command += ["--dep", dep]
        invocations.append({
            "program": arguments.python, "args": command, "env": passed(env),
            "cwd": package_dir or run["cwd"],
            "outputs": [output_of(run), output_of(run) + ".args"],
            "inputs": [script] + [dep.partition("=")[2] for dep in deps],
            "depfile": output_of(run) + ".d",
            "package_name": env.get("CARGO_PKG_NAME", ""),
            "package_version": env.get("CARGO_PKG_VERSION", ""),
            "compile_mode": "run-custom-build",
        })

    libraries, native = [], []
    for one in compiles:
        args = list(one["args"])
        inputs = [path for path in {a.split("=", 1)[1] if "=" in a else a for a in args}
                  if path in maker and maker[path] is not one]
        run = run_of_out_dir.get(one["env"].get("OUT_DIR"))
        if run and not one.get("program_output"):
            args.append("@" + output_of(run) + ".args")
            inputs.append(output_of(run) + ".args")
        static = [out for out in one["outputs"]
                  if "staticlib" in one["crate_types"] and out.endswith((".a", ".lib"))]
        if static:
            listed = arguments.native + ".txt"
            args.append(f"--print=native-static-libs={listed}")
            libraries += static
            native.append((static, listed))
        invocations.append({
            "program": one["program"], "args": args, "env": passed(one["env"]),
            "cwd": one["cwd"], "outputs": one["outputs"], "inputs": sorted(inputs),
            "package_name": one["env"].get("CARGO_PKG_NAME", ""),
            "package_version": one["env"].get("CARGO_PKG_VERSION", ""),
            "compile_mode": "build", "libraries": static,
        })
    for static, listed in native:
        command = [arguments.runner, "native", "--listed", listed, "--rsp", arguments.native]
        for run in runs:
            command += ["--search", output_of(run)]
        invocations.append({
            "program": arguments.python, "args": command, "env": {}, "cwd": real,
            "outputs": [arguments.native], "inputs": static + [output_of(run) for run in runs],
            "package_name": "native libraries", "package_version": "",
            "compile_mode": "link",
        })

    # In an order where each comes after what makes its inputs.
    producer = {out: at for at, one in enumerate(invocations) for out in one["outputs"]}
    waits = [sorted({producer[path] for path in one.pop("inputs") if path in producer} - {at})
             for at, one in enumerate(invocations)]
    order, placed = [], {}
    pending = list(range(len(invocations)))
    while pending:
        ready = [at for at in pending if all(dep in placed for dep in waits[at])]
        if not ready:
            print("the recorded units wait for each other in a circle", file=sys.stderr)
            return 1
        for at in ready:
            placed[at] = len(order)
            order.append(at)
        pending = [at for at in pending if at not in placed]
    plan = []
    for at in order:
        one = invocations[at]
        one["deps"] = [placed[dep] for dep in waits[at]]
        one["links"] = {}
        plan.append(one)
    with open(arguments.plan, "w", encoding="utf-8") as file:
        json.dump({"invocations": plan}, file)
    return 0


if __name__ == "__main__":
    sys.exit(main())
