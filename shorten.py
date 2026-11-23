"""Shortens the names of a joined release script (every release build, build.py -full skips it).

A compiled T6 script keeps every function name, local variable name, field name and string
literal once, in a string area its 16-bit offsets must reach (64 KB). This pass rewrites a
copy of the joined source (build/<map>/full/<entry>.gsc -> build/<map>/<entry>.gsc) before
it is compiled, so the compiled script carries 1-3 character names. Sources are not touched.
Every distinct name costs its length once however often it is used, so what saves space is
the count of short names, not which name gets which.

Renamed:
  - every project function (defined in the joined file), except main and init, which the
    game calls by name. Only call sites (name followed by "(") and pointers ("::name" with
    no path) change, so vanilla calls written maps\\...::name, fields, variables and strings
    keep their names.
  - every function's parameters and locals (a, b, c ... per function).
  - project-owned fields: written by the project, named by nothing outside it.
  - project-owned flag and notify strings: a string the project uses as a flag or notify
    name, that the project itself creates (flag_init) or both sends and waits on, that
    nothing outside names, and that is never built with "+" or used in any other place than
    a flag call, a notify call, a comparison or a case label.

Kept: vanilla and builtin functions, dvars, cfg keys, displayed text, engine notifies, and
every string a script builds at run time.

"Outside" is the vanilla scripts (..\\t6-scripts-main), the engine's notify list and field
tables (..\\Game-Decomp\\export), the Plutonium docs (..\\plutonium-reference) and our other
tools (CONSUMERS: the B2EE timer reads level.practice_version, for example). A workspace build
writes its verdicts to shorten_owned.txt, which builds without the workspace (CI) read, so
both ship the same bytes. With neither, only functions and locals are renamed.
"""
import csv
import itertools
import re
import string
from pathlib import Path

ROOT = Path(__file__).resolve().parent
WORKSPACE = ROOT.parent

# Names the game calls by name.
KEEP_FUNCTIONS = {"main", "init"}

# Short names never handed out: GSC keywords, and the 1-3 character names in the T6 ZM
# builtin tables (Game-Decomp export/t6zm_gsc_builtins.csv) and the Plutonium docs.
RESERVED = {
    "if", "do", "in", "for", "case", "else", "wait", "self", "game", "anim", "true", "false", "level",
    "c", "cp", "go", "io", "os", "ph", "uk", "us", "ui", "vm",
}

FLAG_CALLS = {
    "flag", "flag_init", "flag_set", "flag_clear", "flag_wait", "flag_waitopen", "flag_exists", "flag_toggle",
    "flag_wait_any", "flag_wait_all", "flag_wait_or_timeout", "flag_waitopen_or_timeout", "flag_set_delayed",
    "flag_clear_delayed", "flag_wait_any_array", "flag_wait_array",
}
NOTIFY_CALLS = {"notify"}
WAIT_CALLS = {
    "waittill", "endon", "waittill_any", "waittill_any_return", "waittill_either", "waittill_multiple",
    "waittill_notify_or_timeout", "waittill_any_timeout", "waittill_any_or_timeout", "waittill_either_return",
    "waittill_any_ents", "waittill_any_ents_two", "waittill_multiple_ents", "waittill_string",
}

_TOKEN_RE = re.compile(
    r'(?P<comment>//[^\n]*|/\*[\s\S]*?\*/)'
    r'|(?P<string>&?"(?:\\.|[^"\\\n])*")'
    r'|(?P<ident>[A-Za-z_]\w*)'
    r'|(?P<path>(?:[A-Za-z_]\w*\\)+[A-Za-z_]\w*)'
    r'|(?P<op>::|==|!=|&&|\|\||<=|>=|\+\+|--|[-+*/%|&^]=|<<|>>|[^\sA-Za-z_"])'
    r'|(?P<space>\s+)'
)


def tokenize(text):
    """(kind, text) pairs that join back to text exactly. Paths like maps\\mp\\x are one token."""
    tokens, pos = [], 0
    path_re = re.compile(r'(?:[A-Za-z_]\w*\\)+[A-Za-z_]\w*')
    while pos < len(text):
        m = path_re.match(text, pos)
        if m and (pos == 0 or not (text[pos - 1].isalnum() or text[pos - 1] == "_")):
            tokens.append(("path", m.group(0)))
            pos = m.end()
            continue
        m = _TOKEN_RE.match(text, pos)
        if not m:
            tokens.append(("op", text[pos]))
            pos += 1
            continue
        tokens.append((m.lastgroup, m.group(0)))
        pos = m.end()
    return tokens


