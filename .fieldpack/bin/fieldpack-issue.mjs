#!/usr/bin/env node
// @generated from cli/src; do not edit by hand.

// src/lib/secrets.ts
import { promises as fs, constants as fsConstants } from "fs";
import path from "path";
import os from "os";
var MASTER_DIR = path.join(os.homedir(), ".fieldpack");
var MASTER_PATH = path.join(MASTER_DIR, "secrets.env");
function parseEnvText(text) {
  const out = /* @__PURE__ */ new Map();
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq < 0) continue;
    const key = line.slice(0, eq).trim();
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(key)) continue;
    let value = line.slice(eq + 1).trim();
    if (value.startsWith('"') && value.endsWith('"') || value.startsWith("'") && value.endsWith("'")) {
      value = value.slice(1, -1);
    }
    out.set(key, value);
  }
  return out;
}
async function readMasterSecrets(masterPath = MASTER_PATH) {
  try {
    const text = await fs.readFile(masterPath, "utf8");
    return parseEnvText(text);
  } catch (err) {
    if (err.code === "ENOENT") return null;
    throw err;
  }
}

// src/lib/linear.ts
var KINDS = ["blocker", "decision", "review", "task", "tech-debt"];
function buildIssueInput(args2) {
  if (!KINDS.includes(args2.kind)) {
    throw new Error(`kind must be one of ${KINDS.join(", ")} (got "${args2.kind}")`);
  }
  if (!args2.repo.trim()) {
    throw new Error("repo is required: an issue nobody can route is an issue nobody fixes");
  }
  if (!args2.title.trim()) throw new Error("title is required");
  return {
    teamId: args2.teamId,
    title: args2.title.trim(),
    description: args2.body,
    labelIds: args2.labelIds
  };
}
function resolveLabelIds(labels, repo, kind, fromRepo) {
  const wanted = [`kind:${kind}`, `repo:${repo}`];
  if (fromRepo && fromRepo !== repo) wanted.push(`from:${fromRepo}`);
  const missing2 = wanted.filter((n) => !labels.has(n));
  if (missing2.length > 0) {
    throw new Error(
      `no such label: ${missing2.join(", ")}. Labels are created from portal.yaml; add the repo there or create the label first.`
    );
  }
  return wanted.map((n) => labels.get(n));
}
function provenanceFooter(p) {
  const parts = [`repo \`${p.repo}\``];
  if (p.branch) parts.push(`branch \`${p.branch}\``);
  if (p.sha) parts.push(`commit \`${p.sha}\``);
  return `

---
_Filed by an agent from ${parts.join(", ")}._`;
}
var CREATE_ISSUE = `mutation($input: IssueCreateInput!) {
  issueCreate(input: $input) { success issue { identifier url } }
}`;

