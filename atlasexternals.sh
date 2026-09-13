package: atlasexternals
description: ATLAS AthenaExternals project, built from athena's own build_externals.sh on an lcg.bits LCG base.
version: "2.1.89"       # AthenaExternalsVersion, athena/Projects/Athena/externals.txt
                        # TODO(scoped option 3): read from externals.txt to avoid drift.
tag: "%(version)s"      # NB: the athena source tag (below) is what actually
                        # carries build_externals.sh + externals.txt.
source: https://gitlab.cern.ch/atlas/athena   # carries Projects/Athena/build_externals.sh
requires:
  - lcg-view            # provides $LCG_RELEASE_BASE + the LCG_110_ATLAS_5 manifest
build_requires:
  - bits-recipe-tools
  - CMake
  - ninja
  - Python
  - "GCC-Toolchain:(?!osx)"
env:
  # build_externals.sh reads LCG_PLATFORM and passes -DLCG_VERSION_POSTFIX. Kept
  # on this ATLAS-only recipe, not in shared defaults, so the reusable LCG
  # externals keep stacks-identical hashes.
  LCG_PLATFORM: "x86_64-el9-gcc15-opt"
  LCG_VERSION_POSTFIX: "_ATLAS_5"
system:
  # off = network ALLOWED (sandbox_network is "is the restriction on?"; default
  # on blocks network). build_externals.sh clones atlasexternals and downloads
  # Gaudi/acts/GeoModel/vecmem tarballs, so it needs network. NB this is against
  # bits' reproducible default; cleaner end state is to prefetch those and keep
  # the sandbox closed (follow-up).
  sandbox_network: "off"
---
#!/bin/bash -e
##############################
MODULE_OPTIONS="--bin --lib --cmake"
##############################
# Build AthenaExternals exactly as an ATLAS developer would: run athena's own
# Projects/Athena/build_externals.sh, UNCHANGED. bits supplies the LCG base
# (via lcg-view -> LCG_RELEASE_BASE) and the toolchain; ATLAS's script pins
# atlasexternals (externals.txt) + Gaudi/acts/GeoModel/vecmem + LCG 110.
function Build() {
  export LCG_RELEASE_BASE="${LCG_RELEASE_BASE:?lcg-view must export LCG_RELEASE_BASE}"
  export LCG_PLATFORM="${LCG_PLATFORM:-x86_64-el9-gcc15-opt}"
  # -c disables RPM packaging. build_externals.sh writes build/ + install/
  # beside the source. TODO: confirm its dir flags and route the install tree
  # into $INSTALLROOT so bits captures it as this package's artifact.
  "$SOURCEDIR/Projects/Athena/build_externals.sh" -c
}
