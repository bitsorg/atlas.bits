# atlas.bits

Policy layer and build recipes for building **ATLAS Athena** with [`bits`](../bits),
using [`lcg.bits`](../lcg.bits) as the external-package pool. Like
[`key4hep.bits`](../key4hep.bits) it is a *policy* repository — it ships almost no
package recipes of its own and points at the ~1100 recipes in `lcg.bits`. Unlike
`key4hep.bits`, it does **not** enumerate a per-package stack: Athena is built as
ATLAS builds it — two large CMake super-projects driven by ATLAS's own scripts —
so `atlas.bits` wraps those scripts rather than replacing them.

The goal is to move the ATLAS build onto a `bits` backend **without changing how
users interact with their build scripts**: `athena/Projects/Athena/build_externals.sh`
and `build.sh` run unchanged; only the LCG release they resolve against is supplied
by `bits` instead of `/cvmfs/sft.cern.ch/lcg/releases`.

---

## Table of Contents
- [Repository Discovery & Provider Model](#repository-discovery--provider-model)
- [How the ATLAS build works on bits](#how-the-atlas-build-works-on-bits)
- [The `defaults-atlas.sh` Overlay (LCG_110 `_ATLAS_5`)](#the-defaults-atlassh-overlay-lcg_110-_atlas_5)
- [The LCG view — satisfying `find_package(LCG)`](#the-lcg-view--satisfying-find_packagelcg)
- [The Recipes: `atlasexternals.sh` and `athena.sh`](#the-recipes-atlasexternalssh-and-athenash)
- [Branches and Releases](#branches-and-releases)
- [Command-Line Usage](#command-line-usage)
- [Local Development](#local-development)
- [Publishing to CVMFS](#publishing-to-cvmfs)
- [Files Overview](#files-overview)

---

## Repository Discovery & Provider Model

`bits` resolves recipes along an ordered search path (`BITS_PATH`). A repository can
be pulled in on demand by a *repository-provider* package — an ordinary recipe with
`provides_repository: true` whose `source` points at a recipe repo. Like every
stacks-based group, `atlas.bits` requires `stacks.bits`, which requires `lcg.bits`:

```
atlas.bits  ──requires──▶  stacks.bits  ──requires──▶  lcg.bits
  defaults-atlas.sh          defaults-release.sh          ROOT, Geant4, Boost, …
  lcg-view.sh, athena.sh,    gcc13/14/15, dbg, cuda, …    (the LCG recipe pool)
  atlasexternals.sh, …
```

`defaults-atlas.sh` points both providers at the branch named by `release`:

```yaml
overrides:
  lcg.bits:
    tag: "%(release)s"
  stacks.bits:
    tag: "%(release)s"
```

The release is given on the command line (`--set release=LCG_110`, see
[Branches and Releases](#branches-and-releases)); it must exist as an `lcg.bits`
and a `stacks.bits` branch.

---

## How the ATLAS build works on bits

ATLAS builds Athena as two CMake super-projects, both consuming an **LCG release**
as their external base:

1. `Projects/Athena/build_externals.sh` builds **AthenaExternals** (from
   `atlas/atlasexternals`, version pinned in `Projects/Athena/externals.txt`),
   layering ATLAS's own Gaudi fork, ACTS, GeoModel and vecmem on top of an
   LCG release found via `find_package(LCG 110 EXACT)` (postfix `_ATLAS_5`).
2. `Projects/Athena/build.sh` builds **Athena** (version in `Projects/Athena/version.txt`)
   on top of AthenaExternals.

`atlas.bits` maps this onto `bits` as:

```
lcg.bits (LCG_110)  ──▶  lcg-view  ──▶  atlasexternals  ──▶  Athena
   recipe pool          LCG manifest    build_externals.sh    build.sh
```

`lcg-view` presents the `bits`-built LCG closure in the layout ATLAS's
`find_package(LCG)` expects, so **ATLAS's CMake and scripts run unmodified** — the
only thing that changes is that the LCG base comes from `bits` (and its signed,
content-addressed store) rather than the SFT CVMFS release.

---

## The `defaults-atlas.sh` Overlay (LCG_110 `_ATLAS_5`)

Composed with `--defaults atlas`, this overlay carries the ATLAS-specific policy:

- `release: main` — a default only; ATLAS builds pass `--set release=LCG_110`.
- `system:` — the ATLAS CVMFS layout (never hashed):
  `{prefix}/{release}/{family}{pkg}/{tag}/{platform}` under `/cvmfs/bits.cern.ch/atlas`,
  modules at `{prefix}/{release}/{platform}/Modules/modulefiles/{pkg}`. `prefix` is an
  auth boundary injected by bits-console and must match the community's `ui-config.yaml`.
- `LCG_PLATFORM` / `LCG_VERSION_POSTFIX=_ATLAS_5` — so `find_package(LCG 110 EXACT)`
  finds a directory `LCG_110_ATLAS_5` and the `LCG_externals_<platform>.txt` manifest.
- `overrides:` — the `_ATLAS_5` externals deltas (lcgcmake `heptools-110_ATLAS_5.cmake`)
  applied on top of the shared base LCG_110 branch: version pins for the ATLAS
  generators and the CUDA stack.
- `disable:` — `DD4hep` and `acts` (**AthenaExternals builds its own** GeoModel and
  ACTS v47.6.1), plus `R`, `rpy2`, `onnxruntime`, `tf2onnx`.

Keeping these deltas in `atlas.bits` (rather than in `lcg.bits`) means the shared
`lcg.bits` LCG_110 branch stays the neutral base LCG 110, and ATLAS's choices ride
on top — other communities using the same pool are unaffected.

> **Patch-coupled entries.** The ATLAS author-patched generators (`epos4`,
> `hijing`, `madgraph5amc`) pin `.atlasN` versions that require the matching author
> patch in the `lcg.bits` recipe; the recipes currently carry the *older* patch, so
> these will not build until the recipe is updated. They are pinned in the overlay
> to record the target. `tauola++` (`lcg.bits/tauolacpp.sh`) and the
> `jax_cuda12_*` packages are named by `_ATLAS_5` but need recipe work too.

---

## The LCG view — satisfying `find_package(LCG)`

ATLAS's `find_package(LCG 110 EXACT)` (config-mode, `atlasexternals/Build/AtlasLCG/
LCGConfig.cmake`) reads, under `$LCG_RELEASE_BASE`:

```
LCG_110_ATLAS_5/LCG_externals_<platform>.txt      # name;hash;version;dir;deps
LCG_110_ATLAS_5/LCG_generators_<platform>.txt
```

and sets each `<PKG>_LCGROOT` from field 4 (`dir`), which **may be an absolute
path**. `lcg-view.sh` emits exactly these manifests over the `bits` LCG closure,
with `dir` pointing straight at the `bits` install prefixes — no symlink farm and
no CMake from us; AtlasLCG (shipped by ATLAS) is the resolver. `lcg-view` exports
`LCG_RELEASE_BASE`, so the view is materialised **locally, before any publish**,
and `bits build Athena` works from the local cache.

The manifest lines are produced by a `bits lcg-view-manifest` helper (the one new
piece of `bits` code this use case needs — the versions/hashes/deps live in the
resolved specs, not in a recipe's shell env).

---

## The Recipes: `atlasexternals.sh` and `athena.sh`

Both check out `atlas/athena` and drive ATLAS's own scripts, so the build is exactly
what an ATLAS developer would run:

| recipe | version from | runs | requires |
|---|---|---|---|
| `atlasexternals` | `externals.txt` (`AthenaExternalsVersion`) | `Projects/Athena/build_externals.sh` | `lcg-view` |
| `Athena` | `version.txt` | `Projects/Athena/build.sh` | `atlasexternals` |

Both set `sandbox_network: "off"` (network **allowed** — `build_externals.sh` clones
`atlasexternals` and downloads the Gaudi/ACTS/GeoModel/vecmem tarballs). This is
against `bits`' reproducible default; the cleaner end state is to prefetch those and
keep the sandbox closed.

---

## Branches and Releases

The `release` label names the `lcg.bits` and `stacks.bits` branches to build against
**and** the CVMFS `{release}` path segment. **Pass it on the command line**
(`--set release=LCG_110`); `main` is only the default. Every stacks-based group
(atlas, lhcb, key4hep, ship) follows the same rule, because a `--set` value is also
exported into the build environment and enters every package hash: a release chosen
any other way (a `release:` in a profile, or the checkout's branch name) hashes
differently and nothing built by the other groups would be reused.

`lcg-view` refuses to build on `main`: the ATLAS manifest needs an LCG release number.

---

## Command-Line Usage

```bash
bits deps  Athena         --defaults atlas::gcc15                          # inspect the dependency tree
bits build atlasexternals --defaults atlas::gcc15 --set release=LCG_110  # the externals layer only
bits build Athena         --defaults atlas::gcc15 --set release=LCG_110  # externals + Athena
```

The base profile `release` comes from `stacks.bits`; overlay it with the compiler/build-type axes
(`gcc15`, `dbg`, …) from `stacks.bits`. ATLAS targets `x86_64-el9-gcc15-opt`.

---

## Local Development

Build with `bits`; explore the result with `bitsenv` (Environment Modules front-end):

```bash
bitsenv q                       # list built modules
bitsenv enter Athena/25.0.72    # subshell with the module(s) loaded
eval `bitsenv printenv Athena/25.0.72`
```

After a local build, the standard ATLAS runtime setup still applies:

```bash
asetup Athena,25.0.72 --releasepath=<build>/install --siteroot=<LCG view>
```

---

## Publishing to CVMFS

The LCG view has two renderings of the same manifest: the **absolute-path** form
(two text files whose `dir` fields point at the local `sw/` prefixes — used for the
local pre-publish build) and the **relocatable** form (relative `dir` + a symlink
farm, i.e. `bits publish --release-view`) for the CVMFS release tree. Publishing is
a follow-on to a working local build, not a prerequisite for it.

---

## Files Overview

| File | Purpose |
|---|---|
| `defaults-atlas.sh` | ATLAS group overlay: `stacks.bits` base, release tracking, CVMFS layout, LCG_110 `_ATLAS_5` deltas + disables |
| `lcg-view.sh` | emits the `LCG_<N>_ATLAS_5` manifest (N from `release`) over the `bits` LCG closure |
| `atlasexternals.sh` | AthenaExternals via ATLAS's `build_externals.sh` |
| `athena.sh` | Athena via ATLAS's `build.sh` |

Compiler/build-type axis profiles (`gcc15`, `dbg`, `cuda`, …) are **not** shipped here — they are inherited from `stacks.bits` when it is on `BITS_PATH`.
