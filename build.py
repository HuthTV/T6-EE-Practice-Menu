#!/usr/bin/env python3
"""Builds the practice tool for every map. Cross-platform; standard library only.

    python build.py                       Build every map into build/. Does not touch the game.
    python build.py -deploy               Build, then install one compiled script per map.
    python build.py -deploy -source       Install the plain source files instead; Plutonium
                                          compiles them, so edits only need a map restart.
    python build.py -map od -deploy       Only Origins and Die Rise.
    python build.py -map origins mob      Maps by name or by letters, in any order.
    python build.py -tools                Also compile every z_tools/*.gsc (installed with -deploy).

Flags may be given in any order, with one or two dashes, in any case (-Map, --map).
-check is accepted for "build only" (the old build_single.bat -Check).

Maps: t TranZit, o Origins, d Die Rise, m Mob of the Dead, b Buried. "todmb" is all five.
Skeleton maps (install=False in MAPS) are built and checked, never installed.

Deploy folder (the game's scripts/zm folder), first found wins:
    -deploy-dir <path>
    environment variable T6_DEPLOY_DIR
    "deploy_dir" in build.local.json (next to this script; keep it out of git)
    Windows only: %LOCALAPPDATA%/Plutonium/storage/t6/scripts/zm

gsc-tool (https://github.com/xensik/gsc-tool/releases) is looked for at bin/gsc-tool.exe,
bin/gsc-tool, then on PATH. Tested with 1.5.1.359.

Each map has an entry script in its map folder, so Plutonium only loads it on that map,
named for the tool it starts: scripts/zm/zm_tomb/o-prac-menu.gsc (Origins) and so on.
Release and source installs use the same entry path, so one replaces the other. The
previous entry script is backed up to build/<map>/previous-<entry>.gsc. Installing also
moves an older entry named menu.gsc out of the map folder (to build/<map>/previous-menu.gsc).

The sources are laid out like the install:
  - utility_core/   the menu engine, settings, modes and HUDs every map shares. It never
                    names map code; maps hand it function pointers.
  - origins_menu/   Origins code and modes; oprac.gsh holds its #defines.
  - mob_menu/       Mob of the Dead code and modes; mob.gsh holds its #defines.
  - buried_menu/, dierise_menu/, tranzit_menu/   skeletons: a map descriptor, a .gsh and a
                    bare Freeroam mode.
A map's entry includes the core and its own folder. Every build checks both forms:
  - Source: every file compiles on its own (from a copy of the install tree in
    build/<map>/source/), and includes each project file whose functions it calls. The core
    may not include a map folder or name maps\\mp\\zm_* scripts, and a map folder may not
    include another map's folder.
  - Release: the map's files are joined into build/<map>/<entry>.gsc and compiled to one
    script. Project #includes and #inlines become blank lines (so compile errors keep their
    file and line), the vanilla #includes of every file are collected at the top, and the
    shared headers go in once.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BUILD_DIR = ROOT / "build"
CORE = "utility_core"


class BuildError(Exception):
    pass


class MapInfo:
    def __init__(self, name, letter, entry, entry_file, folder, install):
        self.name = name
        self.letter = letter
        self.entry = entry
        self.entry_file = entry_file
        self.folder = folder
        self.install = install


# Every map: its entry folder (the game's map name), entry script and code folder.
# install=False marks a skeleton: built and checked like the others, never installed
# (set it to True when the map is ready to run in game).
MAPS = [
    MapInfo("origins", "o", "zm_tomb",     "o-prac-menu.gsc", "origins_menu", True),
    MapInfo("mob",     "m", "zm_prison",   "m-prac-menu.gsc", "mob_menu",     True),
    MapInfo("buried",  "b", "zm_buried",   "b-prac-menu.gsc", "buried_menu",  False),
    MapInfo("dierise", "d", "zm_highrise", "d-prac-menu.gsc", "dierise_menu", False),
    MapInfo("tranzit", "t", "zm_transit",  "t-prac-menu.gsc", "tranzit_menu", False),
]
MAP_FOLDERS = [m.folder for m in MAPS]


# ---------------------------------------------------------------- helpers
def rel(path):
    """'origins_menu\\fullgame.gsc' for a source file (backslashes, as in the includes)."""
    return Path(path).relative_to(ROOT).as_posix().replace("/", "\\")


def project_name(path):
    """'origins_menu\\fullgame' for a source file."""
    return rel(path)[: -len(Path(path).suffix)]


def read_lines(path):
    return Path(path).read_text(encoding="utf-8-sig").splitlines()


def assert_ascii(path, lines):
    for i, line in enumerate(lines):
        if re.search(r"[^\x00-\x7F]", line):
            raise BuildError(f"{rel(path)}:{i + 1}: non-ASCII character.")


_CODE_RE = re.compile(r'"(?:\\.|[^"\\])*"|//[^\r\n]*|/\*[\s\S]*?\*/')


def get_code(path):
    """Code with comments removed and strings emptied, for finding names."""
    text = Path(path).read_text(encoding="utf-8-sig")
    return _CODE_RE.sub(lambda m: '""' if m.group(0).startswith('"') else "", text)


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def find_gsc_tool():
    for candidate in (ROOT / "bin" / "gsc-tool.exe", ROOT / "bin" / "gsc-tool"):
        if candidate.is_file():
            return str(candidate)
    found = shutil.which("gsc-tool")
    if found:
        return found
    raise BuildError("gsc-tool not found (bin/gsc-tool[.exe] or on PATH). See the top of build.py.")


def resolve_deploy_dir(arg):
    if arg:
        return Path(arg)
    if os.environ.get("T6_DEPLOY_DIR"):
        return Path(os.environ["T6_DEPLOY_DIR"])
    local = ROOT / "build.local.json"
    if local.is_file():
        value = json.loads(local.read_text(encoding="utf-8")).get("deploy_dir")
        if value:
            return Path(value)
    if sys.platform == "win32" and os.environ.get("LOCALAPPDATA"):
        return Path(os.environ["LOCALAPPDATA"]) / "Plutonium" / "storage" / "t6" / "scripts" / "zm"
    raise BuildError("no deploy folder: use -deploy-dir, T6_DEPLOY_DIR or build.local.json.")


def select_maps(tokens):
    if not tokens:
        return list(MAPS)
    by_name = {m.name: m for m in MAPS}
    by_letter = {m.letter: m for m in MAPS}
    chosen = set()
    for token in tokens:
        for part in token.lower().replace(",", " ").split():
            if part in by_name:
                chosen.add(part)
            elif all(c in by_letter for c in part):
                chosen.update(by_letter[c].name for c in part)
            else:
                raise BuildError(f"unknown map '{part}' (names: {', '.join(by_name)}; letters: todmb).")
    return [m for m in MAPS if m.name in chosen]


# ---------------------------------------------------------------- sources and checks
def get_menu_sources(info):
    """A map's sources, in release join order: entry script, core utilities, the rest of
    the core, then the map folder, each alphabetically."""
    first = ["menu_utility.gsc", "menu_base.gsc"]
    core_dir = ROOT / CORE
    core_rest = sorted((p for p in core_dir.glob("*.gsc") if p.name not in first), key=lambda p: p.name.lower())
    files = [ROOT / info.entry / info.entry_file]
    files += [core_dir / name for name in first]
    files += core_rest
    files += sorted((ROOT / info.folder).glob("*.gsc"), key=lambda p: p.name.lower())
    return files


def test_project_includes(files):
    """Every file must #include the project files whose functions it calls; Plutonium
    compiles each source file on its own."""
    owner, code = {}, {}
    for f in files:
        code[f] = get_code(f)
        for m in re.finditer(r"(?m)^([A-Za-z_]\w*)\s*\([^;{]*\)\s*$", code[f]):
            name = m.group(1)
            if name in owner and owner[name] != f:
                raise BuildError(f"{name}() is defined in both {rel(owner[name])} and {rel(f)}.")
            owner[name] = f
    problems = []
    for f in files:
        text = Path(f).read_text(encoding="utf-8-sig")
        included = {m.group(1) for m in re.finditer(r"(?m)^\s*#include\s+scripts\\zm\\(\w+\\\w+)\s*;", text)}
        # Calls with a path (maps\...::name) name their own script.
        plain = re.sub(r"[\w\\]+::\w+", "", code[f])
        reported = set()
        for m in re.finditer(r"::(\w+)|\b(\w+)\s*\(", plain):
            name = m.group(1) or m.group(2)
            if name not in owner or owner[name] == f:
                continue
            target = project_name(owner[name])
            if target not in included and target not in reported:
                reported.add(target)
                problems.append(f"{rel(f)} calls {name}() but does not #include scripts\\zm\\{target}")
    if problems:
        for p in problems:
            print("ERROR " + p)
        raise BuildError("missing project #includes.")


def test_dependencies(files, info):
    """Core never refers to a map; a map never includes another map's folder."""
    problems = []
    for f in files:
        relative = rel(f)
        is_core = relative.startswith(CORE + "\\")
        text = Path(f).read_text(encoding="utf-8-sig")
        for m in re.finditer(r"(?m)^\s*#(?:include|inline)\s+scripts\\zm\\(\w+)\\", text):
            folder = m.group(1)
            if is_core and folder != CORE:
                problems.append(f"{relative} (core) includes the map folder {folder}")
            elif not is_core and folder in MAP_FOLDERS and folder != info.folder:
                problems.append(f"{relative} includes another map's folder {folder}")
        if is_core:
            hit = re.search(r"maps\\mp\\zm_\w+", get_code(f))
            if hit:
                problems.append(f"{relative} (core) names the map script {hit.group(0)}")
    if problems:
        for p in problems:
            print("ERROR " + p)
        raise BuildError("dependency rule broken.")


