#!/bin/bash
# Drop-in for ATLAS's setupATLAS with bits providing the externals and the LCG stack:
#     source setupATLAS.sh; asetup ...
# BITS_SW: the bits install (default: the sw/ beside this script).
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    _bits_self="${BASH_SOURCE[0]}"
else
    _bits_self="${(%):-%x}"   # zsh fallback
fi
_bits_selfdir="$(cd "$(dirname "${_bits_self}")" >/dev/null 2>&1 && pwd)"
: "${BITS_SW:=${_bits_selfdir}/sw}"
: "${BITS_ARCH:=x86_64-el9}"
_bits_base="${BITS_SW}/${BITS_ARCH}"

# 1) LCG: lcg-view's prefix is LCG_RELEASE_BASE, which AtlasLCG's find_package(LCG) reads.
if [ -d "${_bits_base}/lcg-view/latest" ]; then
    export LCG_RELEASE_BASE="${LCG_RELEASE_BASE:-${_bits_base}/lcg-view/latest}"
    echo "setupATLAS.sh: LCG_RELEASE_BASE -> ${LCG_RELEASE_BASE} (bits)"
fi

# 2) Externals and Athena: each project's relocatable setup.sh; Athena's pulls in
# AthenaExternals.
for _p in atlasexternals Athena; do
    if [ -f "${_bits_base}/${_p}/latest/setup.sh" ]; then
        source "${_bits_base}/${_p}/latest/setup.sh"
        echo "setupATLAS.sh: sourced ${_p} (bits)"
    fi
done

# --- 3) stock ALRB setupATLAS (UNCHANGED) ----------------------------------------
# Provides asetup/lsetup exactly as usual; it honours the variables set above.
export ATLAS_LOCAL_ROOT_BASE="${ATLAS_LOCAL_ROOT_BASE:-/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase}"
if [ -f "${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh" ]; then
    source "${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh" "$@"
else
    echo "setupATLAS.sh: ALRB not found at ${ATLAS_LOCAL_ROOT_BASE};" >&2
    echo "               bits externals/LCG env is set, but asetup/lsetup are unavailable." >&2
fi

unset _bits_base _p _bits_self _bits_selfdir