def name_pool(taken):
    """1 character names, then 2, then 3, lowercase (GSC names are case-insensitive)."""
    first = string.ascii_lowercase
    rest = string.ascii_lowercase + string.digits + "_"
    for a in first:
        if a not in RESERVED and a not in taken:
            yield a
    for a in first:
        for b in rest:
            if a + b not in RESERVED and a + b not in taken:
                yield a + b
    for a in first:
        for b in rest:
            for c in rest:
                if a + b + c not in RESERVED and a + b + c not in taken:
                    yield a + b + c
    raise ValueError("name pool exhausted")


def _significant(tokens):
    """Indexes of tokens that are not comments or whitespace."""
    return [i for i, (kind, _) in enumerate(tokens) if kind not in ("comment", "space")]


def find_functions(tokens, sig):
    """Project function names: an identifier at the start of a line followed by "(" ... ")" "{"."""
    defs = set()
    braces = 0
    for n, i in enumerate(sig):
        kind, text = tokens[i]
        braces += (text == "{") - (text == "}")
        if kind != "ident" or braces != 0:
            continue  # definitions only sit outside every function body
        line_start = i == 0 or (tokens[i - 1][0] == "space" and "\n" in tokens[i - 1][1])
        if not line_start or n + 1 >= len(sig) or tokens[sig[n + 1]][1] != "(":
            continue
        depth, k = 0, n + 1
        while k < len(sig):
            t = tokens[sig[k]][1]
            depth += t == "("
            depth -= t == ")"
            k += 1
            if depth == 0:
                break
        if k < len(sig) and tokens[sig[k]][1] == "{":
            defs.add(text.lower())
    return defs


def rename_functions(tokens, sig, mapping, macros=()):
    """Renames call sites and unqualified ::pointers of the functions in mapping. Macro
    names (case-sensitive, ENDINGEMP_ROUND beside endingemp_round) are left alone."""
    count = 0
    for n, i in enumerate(sig):
        kind, text = tokens[i]
        if kind != "ident" or text.lower() not in mapping or text in macros:
            continue
        prev = tokens[sig[n - 1]][1] if n > 0 else ""
        prev2_kind = tokens[sig[n - 2]][0] if n > 1 else ""
        nxt = tokens[sig[n + 1]][1] if n + 1 < len(sig) else ""
        if prev == ".":
            continue  # a field
        if prev == "::":
            if prev2_kind == "path":
                continue  # a qualified call into another script
            tokens[i] = (kind, mapping[text.lower()])
            count += 1
        elif nxt == "(":
            if prev == "define":
                continue  # a function-like macro
            tokens[i] = (kind, mapping[text.lower()])
            count += 1
    return count


def _call_context(tokens, sig):
    """For every string token: the call it is an argument of (or None) and its neighbours."""
    stack, info = [], {}
    for n, i in enumerate(sig):
        kind, text = tokens[i]
        if text == "(":
            callee = None
            if n > 0 and tokens[sig[n - 1]][0] == "ident":
                callee = tokens[sig[n - 1]][1].lower()
            stack.append(callee)
        elif text == ")":
            if stack:
                stack.pop()
        elif kind == "string":
            prev = tokens[sig[n - 1]][1] if n > 0 else ""
            nxt = tokens[sig[n + 1]][1] if n + 1 < len(sig) else ""
            info[n] = (stack[-1] if stack else None, prev, nxt)
    return info


def load_external_strings():
    """Every string the game owns, lowercased, or None when the vanilla dump is missing."""
    vanilla = WORKSPACE / "t6-scripts-main"
    if not vanilla.is_dir():
        return None
    owned = set()
    lit = re.compile(r'"((?:\\.|[^"\\\n])*)"')
    for p in vanilla.rglob("*"):
        if p.is_file() and p.suffix.lower() in (".gsc", ".csc", ".gsh"):
            owned.update(s.lower() for s in lit.findall(p.read_text(encoding="latin-1")))
    notify = WORKSPACE / "Game-Decomp" / "export" / "notify_usage.csv"
    if notify.is_file():
        with notify.open(encoding="utf-8", newline="") as f:
            owned.update(row["event"].lower() for row in csv.DictReader(f))
    docs = WORKSPACE / "plutonium-reference"
    if docs.is_dir():
        word = re.compile(r'["`\']([A-Za-z_][\w ]*)["`\']')
        for p in docs.rglob("*"):
            if p.is_file() and p.suffix.lower() in (".md", ".txt"):
                owned.update(s.lower() for s in word.findall(p.read_text(encoding="utf-8", errors="replace")))
    return owned