// src/commands/issue.ts
var ENDPOINT = "https://api.linear.app/graphql";
function httpApi(token2) {
  return async (query, variables) => {
    const res = await fetch(ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token2}` },
      body: JSON.stringify({ query, variables })
    });
    const json = await res.json();
    if (json.errors?.length) throw new Error(json.errors.map((e) => e.message).join("; "));
    if (!res.ok) throw new Error(`Linear returned HTTP ${res.status}`);
    return json;
  };
}
async function resolveToken(env2) {
  if (env2.LINEAR_ACCESS_TOKEN) return env2.LINEAR_ACCESS_TOKEN;
  const master2 = await readMasterSecrets();
  return master2?.get("LINEAR_ACCESS_TOKEN") || null;
}
async function issueFileCommand(args2, deps) {
  const output = deps.output ?? console.log;
  const errorOutput = deps.errorOutput ?? console.error;
  const token2 = deps.env.LINEAR_ACCESS_TOKEN;
  if (!token2) {
    errorOutput(
      "issue file: LINEAR_ACCESS_TOKEN is not set. It is provisioned by a human into ~/.fieldpack/secrets.env; see docs/operations/agent-control-files.md."
    );
    return 4;
  }
  try {
    const teamKey = deps.env.LINEAR_TEAM_KEY;
    if (!teamKey) {
      errorOutput("issue file: LINEAR_TEAM_KEY is not set.");
      return 4;
    }
    const teams = await deps.api("{ teams { nodes { id key } } }", {});
    const team = teams.data.teams.nodes.find((t) => t.key === teamKey);
    if (!team) {
      errorOutput(`issue file: no team with key "${teamKey}".`);
      return 1;
    }
    const labelData = await deps.api("{ issueLabels(first: 250) { nodes { id name } } }", {});
    const labels = new Map(labelData.data.issueLabels.nodes.map((l) => [l.name, l.id]));
    const labelIds = resolveLabelIds(labels, args2.repo, args2.kind, args2.provenance?.repo);
    const body = args2.body + (args2.provenance ? provenanceFooter(args2.provenance) : "");
    const input = buildIssueInput({
      teamId: team.id,
      repo: args2.repo,
      kind: args2.kind,
      title: args2.title,
      body,
      labelIds
    });
    const created = await deps.api(CREATE_ISSUE, { input });
    const result = created.data.issueCreate;
    if (!result.success || !result.issue) {
      errorOutput("issue file: Linear did not create the issue.");
      return 1;
    }
    output(`\u2713 ${result.issue.identifier}  ${result.issue.url}`);
    return 0;
  } catch (error) {
    errorOutput(`issue file: ${error instanceof Error ? error.message : String(error)}`);
    return 1;
  }
}

// src/bin/fieldpack-issue.ts
var USAGE = `fieldpack-issue \u2014 file work in Linear against the repo that owns the fix

  --repo <name>           the repo that owns the fix \u2014 an unroutable issue is unfixed
  --kind <kind>           one of: ${KINDS.join(", ")}
  --title <title>         one line, specific
  --body <body>           what you observed, what you expected
  --from-repo <name>      the repo you were working in \u2014 this is what makes it a cross-repo
                          edge, so pass it whenever the fix belongs to someone else
  --from-branch <branch>  the branch you were working on
  --from-sha <sha>        the commit you were working at

LINEAR_ACCESS_TOKEN and LINEAR_TEAM_KEY come from ~/.fieldpack/secrets.env, which is
per-machine and provisioned by a human (ADR 0005).`;
function parseArgs(argv2) {
  const out = {};
  for (let i = 0; i < argv2.length; i += 1) {
    const arg = argv2[i];
    if (!arg.startsWith("--")) continue;
    const key = arg.slice(2);
    const next = argv2[i + 1];
    if (next === void 0 || next.startsWith("--")) {
      throw new Error(`--${key} needs a value`);
    }
    out[key] = next;
    i += 1;
  }
  return out;
}
var argv = process.argv.slice(2);
if (argv.length === 0 || argv.includes("--help") || argv.includes("-h")) {
  console.log(USAGE);
  process.exit(argv.length === 0 ? 2 : 0);
}
var opts;
try {
  opts = parseArgs(argv);
} catch (error) {
  console.error(`fieldpack-issue: ${error.message}`);
  process.exit(2);
}
var required = ["repo", "kind", "title", "body"];
var missing = required.filter((k) => !opts[k]);
if (missing.length > 0) {
  console.error(`fieldpack-issue: missing ${missing.map((m) => `--${m}`).join(", ")}`);
  process.exit(2);
}
if (!KINDS.includes(opts["kind"])) {
  console.error(`fieldpack-issue: --kind must be one of: ${KINDS.join(", ")}`);
  process.exit(2);
}
var master = await readMasterSecrets();
var token = await resolveToken(process.env);
if (!token) {
  console.error(
    "fieldpack-issue: LINEAR_ACCESS_TOKEN is not set. It is provisioned by a human into ~/.fieldpack/secrets.env; see the Shopkeep operating docs."
  );
  process.exit(4);
}
var env = {
  LINEAR_ACCESS_TOKEN: token,
  LINEAR_TEAM_KEY: process.env["LINEAR_TEAM_KEY"] ?? master?.get("LINEAR_TEAM_KEY")
};
var args = {
  repo: opts["repo"],
  kind: opts["kind"],
  title: opts["title"],
  body: opts["body"]
};
if (opts["from-repo"]) {
  const p = { repo: opts["from-repo"] };
  if (opts["from-branch"]) p.branch = opts["from-branch"];
  if (opts["from-sha"]) p.sha = opts["from-sha"];
  args.provenance = p;
}
process.exit(await issueFileCommand(args, { env, api: httpApi(token) }));