def copy_source_tree(directory, info):
    """Copies a map's sources into directory laid out like Plutonium's storage/t6 folder."""
    if directory.exists():
        shutil.rmtree(directory)
    zm = directory / "scripts" / "zm"
    for folder in (info.entry, CORE, info.folder):
        target = zm / folder
        target.mkdir(parents=True, exist_ok=True)
        for p in (ROOT / folder).iterdir():
            if p.is_file() and p.suffix in (".gsc", ".gsh"):
                shutil.copy2(p, target)


def join_sources(files, out_file, info):
    """Joins the sources into out_file and returns where each one starts in it."""
    includes, headers, sections = [], [], []
    for f in files:
        lines = read_lines(f)
        assert_ascii(f, lines)
        body = []
        for line in lines:
            m = re.match(r"^\s*#include\s+(\S+?)\s*;", line)
            if m:
                # Project files are all in the joined file; vanilla ones go to the top.
                path = m.group(1)
                if not path.startswith("scripts\\zm\\") and path not in includes:
                    includes.append(path)
                line = ""
            else:
                m = re.match(r"^\s*#inline\s+scripts\\zm\\(\w+\\\w+)\s*;", line)
                if m:
                    # Project headers go in once, at the top.
                    if m.group(1) not in headers:
                        headers.append(m.group(1))
                    line = ""
            body.append(line)
        sections.append((rel(f), body))

    out = [f"// Generated by build.py from {info.entry}\\{info.entry_file},{CORE}\\ and {info.folder}\\. Do not edit."]
    out += [f"#include {path};" for path in includes]
    for header in headers:
        header_file = ROOT / (header.replace("\\", "/") + ".gsh")
        lines = read_lines(header_file)
        assert_ascii(header_file, lines)
        out += ["", f"// ===== {header}.gsh ====="] + lines
    line_map = []
    for name, body in sections:
        out += ["", f"// ===== {name} ====="]
        line_map.append((name, len(out) + 1, len(body)))
        out += body
    Path(out_file).write_text("\n".join(out) + "\n", encoding="ascii", newline="\n")
    return line_map