def find_owned_strings(tokens, sig, string_ok):
    """Flag and notify strings the project owns (see the module docstring)."""
    info = _call_context(tokens, sig)
    uses = {}
    concat_parts = set()
    for n, (callee, prev, nxt) in info.items():
        value = tokens[sig[n]][1]
        if value.startswith("&"):
            continue
        s = value[1:-1]
        uses.setdefault(s, []).append((callee, prev, nxt))
        if prev == "+" or nxt == "+":
            concat_parts.add(s)
    owned = []
    for s, occurrences in uses.items():
        if not re.fullmatch(r"[A-Za-z_][\w]*", s) or len(s) <= 2:
            continue
        if not string_ok(s) or s in concat_parts:
            continue
        # A name built at run time ("kill" + "_speedometer") must keep its parts. One or two
        # letter parts are display text ("s", "x"), not name pieces.
        if any(len(part) >= 3 and (s.startswith(part) or s.endswith(part)) for part in concat_parts):
            continue
        flag_init = notified = waited = False
        ok = True
        for callee, prev, nxt in occurrences:
            if callee in FLAG_CALLS:
                flag_init |= callee == "flag_init"
            elif callee in NOTIFY_CALLS:
                notified = True
            elif callee in WAIT_CALLS:
                waited = True
            elif prev in ("==", "!=") or nxt in ("==", "!=") or (prev == "case" and nxt == ":"):
                pass
            else:
                ok = False
                break
        if ok and (flag_init or (notified and waited)):
            owned.append(s)
    return sorted(owned)


# Words that are never local variables.
KEYWORDS = {
    "self", "level", "game", "anim", "world", "undefined", "true", "false", "if", "else", "while", "for",
    "foreach", "in", "switch", "case", "default", "break", "continue", "return", "wait", "waittillframeend",
    "thread", "childthread", "do", "notify", "endon", "waittill", "isdefined", "size", "vararg",
}

# Where scripts and tools outside this project read our level fields or script names by name.
CONSUMERS = [
    "T6-B2EE-PATCH", "T6-EE-Timer", "T6-Gnosis/src", "T6-Gnosis/scripts", "T6-ZM-Autosplitter", "BOFA-Counter",
    "T6-B2OP-PATCH", "T6-B2FR-PATCH", "T6-B2SONG-PATCH", "T6-EE-Practice-Tool/z_tools",
]
_WORD_RE = re.compile(r"[A-Za-z_]\w*")


def load_external_words():
    """Every identifier the game, Plutonium or another of our tools may know by name,
    lowercased, or None when the vanilla dump is missing."""
    vanilla = WORKSPACE / "t6-scripts-main"
    if not vanilla.is_dir():
        return None
    words = set()

    def scan(folder, suffixes):
        for p in folder.rglob("*"):
            if "vendor" in p.parts or "build" in p.parts or "bin" in p.parts or "obj" in p.parts:
                continue
            if p.is_file() and p.suffix.lower() in suffixes:
                words.update(w.lower() for w in _WORD_RE.findall(p.read_text(encoding="latin-1")))

    scan(vanilla, (".gsc", ".csc", ".gsh"))
    for name in CONSUMERS:
        folder = WORKSPACE / name
        if folder.is_dir():
            scan(folder, (".gsc", ".gsh", ".csc", ".cpp", ".hpp", ".h", ".c", ".cs", ".py", ".lua"))
    docs = WORKSPACE / "plutonium-reference"
    if docs.is_dir():
        scan(docs, (".md", ".txt"))
    decomp = WORKSPACE / "Game-Decomp" / "export"
    for name in ("t6zm_field_tables.csv", "t6zm_struct_fields.tsv", "t6zm_field_labels.tsv"):
        if (decomp / name).is_file():
            words.update(w.lower() for w in _WORD_RE.findall((decomp / name).read_text(encoding="latin-1")))
    return words


def find_owned_fields(tokens, sig, field_ok, kept_names):
    """Fields only this script uses: written here, named by nothing outside the project."""
    written, seen = set(), set()
    for n, i in enumerate(sig):
        if tokens[i][0] != "ident" or n == 0 or tokens[sig[n - 1]][1] != ".":
            continue
        name = tokens[i][1].lower()
        seen.add(name)
        if n + 1 < len(sig) and tokens[sig[n + 1]][1] in ("=", "[", "++", "--", "+=", "-=", "*=", "/=", "%=", "|=", "&=", "^="):
            written.add(name)
    return sorted(f for f in written if field_ok(f) and f not in kept_names and len(f) > 2)


def rename_fields(tokens, sig, mapping):
    for n, i in enumerate(sig):
        kind, text = tokens[i]
        if kind == "ident" and n > 0 and tokens[sig[n - 1]][1] == "." and text.lower() in mapping:
            tokens[i] = (kind, mapping[text.lower()])


