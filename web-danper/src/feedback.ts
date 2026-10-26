export type Feedback = {
  kind: "success" | "error";
  title?: string;
  message: string;
  labels?: string[];
  selector?: string;
  scope?: HTMLElement;
  correct?: () => void;
  origin?: HTMLElement;
};
export class FieldError extends Error {
  constructor(
    message: string,
    public labels: string[] = [],
    public correct?: () => void,
    public selector?: string,
  ) {
    super(message);
  }
}
let active = 0;
let saved = new Set<string>();
let failed = false;
function emit(detail: Feedback) {
  if (typeof window !== "undefined")
    window.dispatchEvent(new CustomEvent("danper-feedback", { detail }));
}
export function notifySuccess(
  message: string,
  title = "Guardado correctamente",
) {
  emit({ kind: "success", message, title });
}
export function beginOperation() {
  if (!active) {
    saved.clear();
    failed = false;
  }
  active++;
}
export function finishOperation(ok: boolean) {
  failed ||= !ok;
  active = Math.max(0, active - 1);
  if (!active) {
    if (!failed && saved.size) confirmSaved([...saved]);
    saved.clear();
  }
}
function confirmSaved(collections: string[]) {
  const title = collections.includes("attentions")
    ? "Atención guardada"
    : collections.includes("movements")
      ? "Operación de inventario guardada"
      : collections.includes("lots")
        ? "Stock registrado en Kardex"
        : collections.includes("workers")
          ? "Ficha de trabajador guardada"
          : collections.includes("corrections")
            ? "Rectificación guardada"
            : collections.includes("leaves")
              ? "Descanso médico guardado"
              : collections.some((c) => ["emo", "cholinesterase"].includes(c))
                ? "Exámenes guardados"
                : "Operación guardada";
  notifySuccess(title + ". Los cambios se conservaron en este navegador.");
}
export function notifySaved(collections: string[]) {
  const relevant = collections.filter((c) => c !== "drafts");
  if (!relevant.length) return;
  if (active) relevant.forEach((c) => saved.add(c));
  else confirmSaved(relevant);
}
const hints: [RegExp, string[]][] = [
  [
    /contraseña|cifrad|descifrad/i,
    ["Contraseña del respaldo (no se almacena)"],
  ],
  [
    /archivo|plantilla|respaldo|hoja/i,
    [
      "Importar PERSONAL",
      "Importar exámenes",
      "Plantilla oficial de exámenes",
      "Respaldo cifrado",
    ],
  ],
  [/per[ií]odo/i, ["Desde", "Hasta"]],
  [/vencimiento|fecha del lote/i, ["Vencimiento"]],
  [/lote/i, ["Lote"]],
  [
    /stock|cantidad|envases/i,
    [
      "Cantidad inicial",
      "Ingreso de cerrados / unidades",
      "Conteo de cerrados / unidades",
      "Envases a cerrar",
      "Cantidad",
    ],
  ],
  [/motivo|documento/i, ["Motivo / documento", "Motivo"]],
  [/DNI/i, ["DNI", "Buscar trabajador para atención"]],
  [/nombre|apellidos/i, ["Apellidos y nombres"]],
  [/fecha/i, ["Fecha", "Desde"]],
  [/resultado/i, ["Resultado original"]],
  [/tipo|perfil/i, ["Tipo", "Perfil"]],
  [/producto/i, ["Producto oficial de enfermería", "Buscar producto clínico"]],
];
export function notifyFailure(error: unknown, scope?: HTMLElement) {
  const e = error instanceof Error ? error : new Error(String(error));
  const labels =
    e instanceof FieldError
      ? e.labels
      : hints.find(([pattern]) => pattern.test(e.message))?.[1];
  emit({
    kind: "error",
    message: e.message,
    labels,
    selector: e instanceof FieldError ? e.selector : undefined,
    scope,
    correct: e instanceof FieldError ? e.correct : undefined,
    origin:
      typeof document !== "undefined"
        ? (document.activeElement as HTMLElement)
        : undefined,
  });
}
export function focusCorrection(feedback: Feedback) {
  feedback.correct?.();
  requestAnimationFrame(() =>
    requestAnimationFrame(() => {
      const base = feedback.scope?.isConnected
        ? feedback.scope
        : document.querySelector("main") || document;
      const scope = feedback.selector
        ? document.querySelector<HTMLElement>(feedback.selector) || base
        : base;
      if (scope instanceof HTMLDetailsElement) scope.open = true;
      const fields = Array.from(
        scope.querySelectorAll<HTMLElement>(
          "input:not([type=hidden]),select,textarea,button",
        ),
      ).filter(
        (e) =>
          !e.hasAttribute("disabled") &&
          !e.hasAttribute("readonly") &&
          e.getClientRects().length,
      );
      const label = (e: HTMLElement) =>
        e.getAttribute("aria-label") ||
        e.closest("label")?.querySelector("span")?.textContent ||
        "";
      const target =
        feedback.labels
          ?.map(
            (name) =>
              fields.find((e) => label(e) === name) ||
              fields.find((e) => label(e).startsWith(name)),
          )
          .find(Boolean) ||
        fields.find((e) => e.getAttribute("aria-invalid") === "true") ||
        (!feedback.labels?.length && feedback.origin?.isConnected
          ? feedback.origin
          : undefined) ||
        fields.find(
          (e) =>
            e instanceof HTMLInputElement ||
            e instanceof HTMLSelectElement ||
            e instanceof HTMLTextAreaElement,
        ) ||
        (feedback.origin?.isConnected ? feedback.origin : fields[0]);
      if (!target) return;
      target.scrollIntoView({
        behavior: matchMedia("(prefers-reduced-motion: reduce)").matches
          ? "instant"
          : "smooth",
        block: "center",
      });
      target.focus({ preventScroll: true });
      target.classList.add("needs-correction");
      if (!(target instanceof HTMLButtonElement))
        target.setAttribute("aria-invalid", "true");
      const clear = () => {
        target.classList.remove("needs-correction");
        target.removeAttribute("aria-invalid");
      };
      target.addEventListener("input", clear, { once: true });
      target.addEventListener("change", clear, { once: true });
      if (target instanceof HTMLButtonElement)
        target.addEventListener("click", clear, { once: true });
    }),
  );
}
