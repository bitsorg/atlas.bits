# atlas.bits

Recipes and defaults for building **ATLAS Athena** with [bits](https://github.com/bitsorg/bits).
The repository is a thin layer. It builds **AthenaExternals** (`atlasexternals`) and
**Athena** by running ATLAS's own `Projects/Athena/build_externals.sh` and `build.sh`
without changes. The only difference from a standard ATLAS build is where the LCG base
comes from: it is built by bits from the [lcg.bits](https://github.com/bitsorg/lcg.bits)
recipe pool instead of being taken from `/cvmfs/sft.cern.ch/lcg/releases`.
`defaults-atlas.sh` requires [stacks.bits](https://github.com/bitsorg/stacks.bits), which
provides the shared `release` base and the compiler and build-type profiles, and
`stacks.bits` in turn requires `lcg.bits`. bits fetches both automatically through the
[bits-providers](https://github.com/bitsorg/bits-providers) registry.

```
lcg.bits (LCG_110)  -->  lcg-view  -->  atlasexternals  -->  Athena
  recipe pool           LCG manifest    build_externals.sh    build.sh
```

## Prerequisites

- bits and its requirements (Python 3, git, Environment Modules), see the
  [bits installation instructions](https://github.com/bitsorg/bits#installation).
- ATLAS targets `x86_64-el9-gcc15-opt`. The bits-console ATLAS community also offers
  el8, el10 and aarch64-el9; Ubuntu is not a supported Athena platform.
- Network access during the build. `atlasexternals` and `Athena` set
  `sandbox_network: "off"` because `build_externals.sh` clones `atlasexternals` and
  downloads the Gaudi, ACTS, GeoModel and VecMem sources.
- Read access to `https://gitlab.cern.ch/atlas/athena`, which both recipes check out.

## Getting started

```bash
bits init atlas.bits && cd atlas.bits     # or: git clone https://github.com/bitsorg/atlas.bits
bits use build --architecture x86_64-el9 --defaults atlas::gcc15::opt --set release=LCG_110
bits build --dry-run Athena
bits build Athena                         # LCG base, AthenaExternals and Athena
bits enter Athena/latest
```

The `bits use` profile stores the settings in this checkout, so every later
`bits build` here gets them; options given on the command line still win. The build
architecture is `x86_64-el9-gcc15-opt`. `bits build atlasexternals` builds only the LCG
base and AthenaExternals. Check the machine with `bits doctor`. To build elsewhere,
`export BITS_WORK_DIR=/path/to/sw`. The profile format is described in the
[bits user guide](https://github.com/bitsorg/bits/blob/main/docs/USERGUIDE.md#4-configuration).

To use an ATLAS-style setup instead of `bits enter`, source `setupATLAS.sh` from this
repository. It points `LCG_RELEASE_BASE` at the bits-built `lcg-view` and sources the
`setup.sh` of `atlasexternals` and `Athena`. Set `BITS_SW` to your work directory and
`BITS_ARCH=x86_64-el9-gcc15-opt` (the script's default, `x86_64-el9`, holds no packages).

## Notes for ATLAS users

- **Always pass the release on the command line** (`--set release=LCG_110`, or record it
  with `bits use` as above). The value selects the `lcg.bits` and `stacks.bits` branches
  and the CVMFS `{release}` path segment. It also enters every package hash. A release
  chosen any other way hashes differently, so nothing built by the other groups is reused.
  `lcg-view` stops with an error on the default `main`, because the ATLAS manifest needs
  an LCG release number.
- **The LCG view.** `lcg-view` uses `bits overlay lcg` to write
  `LCG_110_ATLAS_5/LCG_externals_<platform>.txt` and `LCG_generators_<platform>.txt` over
  the bits-built closure of `lcg-externals` and `lcg-generators`. The package
  directories in these files point straight at the bits install prefixes. ATLAS's own
  `find_package(LCG 110 EXACT)` (AtlasLCG) reads them, so no ATLAS CMake is changed.
- **The `_ATLAS_5` flavour.** `defaults-atlas.sh` applies the deltas of lcgcmake
  `heptools-110_ATLAS_5.cmake` on top of the neutral `lcg.bits` LCG_110 branch:
  generator and xrootd version pins, the ATLAS-patched `epos4`, `hijing` and
  `madgraph5amc` versions, and the CUDA stack. It also disables `DD4hep` and `acts`
  (AthenaExternals builds its own GeoModel and ACTS), `R`, `rpy2`, `onnxruntime` and
  `tf2onnx`. Other communities using the same branch are not affected.
- **Known gaps.** `tauolacpp` builds `1.1.9.atlas1`, because no `atlas2` patch exists
  yet. The `jax_cuda12_*` packages have no recipe in `lcg.bits`. The `cuda` and `cudnn`
  pins (13.3.1, 9.20.0.48) are newer than the `lcg.bits` recipes support today.
- **What is built.** `atlasexternals` is version 2.1.90 from athena `main`
  (`Projects/Athena/externals.txt`). `Athena` is version 25.0.70 (tag
  `release/25.0.70`), and it currently builds only the `AthExHelloWorld` example and the
  packages it depends on. The package filter is written in `athena.sh`.
- **Developing Athena.** `bits init -c . Athena` creates a writable athena checkout
  next to the recipes; later builds of `Athena` use it. See the bits cookbook on
  [developing a single package](https://github.com/bitsorg/bits/blob/main/docs/COOKBOOK.md#develop-and-iterate-on-a-single-package).
- **CVMFS layout.** Builds publish under `/cvmfs/bits.cern.ch/atlas` with the shared
  [stacks.bits layout](https://github.com/bitsorg/stacks.bits#cvmfs-layout); only the
  prefix differs. `prefix` must match `cvmfs_prefix` in the bits-console ATLAS community
  configuration. When `lcg-view` is published, its `post-relocate.sh` rewrites the
  manifest directories to the published package paths, so `find_package(LCG)` resolves
  against CVMFS. Publishing is done by the bits-console pipeline after a working local
  build.

## Files

| File | Purpose |
|---|---|
| `defaults-atlas.sh` | ATLAS overlay: `stacks.bits` base, release tracking, CVMFS layout, `_ATLAS_5` deltas and disables |
| `lcg-externals.sh`, `lcg-generators.sh` | ATLAS's top-level LCG externals and generators (from the `LCG_110_ATLAS_5` manifest) |
| `lcg-view.sh` | Writes the `LCG_<N>_ATLAS_5` manifests over the bits-built LCG closure |
| `atlasexternals.sh` | AthenaExternals, built with ATLAS's `build_externals.sh` |
| `athena.sh` | Athena, built with ATLAS's `build.sh` |
| `setupATLAS.sh` | Optional `setupATLAS` replacement that uses the bits-built LCG view and projects |

The compiler and build-type profiles (`gcc13`, `gcc14`, `gcc15`, `opt`, `dbg`, `cuda`, ...)
are not part of this repository. They come from `stacks.bits`.

## More information

- [Producing an LCG release view](https://github.com/bitsorg/bits/blob/main/docs/USERGUIDE.md#produce-an-lcg-release-view);
  ATLAS sources: [athena](https://gitlab.cern.ch/atlas/athena) and
  [atlasexternals](https://gitlab.cern.ch/atlas/atlasexternals)
- [stacks.bits](https://github.com/bitsorg/stacks.bits#readme) and
  [lcg.bits](https://github.com/bitsorg/lcg.bits#readme) READMEs: profiles, releases,
  CVMFS layout and the recipe pool; [bits-providers](https://github.com/bitsorg/bits-providers): the registry
- bits [User Guide](https://github.com/bitsorg/bits/blob/main/docs/USERGUIDE.md),
  [Cookbook](https://github.com/bitsorg/bits/blob/main/docs/COOKBOOK.md),
  [Reference](https://github.com/bitsorg/bits/blob/main/docs/REFERENCE.md)
- [bits-console](https://gitlab.cern.ch/buncic/bits-console): CI builds and CVMFS publishing

## License

Apache License 2.0, see [LICENSE](LICENSE).
