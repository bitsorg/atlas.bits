package: lcg-view
description: Emit an lcgcmake-style LCG release view over the bits LCG closure so ATLAS find_package(LCG N EXACT) resolves against bits-built packages.
# Versioned by the LCG release (--set release=LCG_<N>).
version_from: release
view: true          # `bits enter lcg-view` auto-collapses paths onto the merged view
requires:
  # ATLAS's top-level LCG lists; the manifest below covers their whole closure.
  - lcg.bits
  - lcg-externals
  - lcg-generators
build_requires:
  - bits-recipe-tools
env:
  # The directory containing LCG_110_ATLAS_5/, read by consumers.
  LCG_RELEASE_BASE: "$LCG_VIEW_ROOT"
  # Names LCG_<N><postfix>; here, not in the shared defaults, to keep stacks' hashes.
  LCG_VERSION_POSTFIX: "_ATLAS_5"
---
#!/bin/bash -e
##############################
. $(bits-include ModuleRecipe)
##############################
MODULE_OPTIONS="--none"   # manifest-only; the modulefile exists solely to carry env: to dependents
##############################
# AtlasLCG reads $LCG_RELEASE_BASE/LCG_<num><postfix>/LCG_{externals,generators}_<platform>.txt
# (name;hash;version;dir;deps). dir points straight at the bits install prefixes;
# a CVMFS publish rewrites it to the published paths (post-relocate.sh below).
release="${PKGVERSION:?}"
relnum="${release#LCG_}"; postfix="_ATLAS_5"
[[ "$relnum" =~ ^[0-9]+[a-z]?$ ]] || { echo "lcg-view: '$release' is not an LCG release — build with --set release=LCG_<N>" >&2; exit 1; }
# The install subtree (e.g. x86_64-el9-gcc15-opt) is both what to scan and the LCG
# platform. $ARCHITECTURE is the raw host arch (x86_64-el9), which holds nothing.
plat="${LCG_PLATFORM:-${EFFECTIVE_ARCHITECTURE:?}}"
# `bits overlay lcg` scans the built LCG closure and writes the manifest straight
# into $INSTALLROOT/LCG_${relnum}${postfix}/... (so lcg-view installs directly).
wd="${WORK_DIR:-${BITS_WORK_DIR:-$PWD}}"
"${BITS_SCRIPT_DIR:?}/bits" overlay lcg \
    --architecture "$EFFECTIVE_ARCHITECTURE" \
    --work-dir "$wd" \
    --platform "$plat" \
    --version-number "$relnum" \
    --postfix "$postfix" \
    --out "$INSTALLROOT" \
    --closure "$INSTALLROOT/.meta.json"

# Per-entry publish identity (templates, version-revision, family, arch) for the
# CVMFS rewrite below. Same scan as the overlay, so the entries match its lines.
mkdir -p "$INSTALLROOT/etc/lcg-view"
python3 - "$wd" "$EFFECTIVE_ARCHITECTURE" "$INSTALLROOT/etc/lcg-view/entries.json" <<\PY
import json, os, sys
sys.path.insert(0, os.environ["BITS_SCRIPT_DIR"])
from bits_helpers.overlay.lcg import closure_of, collect, manifest_line
wd, arch, out = sys.argv[1:]
records, _, errors = collect(wd, arch, closure_of(os.environ["INSTALLROOT"] + "/.meta.json"))
if errors:
    sys.exit("lcg-view: " + "; ".join(errors))
entries = []
for name, (install_dir, meta) in sorted(records.items()):
    pkg = meta["package"]
    rev = str(pkg.get("revision") or "")
    entries.append({
        "name": name,
        "line": manifest_line(name, os.path.abspath(install_dir), meta),
        "pkg": pkg["name"], "version": pkg["version"], "revision": rev,
        "tag": pkg["version"] + ("-" + rev if rev else ""),
        "family": pkg.get("pkg_family") or "",
        "arch": pkg.get("effective_architecture") or arch,
        "templates": meta.get("cvmfs_templates") or {}})
with open(out, "w") as fh:
    json.dump(entries, fh, indent=1)
PY

