package: lcg-view
description: Emit an lcgcmake-style LCG release view over the bits LCG closure so ATLAS find_package(LCG N EXACT) resolves against bits-built packages.
version: "1"
requires:
  # ATLAS's top-level LCG dependency lists (seeded from the LCG_110_ATLAS_5
  # manifest). bits resolves the full transitive closure; this recipe then
  # scans it and writes the LCG_externals/generators manifest below.
  - lcg.bits
  - lcg-externals
  - lcg-generators
build_requires:
  - bits-recipe-tools
env:
  # Consumers read LCG_RELEASE_BASE; it is this package's install prefix (the
  # directory that CONTAINS LCG_110_ATLAS_5/). $LCG_VIEW_ROOT is the bits
  # per-package root var for `lcg-view`.
  LCG_RELEASE_BASE: "$LCG_VIEW_ROOT"
  # Platform/postfix name the emitted manifest (LCG_externals_<platform>.txt and
  # the LCG_110<postfix> dir). Kept on this ATLAS-only recipe, NOT in shared
  # defaults, so they do not invalidate the reusable LCG externals' hashes.
  LCG_PLATFORM: "x86_64-el9-gcc15-opt"
  LCG_VERSION_POSTFIX: "_ATLAS_5"
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
  # `bits lcg-view` scans the built LCG closure in the work dir (each package's
  # .meta.json) and writes $INSTALLROOT/LCG_${relnum}${postfix}/LCG_externals_<plat>.txt
  # (+ generators). $LCG_VIEW_ROOT (=$INSTALLROOT) is then exported as
  # LCG_RELEASE_BASE (see frontmatter), so find_package(LCG) resolves here.
  # TODO(verify on build host): the work dir + arch to pass from inside a recipe
  # build. $ARCHITECTURE is the bits arch; the work dir is the build work dir.
  bits lcg-view \
    --architecture "$ARCHITECTURE" \
    --work-dir "${WORK_DIR:-${BITS_WORK_DIR:-$PWD}}" \
    --platform "$plat" \
    --version-number "$relnum" \
    --postfix "$postfix" \
    --out "$INSTALLROOT"
}