def _is_local(tokens, sig, n, keep):
    kind, text = tokens[sig[n]]
    if kind != "ident" or text.lower() in keep:
        return False
    prev = tokens[sig[n - 1]][1] if n > 0 else ""
    nxt = tokens[sig[n + 1]][1] if n + 1 < len(sig) else ""
    if prev == "%":
        # %name is an animation, a % b is modulo.
        before = tokens[sig[n - 2]] if n > 1 else ("op", "")
        if not (before[0] == "ident" or before[1] in (")", "]") or before[1].isdigit()):
            return False
    return prev not in (".", "::", "#") and nxt != "("


def rename_locals(tokens, sig, keep):
    """Renames each function's parameters and local variables to a, b, c, ... The names
    only exist in the string area, so every function reuses the same few."""
    pool_names = list(itertools.islice((n for n in name_pool(set()) if n not in keep), 2000))
    total, braces, n = set(), 0, 0
    while n < len(sig):
        text = tokens[sig[n]][1]
        if braces == 0 and tokens[sig[n]][0] == "ident" and n + 1 < len(sig) and tokens[sig[n + 1]][1] == "(":
            # A definition: header, then its body.
            start, depth, k = n + 1, 0, n + 1
            while k < len(sig):
                t = tokens[sig[k]][1]
                depth += t == "("
                depth -= t == ")"
                k += 1
                if depth == 0:
                    break
            if k >= len(sig) or tokens[sig[k]][1] != "{":
                n += 1
                continue
            body_end, depth = k, 0
            while body_end < len(sig):
                t = tokens[sig[body_end]][1]
                depth += t == "{"
                depth -= t == "}"
                body_end += 1
                if depth == 0:
                    break
            counts = {}
            for m in range(start, body_end):
                if _is_local(tokens, sig, m, keep):
                    name = tokens[sig[m]][1].lower()
                    counts[name] = counts.get(name, 0) + 1
            order = sorted(counts, key=lambda v: (-counts[v], v))
            mapping = dict(zip(order, pool_names))
            for m in range(start, body_end):
                if _is_local(tokens, sig, m, keep):
                    tokens[sig[m]] = ("ident", mapping[tokens[sig[m]][1].lower()])
            total.update(order)
            n = body_end
            continue
        braces += (text == "{") - (text == "}")
        n += 1
    return total


# ---------------------------------------------------------------- what the outside world names
OWNED_FILE = ROOT / "shorten_owned.txt"
SHORT_MAX = 3  # new names are 1-3 characters, so only outside names this short can clash


class Outside:
    """Answers "may this field or string be renamed" and "which short names are in use
    outside". From the workspace (vanilla dump and the rest, see load_external_*), or from
    shorten_owned.txt, which a workspace build writes so CI renames the same names."""

    def __init__(self, field_ok, string_ok, taken, source):
        self.field_ok, self.string_ok, self.taken, self.source = field_ok, string_ok, taken, source

    @staticmethod
    def from_workspace():
        strings, words = load_external_strings(), load_external_words()
        if strings is None or words is None:
            return None
        # Only names the pool could hand out (lowercase identifiers) can clash.
        taken = {w for w in words | strings if len(w) <= SHORT_MAX and re.fullmatch(r"[a-z_][a-z0-9_]*", w)}
        return Outside(lambda f: f.lower() not in words, lambda s: s.lower() not in strings, taken, "workspace")

    @staticmethod
    def from_file(path=OWNED_FILE):
        if not Path(path).is_file():
            return None
        sections = read_owned_file(path)
        fields, strings = set(sections["fields"]), set(sections["strings"])
        return Outside(lambda f: f in fields, lambda s: s in strings, set(sections["taken"]), Path(path).name)


def read_owned_file(path=OWNED_FILE):
    sections, current = {"fields": [], "strings": [], "taken": []}, None
    for line in Path(path).read_text(encoding="ascii").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
        elif current in sections:
            sections[current].append(line)
    return sections


