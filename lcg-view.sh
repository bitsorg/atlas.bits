package: lcg-view
description: Emit an lcgcmake-style LCG release view over the bits LCG closure,
  so ATLAS find_package(LCG N EXACT) resolves against bits-built packages.
version: "1"
requires:
  # The LCG closure this view describes must be present in the local cache
  # before the manifest is generated. TODO: confirm the LCG externals
  # meta-package name in lcg.bits / stacks.bits (e.g. `externals`).
  - lcg.bits
  - externals
build_requires:
  - bits-recipe-tools
env:
  # Consumers read LCG_RELEASE_BASE; it is this package's install prefix (the
  # directory that CONTAINS LCG_110_ATLAS_5/). $LCG_VIEW_ROOT is the bits
  # per-package root var for `lcg-view`.
  LCG_RELEASE_BASE: "$LCG_VIEW_ROOT"
---
#!/bin/bash -e
##############################
MODULE_OPTIONS="--none"    # installs a manifest (data), no bin/lib
##############################
# LCGConfig.cmake (atlasexternals/Build/AtlasLCG) expects, under
# $LCG_RELEASE_BASE:
#   LCG_<num><postfix>/LCG_externals_<platform>.txt   name;hash;version;dir;deps
#   LCG_<num><postfix>/LCG_generators_<platform>.txt
# Field 4 (dir) may be ABSOLUTE -> point straight at the bits install prefixes,
# so NO symlink farm and NO cmake files are needed from us (AtlasLCG ships
# LCGConfig + all Find<Foo>.cmake modules and keys off <FOO>_LCGROOT).
function Build() {
  local relnum="110" postfix="_ATLAS_5"
  local plat="${LCG_PLATFORM:-x86_64-el9-gcc15-opt}"
  local dest="$INSTALLROOT/LCG_${relnum}${postfix}"
  mkdir -p "$dest"
  # NEW bits helper (the one genuinely new piece): dump the resolved LCG closure
  # as  name;hash;version;<abs install prefix>;deps  — bits has all of these,
  # a recipe bash body does not. Split externals vs generators by recipe class.
  bits lcg-view-manifest --closure externals  --abs-paths > "$dest/LCG_externals_${plat}.txt"
  bits lcg-view-manifest --closure generators --abs-paths > "$dest/LCG_generators_${plat}.txt"
}
