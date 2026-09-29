# Author actions required before submission

The authors confirmed that no competing interests and no grant funding apply.
The manuscript now includes a complete CRediT contribution statement.

The remaining archival actions are:

1. Create a versioned source release from the synchronized commits and archive
   it with Zenodo or an equivalent repository.
2. Insert the resulting source-release tag, immutable commits and DOI in the
   manuscript and data-availability statement.

The current working tree is not an archival release and must not be cited as one.

## Completed repository and model-release actions

The earlier synchronized pull requests were merged on 20 September 2026:

1. `tkcaccia/pathology-foundation-model-atlas` pull request 1, merge commit
   `48f3ae935c729d899880e7e6d72372ef87c7a2b0`.
2. `tkcaccia/PathoFMPred` pull request 1, merge commit
   `1813a92e8993cf391e976c3870d15076592db0e2`.
3. `tkcaccia/PathoFMPred-private` pull request 1, merge commit
   `e050dcf6726f1b1ad5ddbab5a6d190f5b70b2653`.

The CRAN fastPLS 0.3 rebuild was committed on 29 September 2026 in the public
PathoFMPred package at `faf9d9b9a80754d3b660bf615025df94c596d247` and in
the private package at `113d343c3742d5083a5490b21c03c4da140925b7`. The analysis repository has been renamed to
`tkcaccia/pathology-foundation-model-atlas` and its complete rerun is the
current source snapshot. These commits are not a versioned archival DOI.

The public package is licensed under MIT for contributor-authored source code
and documentation. Fitted objects are excluded from that grant. The public
`models-v3` release contains only the CRAN-fastPLS-rebuilt Giga-SSL and Prov-GigaPath
collections. GitHub records the same SHA-256 digests pinned by the package,
and an end-to-end `fetch_pathofmpred_models()` test downloaded and validated
both objects. No TITAN fitted object was uploaded. The TITAN collection remains
private unless written redistribution permission is obtained from the upstream
rights holder.

The existing `models-v1` and `models-v2` releases contain older fitted-object
snapshots and do not match the checksums pinned by package version 0.4.0.
Only `models-v3` is the matching optional model-asset release.

## Deferred archival action

At the corresponding author's request, no DOI is being created at this stage.
A versioned source-code release and persistent DOI should be created from the
final synchronized commits before final submission or acceptance. The
`models-v3` asset release is not a substitute for that source-code archive.