def find_source(line_map, flat_line, flat_name):
    """'origins_menu\\windstart.gsc:120' for a line of the joined file."""
    for name, start, count in line_map:
        if start <= flat_line < start + count:
            return f"{name}:{flat_line - start + 1}"
    return f"{flat_name}:{flat_line}"


def run_gsc_tool(gsc_tool, folder, file, line_map):
    """Compiles file (a path relative to folder) from inside folder and returns the
    compiled file. With a line_map, errors name the original source file and line."""
    proc = subprocess.run(
        [gsc_tool, "--mode", "comp", "--game", "t6", "--system", "pc", str(file)],
        cwd=str(folder), capture_output=True, text=True, errors="replace",
    )
    for text in (proc.stdout + proc.stderr).splitlines():
        if not text.startswith("[ERROR]"):
            continue
        m = re.match(r"^\[ERROR\]:\w+:[^:]+:(\d+):(\d+): (.*)$", text)
        if line_map and m:
            text = "ERROR " + find_source(line_map, int(m.group(1)), str(Path(folder) / file)) + f":{m.group(2)}: {m.group(3)}"
        print(text)
    if proc.returncode != 0:
        raise BuildError(f"gsc-tool could not compile {file}.")
    return Path(folder) / "compiled" / "t6" / Path(str(file).replace("\\", "/")).name


def install_file(src, dst):
    Path(dst).parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def verify_install(src, dst):
    if sha256(src) != sha256(dst):
        raise BuildError(f"installed file differs from the build: {dst}")


