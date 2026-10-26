#!/usr/bin/env python3
"""Synchronize the cover letter with the 32-cancer manuscript."""

from pathlib import Path

from docx import Document


source = Path.home() / "Desktop/JTM/cover_letter_JTM.docx"
output = Path.home() / "Desktop/JTM/cover_letter_JTM_32_cancer_atlas.docx"
document = Document(source)
replacements = {
    9: "26 October 2026",
    10: ("Manuscript: Cancer-specific prediction of genomic and immune-related "
         "features from pathology slide representations across 32 TCGA cancers"),
    12: ("We are pleased to submit this manuscript as a Research Article for "
         "consideration in Journal of Translational Medicine. We used published "
         "TITAN, Giga-SSL and Prov-GigaPath slide representations to identify "
         "cancer-specific genomic and immune-related features that can be "
         "estimated from haematoxylin-and-eosin images across 32 TCGA cancers. "
         "For the 30 cancers represented by all three resources, we compared "
         "the models using the same patients, slides, outcomes and validation "
         "folds. Separate analyses retained breast cancer and "
         "cholangiocarcinoma in the cancer-specific atlas."),
    13: ("The study gives readers a practical inventory of features reaching "
         "descriptive prediction cutoffs within each cancer. It covers "
         "mutations, fusions and genomic-context alterations alongside "
         "RNA-derived pathways and computational immune phenotypes, while "
         "keeping the different reference measurements distinct. It also "
         "shows where the three slide representations agree and where their "
         "performance differs. PathoFMPred, the accompanying R package, "
         "provides a common interface for the resulting research models and "
         "an optional download of the Prov-GigaPath coefficient collection."),
    14: ("We believe this cancer-by-cancer resource will interest readers in "
         "molecular pathology, translational imaging and medical "
         "bioinformatics. The patient-level design, detailed feature "
         "provenance and reusable modelling interface provide a basis for "
         "selecting promising associations for independent translational "
         "studies and new applications of pathology slide representations."),
    15: ("The Supplementary Material and two COAD patient-report examples "
         "accompany the manuscript. The authors declare no competing "
         "interests and received no specific grant for this work."),
}
for index, value in replacements.items():
    document.paragraphs[index].text = value
document.save(output)
print(output)
