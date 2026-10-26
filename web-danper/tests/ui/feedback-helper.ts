import { expect, type Page } from "@playwright/test";
export async function acknowledge(
  page: Page,
  title = "Guardado correctamente",
) {
  const dialog = page.getByRole("dialog", { name: title, exact: true });
  await expect(dialog).toBeVisible();
  await dialog.getByRole("button", { name: "Entendido", exact: true }).click();
  await expect(dialog).not.toBeVisible();
}