# ---------------------------------------------------------------- main
def build_map(info, gsc_tool, deploy, source, deploy_dir):
    map_build = BUILD_DIR / info.name
    map_build.mkdir(parents=True, exist_ok=True)
    files = get_menu_sources(info)

    # Source form: dependency and include checks, then every file on its own.
    test_dependencies(files, info)
    test_project_includes(files)
    source_dir = map_build / "source"
    copy_source_tree(source_dir, info)
    for f in files:
        run_gsc_tool(gsc_tool, source_dir, "scripts\\zm\\" + rel(f), None)
    print(f"[{info.name}] Checked {len(files)} source files")

    # Release form: one script.
    flat = map_build / info.entry_file
    line_map = join_sources(files, flat, info)
    compiled = run_gsc_tool(gsc_tool, map_build, info.entry_file, line_map)
    print(f"[{info.name}] Built {compiled}")

    if not deploy:
        return
    if not info.install:
        print(f"[{info.name}] Skeleton: checked, not installed")
        return

    entry_name = f"{info.entry}/{info.entry_file}"
    entry = deploy_dir / info.entry / info.entry_file
    if entry.exists():
        shutil.copy2(entry, map_build / f"previous-{info.entry_file}")
        print(f"[{info.name}] Backed up the installed {entry_name} to build/{info.name}/previous-{info.entry_file}")
    # Builds before 2026-10-13 named the entry menu.gsc; both would load.
    old_entry = deploy_dir / info.entry / "menu.gsc"
    if old_entry.exists():
        shutil.move(str(old_entry), str(map_build / "previous-menu.gsc"))
        print(f"[{info.name}] Moved the old {info.entry}/menu.gsc to build/{info.name}/previous-menu.gsc")
    if source:
        # Replace the whole source folders, so deleted files do not linger.
        for folder in (CORE, info.folder):
            installed = deploy_dir / folder
            if installed.exists():
                shutil.rmtree(installed)
            shutil.copytree(source_dir / "scripts" / "zm" / folder, installed)
        install_file(source_dir / "scripts" / "zm" / info.entry / info.entry_file, entry)
        print(f"[{info.name}] Installed the source files in {deploy_dir} ({entry_name}, {CORE}/, {info.folder}/)")
    else:
        install_file(compiled, entry)
        verify_install(compiled, entry)
        print(f"[{info.name}] Installed {entry} (SHA-256 verified)")


def build_tools(gsc_tool, deploy, deploy_dir):
    """Each tool is its own script, compiled from a copy in build/z_tools."""
    tools_build = BUILD_DIR / "z_tools"
    tools_build.mkdir(parents=True, exist_ok=True)
    for tool in sorted((ROOT / "z_tools").glob("*.gsc"), key=lambda p: p.name.lower()):
        shutil.copy2(tool, tools_build)
        compiled = run_gsc_tool(gsc_tool, tools_build, tool.name, None)
        print(f"Built {compiled}")
        if deploy:
            install_file(compiled, deploy_dir / tool.name)
            print(f"Installed {deploy_dir / tool.name}")


def parse_args(argv):
    # Accept -Map, -map and --map alike.
    argv = [a.lower() if a.startswith("-") else a for a in argv]
    parser = argparse.ArgumentParser(prog="build.py", description="Builds the practice tool for every map.", allow_abbrev=False)
    parser.add_argument("-map", "--map", nargs="+", default=[], metavar="MAP", help="maps by name or letters (todmb); default all")
    parser.add_argument("-deploy", "--deploy", action="store_true", help="install into the deploy folder")
    parser.add_argument("-deploy-dir", "--deploy-dir", metavar="PATH", help="the game's scripts/zm folder")
    parser.add_argument("-source", "--source", action="store_true", help="install plain sources instead of the compiled release")
    parser.add_argument("-tools", "--tools", action="store_true", help="also build z_tools/*.gsc")
    parser.add_argument("-check", "--check", action="store_true", help="build only (overrides -deploy)")
    return parser.parse_args(argv)


def main(argv):
    args = parse_args(argv)
    deploy = args.deploy and not args.check
    gsc_tool = find_gsc_tool()
    deploy_dir = resolve_deploy_dir(args.deploy_dir) if deploy else None
    BUILD_DIR.mkdir(parents=True, exist_ok=True)

    for info in select_maps(args.map):
        build_map(info, gsc_tool, deploy, args.source, deploy_dir)

    if deploy:
        # Older builds installed scripts/zm/menu.gsc, which would load a second menu.
        old_entry = deploy_dir / "menu.gsc"
        if old_entry.exists():
            shutil.move(str(old_entry), str(BUILD_DIR / "previous-root-menu.gsc"))
            print("Moved the old scripts/zm/menu.gsc to build/previous-root-menu.gsc")
    if args.tools:
        build_tools(gsc_tool, deploy, deploy_dir)


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except BuildError as error:
        print(f"BUILD FAILED: {error}")
        sys.exit(1)
