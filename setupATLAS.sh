#!/bin/bash
# Drop-in for ATLAS's setupATLAS with bits providing the externals and the LCG stack:
#     source setupATLAS.sh; asetup ...
# Each package from the bits work dir (BITS_SW, default sw/ here), else from CVMFS.
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    _bits_self="${BASH_SOURCE[0]}"
else
    _bits_self="${(%):-%x}"   # zsh fallback
fi
_bits_selfdir="$(cd "$(dirname "${_bits_self}")" >/dev/null 2>&1 && pwd)"
: "${BITS_SW:=${_bits_selfdir}/sw}"
: "${BITS_ARCH:=x86_64-el9-gcc15-opt}"
# The CVMFS prefix: BITS_CVMFS_PREFIX (empty: none), else the one in cvmfs.yaml here.
if [ -n "${BITS_CVMFS_PREFIX+set}" ]; then
    _bits_cvmfs="${BITS_CVMFS_PREFIX}"
else
    _bits_cvmfs=$(sed -n 's/^prefix: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p' "${_bits_selfdir}/cvmfs.yaml" 2>/dev/null)
fi

# The newest entry of directory $1 (not latest), of version $2 if given.
_bits_tags() {
    for _bits_t in $(ls "$1" 2>/dev/null); do
        [ "${_bits_t}" != latest ] || continue
        if [ -z "$2" ] || [ "${_bits_t}" = "$2" ] || [ "${_bits_t#"$2"-}" != "${_bits_t}" ]; then
            echo "${_bits_t}"
        fi
    done | sort -V | tail -1
}
# Package $1 (of version $2, else the latest) in BITS_SW, else on CVMFS
# ({prefix}/{arch}/Packages/{pkg}/{tag}, as in cvmfs.yaml).
_bits_pkg() {
    if [ -z "$2" ] && [ -d "${BITS_SW}/${BITS_ARCH}/$1/latest" ]; then
        echo "${BITS_SW}/${BITS_ARCH}/$1/latest"; return
    fi
    for _bits_d in "${BITS_SW}/${BITS_ARCH}/$1" ${_bits_cvmfs:+"${_bits_cvmfs}/${BITS_ARCH}/Packages/$1"}; do
        _bits_t=$(_bits_tags "${_bits_d}" "$2")
        if [ -n "${_bits_t}" ]; then echo "${_bits_d}/${_bits_t}"; return; fi
    done
}
# Package $2 as $1 was built with it (the tag in $1's init.sh), else the latest.
_bits_dep() {
    _bits_t=$(sed -n "s|.*/$2/\([^/]*\)/etc/profile.d/init.sh.*|\1|p" "$1/etc/profile.d/init.sh" 2>/dev/null | head -1)
    _bits_pkg "$2" "${_bits_t}"
}

# Athena (BITS_ATHENA=25.0.75 picks one), then the atlasexternals and lcg-view it uses.
_bits_athena=$(_bits_pkg Athena "${BITS_ATHENA:-}")
_bits_ext=$(_bits_dep "${_bits_athena}" atlasexternals)
_bits_lcg=$(_bits_dep "${_bits_ext}" lcg-view)

# 1) LCG: lcg-view's prefix is LCG_RELEASE_BASE, which AtlasLCG's find_package(LCG) reads.
if [ -z "${LCG_RELEASE_BASE:-}" ] && [ -n "${_bits_lcg}" ]; then
    export LCG_RELEASE_BASE="${_bits_lcg}"
fi
echo "setupATLAS.sh: LCG_RELEASE_BASE -> ${LCG_RELEASE_BASE:-(none: no lcg-view for ${BITS_ARCH})}"

# 2) Externals and Athena: each project's relocatable setup.sh.
for _bits_p in "${_bits_ext}" "${_bits_athena}"; do
    if [ -f "${_bits_p}/setup.sh" ]; then
        source "${_bits_p}/setup.sh"
        echo "setupATLAS.sh: sourced ${_bits_p}/setup.sh"
    fi
done
[ -n "${_bits_athena}" ] || echo "setupATLAS.sh: no Athena ${BITS_ATHENA:+$BITS_ATHENA }for ${BITS_ARCH}" >&2

# --- 3) stock ALRB setupATLAS (UNCHANGED) ----------------------------------------
# Provides asetup/lsetup exactly as usual; it honours the variables set above.
export ATLAS_LOCAL_ROOT_BASE="${ATLAS_LOCAL_ROOT_BASE:-/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase}"
if [ -f "${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh" ]; then
    source "${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh" "$@"
else
    echo "setupATLAS.sh: ALRB not found at ${ATLAS_LOCAL_ROOT_BASE};" >&2
    echo "               bits externals/LCG env is set, but asetup/lsetup are unavailable." >&2
fi

unset _bits_self _bits_selfdir _bits_cvmfs _bits_p _bits_t _bits_d _bits_athena _bits_ext _bits_lcg
unset -f _bits_tags _bits_pkg _bits_dep
