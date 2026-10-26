import { trialMode } from "./workspace";
import { initializeApp } from "firebase/app";
import {
  getAuth,
  GoogleAuthProvider,
  signInWithPopup,
  signOut,
  onAuthStateChanged,
  type User,
} from "firebase/auth";
import {
  initializeFirestore,
  memoryLocalCache,
  doc,
  runTransaction,
  collection,
  query,
  where,
  orderBy,
  limit,
  getDocsFromServer,
  type Firestore,
} from "firebase/firestore";
import { store } from "./storage";
import { key, type Entity, type Operation } from "./model";
const env = import.meta.env;
export const cloudWritesEnabled = env.VITE_CLOUD_WRITES_ENABLED === "true";
export const configured = !!(
  env.VITE_FIREBASE_API_KEY &&
  env.VITE_FIREBASE_PROJECT_ID &&
  env.VITE_AUTHORIZED_UID
);
let db: Firestore | undefined;
let currentUser: User | null = null;
let running = false;
export const syncStatus = {
  message: configured
    ? "Inicia sesión para sincronizar"
    : "Local · Firebase sin configurar",
  pending: 0,
  conflicts: 0,
};
const notify = () => window.dispatchEvent(new Event("danper-sync"));
export function authSetup(listener: (u: User | null) => void) {
  if (!configured) {
    listener(null);
    return () => {};
  }
  const app = initializeApp({
    apiKey: env.VITE_FIREBASE_API_KEY,
    authDomain:
      env.VITE_FIREBASE_AUTH_DOMAIN ||
      env.VITE_FIREBASE_PROJECT_ID + ".firebaseapp.com",
    projectId: env.VITE_FIREBASE_PROJECT_ID,
    appId: env.VITE_FIREBASE_APP_ID,
  });
  db = initializeFirestore(app, { localCache: memoryLocalCache() });
  return onAuthStateChanged(getAuth(app), async (u) => {
    if (u && u.uid !== env.VITE_AUTHORIZED_UID) {
      await signOut(getAuth());
      syncStatus.message = "Cuenta no autorizada";
      listener(null);
      notify();
      return;
    }
    currentUser = u;
    listener(u);
    if (u) await synchronize();
  });
}
export async function login() {
  if (!configured)
    throw Error("Configura el proyecto Firebase y el UID autorizado");
  await signInWithPopup(getAuth(), new GoogleAuthProvider());
}
export async function logout() {
  await signOut(getAuth());
  currentUser = null;
  syncStatus.message = "Sesión cerrada";
  notify();
}
export function checkRevisions(
  operation: Operation,
  remote: (Entity | undefined)[],
) {
  operation.changes.forEach((c, i) => {
    if ((remote[i]?.revision || 0) !== c.expectedRevision)
      throw Error("revision-conflict");
  });
}
async function push(op: Operation) {
  const base = "accounts/" + currentUser!.uid;
  await runTransaction(db!, async (tx) => {
    const receiptRef = doc(db!, base + "/operations/" + op.id),
      metaRef = doc(db!, base + "/syncMeta/clock");
    const receipt = await tx.get(receiptRef);
    if (receipt.exists()) return;
    const clock = await tx.get(metaRef);
    const refs = op.changes.map((c) =>
      doc(db!, base + "/" + c.collection + "/" + c.id),
    );
    const snapshots = [];
    for (const ref of refs) snapshots.push(await tx.get(ref));
    checkRevisions(
      op,
      snapshots.map((s) => (s.exists() ? (s.data() as Entity) : undefined)),
    );
    const sequence = (clock.data()?.sequence || 0) + 1;
    op.changes.forEach((c, i) =>
      tx.set(refs[i], {
        key: key(c.collection, c.id),
        collection: c.collection,
        id: c.id,
        revision: c.expectedRevision + 1,
        data: c.data,
        operationId: op.id,
        sequence,
      }),
    );
    // Each change is its own document: a 10k-person import never creates an oversized receipt.
    tx.set(receiptRef, {
      id: op.id,
      deviceId: op.deviceId,
      sequence,
      createdAt: op.createdAt,
      keys: op.changes.map((c) => key(c.collection, c.id)),
    });
    tx.set(doc(db!, base + "/changes/" + String(sequence).padStart(12, "0")), {
      sequence,
      operationId: op.id,
      keys: op.changes.map((c) => ({ collection: c.collection, id: c.id })),
    });
    tx.set(metaRef, { sequence });
  });
}
async function pull() {
  let cursor = (await store.meta<number>("cursor")) || 0;
  for (;;) {
    const result = await getDocsFromServer(
      query(
        collection(db!, "accounts/" + currentUser!.uid + "/changes"),
        where("sequence", ">", cursor),
        orderBy("sequence"),
        limit(25),
      ),
    );
    if (result.empty) return;
    for (const change of result.docs) {
      const row = change.data();
      const records: Entity[] = [];
      for (const k of row.keys) {
        const { getDocFromServer } = await import("firebase/firestore");
        const snap = await getDocFromServer(
          doc(
            db!,
            "accounts/" + currentUser!.uid + "/" + k.collection + "/" + k.id,
          ),
        );
        if (snap.exists()) records.push(snap.data() as Entity);
      }
      await store.applyRemote(records, row.sequence);
      cursor = row.sequence;
    }
    if (result.size < 25) return;
  }
}
export async function synchronize() {
  if (trialMode) {
    syncStatus.message = "Prueba ficticia local · sin sincronización";
    notify();
    return;
  }
  if (running) return;
  const queued = await store.queue();
  syncStatus.pending = queued.filter((o) => o.state === "pending").length;
  syncStatus.conflicts = queued.filter((o) => o.state === "conflict").length;
  notify();
  if (!configured || !currentUser || !db) return;
  if (!cloudWritesEnabled) {
    syncStatus.message = "Cloud en validación · escrituras desactivadas";
    notify();
    return;
  }
  if (!navigator.onLine) {
    syncStatus.message = "Sin conexión · operaciones conservadas";
    notify();
    return;
  }
  running = true;
  try {
    syncStatus.message = "Sincronizando…";
    notify();
    // A conflict blocks dependent operations; nothing gets silently rebased.
    for (const op of queued) {
      if (op.state === "conflict") break;
      try {
        await push(op);
        await store.acknowledge(op.id);
      } catch (e) {
        if (e instanceof Error && e.message === "revision-conflict") {
          await store.conflict(
            op,
            "Revisión remota distinta; requiere conciliación explícita",
          );
          break;
        }
        throw e;
      }
    }
    await pull();
    const q = await store.queue();
    syncStatus.pending = q.filter((o) => o.state === "pending").length;
    syncStatus.conflicts = q.filter((o) => o.state === "conflict").length;
    syncStatus.message = syncStatus.conflicts
      ? "Conflicto · datos locales conservados"
      : syncStatus.pending
        ? "Operaciones pendientes"
        : "Sincronizado";
    window.dispatchEvent(new Event("danper-data"));
  } catch {
    syncStatus.message = "No se pudo sincronizar · cola conservada";
  } finally {
    running = false;
    notify();
  }
}