def update_owned_file(reports, project_files, path=OWNED_FILE):
    """Writes the fields and strings the workspace judged project-owned, for CI. Names from
    maps not built this time are kept while the project still names them and they still
    pass, so building one map does not drop the others. Returns True when the file changed."""
    outside = Outside.from_workspace()
    if outside is None:
        return False
    words = set()
    for f in project_files:
        words.update(_WORD_RE.findall(Path(f).read_text(encoding="utf-8-sig")))
    old = read_owned_file(path) if Path(path).is_file() else {"fields": [], "strings": [], "taken": []}
    fields = {f for f in old["fields"] if f in words and outside.field_ok(f)}
    strings = {s for s in old["strings"] if s in words and outside.string_ok(s)}
    for report in reports:
        fields.update(report["fields"])
        strings.update(report["strings"])
    out = [
        "# Generated by build.py (shorten.py) from ..\\t6-scripts-main, the engine tables, the Plutonium docs and",
        "# our other tools. Commit it: CI has none of those and renames exactly these names. Do not edit.",
        "# fields and strings: project-owned names that may be renamed. taken: short names in use outside.",
        "[fields]", *sorted(fields), "[strings]", *sorted(strings), "[taken]", *sorted(outside.taken),
    ]
    text = "\n".join(out) + "\n"
    if Path(path).is_file() and Path(path).read_text(encoding="ascii") == text:
        return False
    Path(path).write_text(text, encoding="ascii", newline="\n")
    return True


def shorten(text, outside=None):
    """Returns (new text, report dict). outside=None renames functions and locals only."""
    tokens = tokenize(text)
    sig = _significant(tokens)
    for n, i in enumerate(sig):
        if tokens[i][1] == "::" and n > 0 and tokens[sig[n - 1]][0] == "path":
            path = tokens[sig[n - 1]][1].lower()
            if path.startswith("scripts\\zm\\"):
                raise ValueError(f"qualified call into a project file ({path}): not supported")
    functions = sorted(find_functions(tokens, sig) - KEEP_FUNCTIONS)
    macro_lines = re.findall(r"(?m)^[ \t]*#define[ \t]+(\w+)(.*)$", text)
    exact_macros = {name for name, _ in macro_lines}
    macros = {name.lower() for name in exact_macros}
    fnames = set(functions)
    defined = {tokens[i][1] for n, i in enumerate(sig[:-1])
               if tokens[i][0] == "ident" and tokens[i][1].lower() in fnames and tokens[sig[n + 1]][1] == "("}
    clash = exact_macros & defined
    if clash:
        raise ValueError(f"#define and function share a name: {sorted(clash)}")
    # A macro body that names a variable ties that name to its callers: keep those names.
    macro_words = {w.lower() for _, body in macro_lines for w in _WORD_RE.findall(re.sub(r'"[^"]*"', "", body))}

    # Every identifier already in the script stays distinct from the new names, so a new
    # name never meets a vanilla function, a builtin, a variable or a macro.
    taken = {t.lower() for k, t in tokens if k == "ident"}
    pool = name_pool(taken)
    # Most used first. Every distinct name is stored once whatever its use count, so the
    # order does not change the size, it only makes the compiled script easier to diff.
    counts = {}
    for k, t in tokens:
        if k == "ident" and t.lower() in fnames:
            counts[t.lower()] = counts.get(t.lower(), 0) + 1
    order = sorted(functions, key=lambda f: (-counts.get(f, 0), f))
    fmap = {f: next(pool) for f in order}
    fcount = rename_functions(tokens, sig, fmap, exact_macros)

    smap, field_map = {}, {}
    if outside is not None:
        owned = find_owned_strings(tokens, sig, outside.string_ok)
        # Strings live in the same area as names: reusing the function names costs nothing.
        literals = {t[1:-1].lower() for k, t in tokens if k == "string"}
        free = lambda name: name not in literals and name not in outside.taken
        reuse = (name for name in fmap.values() if free(name))
        extra = (name for name in name_pool(taken | set(fmap.values())) if free(name))
        for s in owned:
            smap[s] = next(reuse, None) or next(extra)
        for n, i in enumerate(sig):
            kind, value = tokens[i]
            if kind == "string" and not value.startswith("&") and value[1:-1] in smap:
                tokens[i] = (kind, '"' + smap[value[1:-1]] + '"')

        # Fields: new names stay clear of every field and short name anything else may use.
        fields = find_owned_fields(tokens, sig, outside.field_ok, macros)
        field_taken = taken | outside.taken | set(fields)
        reuse = (name for name in fmap.values() if name not in field_taken)
        extra = name_pool(field_taken | set(fmap.values()))
        for f in fields:
            field_map[f] = next(reuse, None) or next(extra)
        rename_fields(tokens, sig, field_map)

    keep = KEYWORDS | RESERVED | macros | macro_words
    locals_renamed = rename_locals(tokens, sig, keep)
    out = "".join(t for _, t in tokens)
    return out, {
        "functions": fmap,
        "function_sites": fcount,
        "strings": smap,
        "fields": field_map,
        "locals": len(locals_renamed),
        "outside": outside.source if outside else None,
    }


