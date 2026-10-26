export const trialMode =
  typeof localStorage !== "undefined" &&
  localStorage.getItem("danper.workspace") === "trial";
export function switchWorkspace(trial: boolean) {
  localStorage.setItem("danper.workspace", trial ? "trial" : "clinical");
  location.reload();
}