# On a CVMFS publish (bits cvmfs publish: INSTALL_BASE under /cvmfs, templated
# layout) the manifest must name where the OTHER packages are published. That is
# only known then, so derive it from this package's own final path and template.
cat > "$INSTALLROOT/etc/lcg-view/cvmfs-manifest.py" <<\PY
# Rewrite the manifest dirs to the packages' CVMFS paths, from the publishing build's
# templates (BITS_CVMFS_TEMPLATES), else each package's own; the run's context comes
# from matching INSTALL_BASE against this package's template.
import json, os, re, sys
root = os.path.join(os.environ["WORK_DIR"], os.environ["PP"])
base = os.environ["INSTALL_BASE"].rstrip("/")
with open(os.path.join(root, ".meta.json")) as fh:
    meta = json.load(fh)
with open(os.path.join(root, "etc/lcg-view/entries.json")) as fh:
    entries = json.load(fh)
CONTEXT = {"prefix": ".+", "platform": "[^/]*", "install_dir": "[^/]*", "user": "[^/]*"}
run = json.loads(os.environ.get("BITS_CVMFS_TEMPLATES") or "{}")

def fill(tmpl, e):
    fam = e["family"] + "/" if e["family"] else ""
    for k, v in (("pkg", e["pkg"]), ("tag", e["tag"]), ("version", e["version"]),
                 ("revision", e["revision"]), ("family", fam), ("arch", e["arch"])):
        tmpl = tmpl.replace("{%s}" % k, v)
    return tmpl

def template(e, tm):
    # A packages template is where the package trees are; "path" is then only
    # the release view.
    tree = tm.get("packages") or tm.get("path")
    t = (tm.get("shared") or tree) if e["arch"] in ("share", "shared") else tree
    if not t:
        sys.exit("lcg-view: %s has no CVMFS template" % e["pkg"])
    return t

pkg = meta["package"]
rev = str(pkg.get("revision") or "")
me = {"pkg": pkg["name"], "version": pkg["version"], "revision": rev,
      "arch": pkg.get("effective_architecture") or meta.get("architecture") or "",
      "tag": pkg["version"] + ("-" + rev if rev else ""), "family": pkg.get("pkg_family") or ""}
pattern = fill(template(me, run or meta.get("cvmfs_templates") or {}), me)
rx, pos, seen = "", 0, set()
for m in re.finditer(r"\{(\w+)\}", pattern):
    name = m.group(1)
    if name not in CONTEXT:
        sys.exit("lcg-view: unsupported {%s} in CVMFS template %s" % (name, pattern))
    rx += re.escape(pattern[pos:m.start()])
    rx += "(?P=%s)" % name if name in seen else "(?P<%s>%s)" % (name, CONTEXT[name])
    seen.add(name)
    pos = m.end()
rx += re.escape(pattern[pos:])
m = re.fullmatch(rx, base)
if not m:
    sys.exit("lcg-view: %s does not match its template %s" % (base, pattern))
context = m.groupdict()

lines = []
for e in entries:
    d = fill(template(e, run or e["templates"]), e)
    for k, v in context.items():
        d = d.replace("{%s}" % k, v)
    if re.search(r"\{\w+\}", d):
        sys.exit("lcg-view: unresolved token in %s for %s" % (d, e["pkg"]))
    f = e["line"].split(";")
    f[3] = d
    lines.append(";".join(f))
manifest = sys.argv[1]
with open(manifest + ".tmp", "w") as fh:
    fh.write("\n".join(lines) + "\n")
os.replace(manifest + ".tmp", manifest)
print("lcg-view: %d manifest entries rewritten for %s" % (len(lines), base))
PY
mkdir -p "$INSTALLROOT/etc/profile.d"
cat > "$INSTALLROOT/etc/profile.d/post-relocate.sh" <<EOF
# lcg-view: templated CVMFS publish -> point the manifest at the published packages.
if [ -n "\${BITS_RELOCATE_STRIP_PP:-}" ]; then
  case "\${INSTALL_BASE:-}" in
    /cvmfs/*) python3 "\$WORK_DIR/\$PP/etc/lcg-view/cvmfs-manifest.py" \\
                "\$WORK_DIR/\$PP/LCG_${relnum}${postfix}/LCG_externals_$plat.txt" ;;
  esac
fi
EOF
# The modulefile carries this package's env to its dependents and GenerateModule
# does not emit env:, so set the LCG-view variables here (\$PKG_ROOT = LCG_RELEASE_BASE).
MakeModule
cat >> "$MODULEFILE" <<EOF
setenv LCG_RELEASE_BASE     \$PKG_ROOT
setenv LCG_PLATFORM         $plat
setenv LCG_VERSION_POSTFIX  $postfix
EOF
