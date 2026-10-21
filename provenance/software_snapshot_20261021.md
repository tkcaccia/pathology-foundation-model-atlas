# Analysis software snapshot

- R: 4.6.0
- fastPLS: 0.4, source revision `265108b6aa250c2534f98ec89037bb5cd001dca0`
- gpuinfo: 0.2.0
- Platform: macOS arm64
- fastPLS CPU numerical library: Apple Accelerate
- fastPLS optional Metal code: compiled; the analysis requests the CPU backend
- PLS component search: 1 to 20
- rSVD numerical controls: package defaults, 32 oversampling vectors and five power iterations
- R random-number algorithm: Mersenne-Twister with Inversion normals and Rejection sampling, fixed before each nested fit and fold draw

The manuscript reports the software version and statistical settings. This repository snapshot retains the exact source revision for computational reproducibility without implying that a software distribution channel is part of the scientific design.
