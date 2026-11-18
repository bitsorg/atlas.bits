package: lcg-generators
description: ATLAS LCG generators (top-level), seeded from LCG_110_ATLAS_5 (x86_64-el9-gcc15-opt)
version: "1"
license: Apache-2.0
requires:
  - lcg.bits
  - CMake
  - apfel
  - compilebox
  - contur
  - crmc
  - epos4
  - evtgen
  - herwig3
  - hijing
  - hto4l
  - hydjet
  - pepper_kokkos
  - prophecy4f
  - pyquen
  - pythia6
  - SFGen
  - sherpa
  - sherpa-openmpi
  - starlight
  - superchic
  - thep8i
build_requires:
  - bits-recipe-tools
  - "GCC-Toolchain:(?!osx)"
---
