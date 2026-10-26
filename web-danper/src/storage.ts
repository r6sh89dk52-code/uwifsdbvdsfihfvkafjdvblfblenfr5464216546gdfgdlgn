import { trialMode } from "./workspace";
import {
  key,
  type Collection,
  type Change,
  type Entity,
  type Operation,
} from "./model";
export class LocalStore {
  private db!: IDBDatabase;
  async open(name = trialMode ? "danper-web-trial-v1" : "danper-web-v1") {
    this.db = await new Promise<IDBDatabase>((resolve, reject) => {
      const r = indexedDB.open(name, 1);
      r.onupgradeneeded = () => {
        const e = r.result.createObjectStore("entities", { keyPath: "key" });
        e.createIndex("collection", "collection");
        r.result.createObjectStore("outbox", { keyPath: "id" });
        r.result.createObjectStore("meta");
      };
      r.onsuccess = () => resolve(r.result);
      r.onerror = () => reject(r.error);
    });
    return this;
  }
  close() {
    this.db.close();
  }
  async all<T>(collection: Collection): Promise<Entity<T>[]> {
    return this.read("entities", (s) =>
      s.index("collection").getAll(collection),
    );
  }
  async get<T>(
    collection: Collection,
    id: string,
  ): Promise<Entity<T> | undefined> {
    return this.read("entities", (s) => s.get(key(collection, id)));
  }
  async queue(): Promise<Operation[]> {
    return (await this.read<Operation[]>("outbox", (s) => s.getAll())).sort(
      (a, b) => a.createdAt - b.createdAt || a.id.localeCompare(b.id),
    );
  }
  private read<T>(
    table: string,
    fn: (s: IDBObjectStore) => IDBRequest,
  ): Promise<T> {
    return new Promise((resolve, reject) => {
      const r = fn(this.db.transaction(table).objectStore(table));
      r.onsuccess = () => resolve(r.result);
      r.onerror = () => reject(r.error);
    });
  }
  async meta<T>(id: string): Promise<T | undefined> {
    return this.read("meta", (s) => s.get(id));
  }
  async setMeta(id: string, value: unknown) {
    await this.write("meta", (s) => s.put(value, id));
  }
  private write(table: string, fn: (s: IDBObjectStore) => void) {
    return new Promise<void>((resolve, reject) => {
      const tx = this.db.transaction(table, "readwrite");
      fn(tx.objectStore(table));
      tx.oncomplete = () => resolve();
      tx.onabort = () =>
        reject(tx.error || Error("Transacción local cancelada"));
      tx.onerror = () => reject(tx.error);
    });
  }
  async commit(
    changes: Change[],
    deviceId: string,
    enqueue = true,
    id = crypto.randomUUID(),
  ): Promise<void> {
    if (
      !changes.length ||
      changes.length > 180 ||
      new Set(changes.map((c) => key(c.collection, c.id))).size !==
        changes.length
    )
      throw Error("Operación vacía, duplicada o demasiado grande");
    await new Promise<void>((resolve, reject) => {
      const tx = this.db.transaction(["entities", "outbox"], "readwrite");
      const entities = tx.objectStore("entities");
      let failure: Error | undefined;
      for (const c of changes) {
        const r = entities.get(key(c.collection, c.id));
        r.onsuccess = () => {
          const old = r.result as Entity | undefined;
          if ((old?.revision || 0) !== c.expectedRevision) {
            failure = Error("Conflicto de revisión: " + c.collection);
            tx.abort();
            return;
          }
          if (
            ["movements", "attentions", "corrections"].includes(c.collection) &&
            old
          ) {
            failure = Error("El evento guardado es inmutable");
            tx.abort();
            return;
          }
          entities.put({
            key: key(c.collection, c.id),
            collection: c.collection,
            id: c.id,
            revision: c.expectedRevision + 1,
            data: c.data,
            operationId: id,
          });
        };
      }
      if (enqueue && this.db.name !== "danper-web-trial-v1")
        tx.objectStore("outbox").add({
          id,
          deviceId,
          createdAt: Date.now(),
          changes,
          state: "pending",
        } satisfies Operation);
      tx.oncomplete = () => resolve();
      tx.onabort = () =>
        reject(failure || tx.error || Error("No se guardaron los datos"));
      tx.onerror = () => {};
    });
  }
  async acknowledge(id: string) {
    await this.write("outbox", (s) => s.delete(id));
  }
  async conflict(op: Operation, error: string) {
    await this.write("outbox", (s) =>
      s.put({ ...op, state: "conflict", error }),
    );
  }
  async applyRemote(records: Entity[], cursor: number) {
    const pending = await this.queue();
    const dirty = new Set(
      pending.flatMap((o) => o.changes.map((c) => key(c.collection, c.id))),
    );
    await new Promise<void>((resolve, reject) => {
      const tx = this.db.transaction(["entities", "meta"], "readwrite"),
        s = tx.objectStore("entities");
      for (const e of records) {
        if (dirty.has(e.key)) continue;
        const r = s.get(e.key);
        r.onsuccess = () => {
          if (!r.result || r.result.revision < e.revision) s.put(e);
        };
      }
      tx.objectStore("meta").put(cursor, "cursor");
      tx.oncomplete = () => resolve();
      tx.onabort = () => reject(tx.error);
    });
  }
  async snapshot() {
    const result: Record<string, unknown[]> = {};
    for (const c of [
      "workers",
      "allergies",
      "attentions",
      "lots",
      "movements",
      "emo",
      "cholinesterase",
      "leaves",
      "corrections",
      "reconciliations",
      "mappings",
    ] as Collection[])
      result[c] = (await this.all(c)).map((e) => e.data);
    return { schema: "danper-web-1", ...result };
  }
}
export const store = new LocalStore();
export async function put(
  collection: Collection,
  id: string,
  data: unknown,
  enqueue = collection !== "drafts",
) {
  const old = await store.get(collection, id);
  const device = (await store.meta<string>("device")) || crypto.randomUUID();
  await store.setMeta("device", device);
  await store.commit(
    [{ collection, id, expectedRevision: old?.revision || 0, data }],
    device,
    enqueue,
  );
  window.dispatchEvent(
    new CustomEvent("danper-data", { detail: [collection] }),
  );
}
