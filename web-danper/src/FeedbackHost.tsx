import { useEffect, useRef, useState } from "react";
import { focusCorrection, notifyFailure, type Feedback } from "./feedback";

export function FeedbackHost() {
  const [feedback, setFeedback] = useState<Feedback | null>(null);
  const dialog = useRef<HTMLDialogElement>(null);
  const origin = useRef<HTMLElement | null>(null);
  useEffect(() => {
    const receive = (event: Event) => {
      origin.current = document.activeElement as HTMLElement;
      setFeedback((event as CustomEvent<Feedback>).detail);
    };
    const rejection = (event: PromiseRejectionEvent) => {
      notifyFailure(event.reason);
    };
    window.addEventListener("danper-feedback", receive);
    window.addEventListener("unhandledrejection", rejection);
    return () => {
      window.removeEventListener("danper-feedback", receive);
      window.removeEventListener("unhandledrejection", rejection);
    };
  }, []);
  useEffect(() => {
    if (feedback && dialog.current) {
      if (!dialog.current.open) dialog.current.showModal();
      dialog.current
        .querySelector<HTMLButtonElement>(".feedback-actions button:last-child")
        ?.focus();
    }
  }, [feedback]);
  function close(correct = false) {
    const current = feedback;
    dialog.current?.close();
    setFeedback(null);
    if (correct && current) focusCorrection(current);
    else if (origin.current?.isConnected)
      origin.current.focus({ preventScroll: true });
  }
  return (
    <dialog
      ref={dialog}
      className={"feedback-dialog " + (feedback?.kind || "")}
      aria-labelledby="feedback-title"
      aria-describedby="feedback-message"
      onCancel={(e) => {
        e.preventDefault();
        close();
      }}
    >
      {feedback && (
        <div className="feedback-body">
          <span className="feedback-symbol" aria-hidden="true">
            {feedback.kind === "success" ? "✓" : "!"}
          </span>
          <span className="eyebrow">
            {feedback.kind === "success"
              ? "OPERACIÓN CONFIRMADA"
              : "REVISA ESTE DATO"}
          </span>
          <h2 id="feedback-title">
            {feedback.title ||
              (feedback.kind === "success"
                ? "Guardado correctamente"
                : "No se pudo completar")}
          </h2>
          <p id="feedback-message">{feedback.message}</p>
          {feedback.kind === "error" && (
            <p className="muted">
              Tus datos permanecen en el formulario. Pulsa Corregir para volver
              al campo que debes revisar.
            </p>
          )}
          <div className="feedback-actions">
            {feedback.kind === "error" && (
              <button className="quiet" onClick={() => close()}>
                Cerrar
              </button>
            )}
            <button autoFocus onClick={() => close(feedback.kind === "error")}>
              {feedback.kind === "error" ? "Corregir" : "Entendido"}
            </button>
          </div>
        </div>
      )}
    </dialog>
  );
}
