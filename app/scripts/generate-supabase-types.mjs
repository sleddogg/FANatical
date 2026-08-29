import { spawnSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const appDirectory = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repositoryDirectory = resolve(appDirectory, "..");
const supabaseCliPath = resolve(appDirectory, "node_modules/supabase/dist/supabase.js");
const outputPath = resolve(appDirectory, "src/lib/supabase/database.types.ts");

const result = spawnSync(
  process.execPath,
  [
    supabaseCliPath,
    "gen",
    "types",
    "typescript",
    "--local",
    "--schema",
    "public",
    "--workdir",
    repositoryDirectory,
  ],
  {
    cwd: appDirectory,
    encoding: "utf8",
    maxBuffer: 30 * 1024 * 1024,
    env: { ...process.env, SUPABASE_TELEMETRY_DISABLED: "1" },
  },
);

if (result.error) throw result.error;
if (result.status !== 0) {
  throw new Error([result.stdout, result.stderr].filter(Boolean).join("\n") || "Supabase type generation failed.");
}
if (!result.stdout.startsWith("export type Json")) {
  throw new Error("Supabase type generation returned an unexpected document.");
}

writeFileSync(outputPath, result.stdout, { encoding: "utf8" });
console.log("Generated src/lib/supabase/database.types.ts from the disposable local database.");
