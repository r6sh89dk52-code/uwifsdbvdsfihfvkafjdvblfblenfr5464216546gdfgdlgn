import { organizationDirectory } from "../legacy/organizationDirectory";
export function readOfficialOrganization() {
  return ["LA VENTUROSA", "PLVENTUROSA"].flatMap((site) =>
    organizationDirectory().areas[site].map((a) => ({ ...a, site })),
  );
}
