package: lcg-view
description: Emit an lcgcmake-style LCG release view over the bits LCG closure so ATLAS find_package(LCG N EXACT) resolves against bits-built packages.
# Versioned by LCG release: version_from takes version/tag from the build-wide
# `release` (--set release=LCG_<N>), as in lhcb.bits.
version_from: release
view: true          # `bits enter lcg-view` auto-collapses paths onto the merged view
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
  # Postfix names the emitted LCG_<N><postfix> dir. The platform is derived in
  # the body from the install arch, so it follows the compiler/build-type axes.
  # Kept on this ATLAS-only recipe, NOT in shared defaults (hash isolation).
  LCG_VERSION_POSTFIX: "_ATLAS_5"
---
#!/bin/bash -e
##############################
. $(bits-include ModuleRecipe)
##############################
MODULE_OPTIONS="--none"   # manifest-only; the modulefile exists solely to carry env: to dependents
##############################
# LCGConfig.cmake (atlasexternals/Build/AtlasLCG) expects, under
# $LCG_RELEASE_BASE:
#   LCG_<num><postfix>/LCG_externals_<platform>.txt   name;hash;version;dir;deps
#   LCG_<num><postfix>/LCG_generators_<platform>.txt
# Field 4 (dir) may be ABSOLUTE -> point straight at the bits install prefixes,
# so NO symlink farm and NO cmake files are needed from us (AtlasLCG ships
# LCGConfig + all Find<Foo>.cmake modules and keys off <FOO>_LCGROOT).
# The resolved release: version_from sets PKGVERSION to it however it was chosen.
release="${PKGVERSION:?}"
relnum="${release#LCG_}"; postfix="_ATLAS_5"
[[ "$relnum" =~ ^[0-9]+[a-z]?$ ]] || { echo "lcg-view: '$release' is not an LCG release — build with --set release=LCG_<N>" >&2; exit 1; }
# The install subtree (e.g. x86_64-el9-gcc15-opt) is both what to scan and the LCG
# platform. $ARCHITECTURE is the raw host arch (x86_64-el9), which holds nothing.
plat="${LCG_PLATFORM:-${EFFECTIVE_ARCHITECTURE:?}}"
# `bits overlay lcg` scans the built LCG closure and writes the manifest straight
# into $INSTALLROOT/LCG_${relnum}${postfix}/... (so lcg-view installs directly).
"${BITS_SCRIPT_DIR:?}/bits" overlay lcg \
    --architecture "$EFFECTIVE_ARCHITECTURE" \
    --work-dir "${WORK_DIR:-${BITS_WORK_DIR:-$PWD}}" \
    --platform "$plat" \
    --version-number "$relnum" \
    --postfix "$postfix" \
    --out "$INSTALLROOT"
# The modulefile is the ONLY channel that carries this package's env to its
# dependents (default init.sh-from-modules mode). GenerateModule does not emit
# env:, so write the LCG-view vars here. \$PKG_ROOT (Tcl, set by GenerateModule)
# is the deployed prefix = LCG_RELEASE_BASE.
MakeModule
cat >> "$MODULEFILE" <<EOF
setenv LCG_RELEASE_BASE     \$PKG_ROOT
setenv LCG_PLATFORM         $plat
setenv LCG_VERSION_POSTFIX  $postfix
EOF
