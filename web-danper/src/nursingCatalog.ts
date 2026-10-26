import { kardexCatalog } from "../legacy/kardexCatalog";
import { reviewedAssociations } from "../legacy/reviewedKardexAssociations";
// N2NativeCatalogIndex: authoritative approvals, TABLETAS and confirmed nursing exceptions.
export const nursingCatalog = kardexCatalog.map((p) => ({
  ...p,
  unit:
    p.group === "TABLETAS"
      ? "UND"
      : ["E-94", "E-95"].includes(p.id)
        ? "CJA"
        : reviewedAssociations.find((a) => a.kardexCode === p.id)
            ?.clinicalUnit ||
          (p.id === "E-86" && p.name === "ALCOHOL 1 LT" ? "FCO" : ""),
}));
