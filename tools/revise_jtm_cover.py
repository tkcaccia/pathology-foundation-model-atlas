#!/usr/bin/env python3
"""Synchronize the cover letter with the 31-cancer manuscript."""

from pathlib import Path

from docx import Document


root = Path(__file__).resolve().parents[1]
source = root / "manuscript/cover_letter_JTM.docx"
output = Path.home() / "Desktop/JTM/cover_letter_JTM_31_cancer_atlas.docx"
document = Document(source)
replacements = {
    1: "Date:  26 October 2026",
    4: ("Manuscript:  Cancer-specific prediction of genomic and immune-related "
        "features from pathology slide representations across 31 TCGA cancers"),
    6: ("We submit this manuscript for consideration as a Research Article in "
        "Journal of Translational Medicine. We assembled a cancer-specific "
        "atlas of genomic and immune-related features estimated from "
        "haematoxylin-and-eosin slide representations. The analysis includes "
        "31 TCGA cancers. For 30 cancers, we compared TITAN, Giga-SSL and "
        "Prov-GigaPath on identical slides and patient-level validation folds. "
        "We also analysed breast cancer with TITAN and Giga-SSL, the two "
        "representations available for that disease."),
    7: ("The study identifies which features are detectable within each cancer "
        "and shows how representation choice changes the result. We report "
        "direct genomic alterations alongside sequencing-derived burdens, "
        "RNA-derived pathways and inferred immune phenotypes, while keeping "
        "their reference sources distinct. A full cancer-by-feature inventory "
        "accompanies the manuscript. PathoFMPred, an R package developed for "
        "this study, applies compatible fitted research models; users may "
        "download the separate Prov-GigaPath coefficient collection on request "
        "through a checksum-verified function."),
    8: ("We believe the work will interest readers in molecular pathology, "
        "translational imaging and medical bioinformatics. It offers a practical "
        "way to prioritize cancer-specific associations for independent study "
        "and to examine where multiple slide representations support the same "
        "feature. The patient-level design, provenance audit and research "
        "software make the atlas useful beyond a ranking of foundation models."),
    9: ("The Supplementary Material and two COAD patient-report examples "
        "accompany the manuscript. The authors declare no competing interests "
        "and received no specific grant for this work."),
}
for index, value in replacements.items():
    document.paragraphs[index].text = value
document.save(output)
print(output)
