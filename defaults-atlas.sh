package: defaults-atlas
version: v1

# ATLAS overlay on stacks.bits (--defaults atlas::gcc15::opt): release tracking and
# the LCG_110 _ATLAS_5 deltas. The LCG postfix and platform live on lcg-view and
# atlasexternals, so the LCG externals keep stacks' hashes.
  
requires:
  - stacks.bits

variables:
  # LCG release, --set release=LCG_110, as in stacks.bits (so the LCG hashes match).
  release: "main"
  # Athena ref, --set athena_release=release/25.0.75 (or main, a commit); it also
  # picks atlasexternals. Not exported: a change rebuilds only athena and atlasexternals.
  athena_release:
    value: "main"
    export: false

# The ATLAS CVMFS namespace and layout are in cvmfs.yaml.

# ===== LCG_110 _ATLAS_5 externals deltas (base lcg.bits LCG_110 + these) =====
overrides:
  # Recipe pool and policy layer at the branch named by `release`.
  lcg.bits:
    tag: "%(release)s"
  stacks.bits:
    tag: "%(release)s"

  # Straight version pins (recipe present, no patch coupling):
  compilebox:
    version: "08.14"
    tag: "08.14"
  herwig3:
    version: "7.3.0p1"
  sherpa:
    version: "3.0.4"
  sherpa-openmpi:
    version: "3.0.4.openmpi3"
    tag: "3.0.4.openmpi3"
  thep8i:
    version: "2.0.6"
  xrootd:
    version: "6.1.1"          # ATLAS pins 6.1.1 over base-110 6.0.3

  # LCG label 429.2 is the 6.4.28 source the recipe already downloads.
  pythia6:
    version: "429.2"
    tag: "429.2"

  # Already the ATLAS values on LCG_110; pinned in case the base drifts:
  cppcheck:
    version: "2.20.0"
  rivet:
    version: "4.1.2"
  thepeg:
    version: "2.3.0"
  vbfnlo:
    version: "3.0"

  # CUDA for gcc15 (gcc14 would need 12.8.1); the lcg.bits recipes do not build these yet.
  cuda:
    version: "13.3.1"         # recipe currently 12.4
  cudnn:
    version: "9.20.0.48"      # recipe currently 8.2.4.15 (major bump)
    tag: "9.20.0.48"

  # ATLAS-patched generators; lcg.bits carries the version-gated patches.
  epos4:
    version: "4.0.3.atlas3"   # epos4-4.0.3.atlas3.patch present (version-gated)
    tag: "4.0.3.atlas3"
  hijing:
    version: "1.383bs.2.atlas20260625"   # hijing-1.383bs.2.atlas20260625.patch present (gated)
    tag: "1.383bs.2.atlas20260625"
  # The 3.5.11 tarball; the recipe's 3.5.11.atlas16 patch applies by version.
  madgraph5amc:
    version: "3.5.11.atlas16"
    tag: "3.5.11.atlas16"
    sources:
      - https://lcgpackages.web.cern.ch/tarFiles/sources/MCGeneratorsTarFiles/MG5_aMC_v3.5.11.tar.gz

  # _ATLAS_5 lists atlas2, but no atlas2 patch exists anywhere yet.
  tauolacpp:
    version: "1.1.9.atlas1"

  # Not in lcg.bits yet: jax_cuda12_plugin, jax_cuda12_pjrt.

disable:
  - R
  - rpy2
  - DD4hep          # AthenaExternals builds GeoModel itself; ATLAS drops LCG DD4hep
  - acts            # AthenaExternals builds its own ACTS (v47.6.1)
  - onnxruntime
  - tf2onnx

---
