const paths: Record<string, string> = {
  Trabajadores:
    "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2 M16 3a4 4 0 0 1 0 8 M22 21v-2a4 4 0 0 0-3-3.87 M13 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0",
  "Kardex e inventario":
    "M21 8l-9 5-9-5 M12 13v9 M3 8l9-5 9 5v10l-9 5-9-5z M7 5l9 5",
  EMO: "M9 5H5v17h14V5h-4 M9 3h6v4H9z M8 13h8 M8 17h5",
  Colinesterasa:
    "M9 3h6 M10 3v6l-5 9a2 2 0 0 0 2 3h10a2 2 0 0 0 2-3l-5-9V3 M8 14h8",
  "Descansos médicos":
    "M8 2v4 M16 2v4 M3 10h18 M5 4h14a2 2 0 0 1 2 2v14H3V6a2 2 0 0 1 2-2 M9 15h6 M12 12v6",
  Alertas: "M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9 M10 21h4",
  "Indicadores y exportaciones": "M4 3v18h17 M9 17v-5 M14 17V7 M19 17v-9",
};
export function ModuleIcon({ name }: { name: string }) {
  return (
    <span className="module-icon" aria-hidden="true">
      <svg
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.7"
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d={paths[name] || paths.EMO} />
      </svg>
    </span>
  );
}
export const moduleDetails: Record<string, string> = {
  Trabajadores: "Fichas y padrón",
  "Kardex e inventario": "Stock y movimientos",
  EMO: "Exámenes y seguimiento",
  Colinesterasa: "Campañas y resultados",
  "Descansos médicos": "Descansos y reincorporación",
  Alertas: "Pendientes de tu jornada",
  "Indicadores y exportaciones": "Reportes por período",
};
