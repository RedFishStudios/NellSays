// Tiny one-shot sync server for AI-driven sessions (Lync-compatible layout).
// Serves the src/ tree as JSON so a Studio plugin/MCP snippet can pull it:
//   node tools/sync.js            -> http://localhost:34875/bundle
// Lync remains the normal workflow for humans: `lync serve`.
const http = require("http");
const fs = require("fs");
const path = require("path");
const root = path.resolve(__dirname, "..");
const project = JSON.parse(fs.readFileSync(path.join(root, "default.project.json"), "utf8"));

function walkTree(node, instPath, out) {
	for (const [key, child] of Object.entries(node)) {
		if (key.startsWith("$") || typeof child !== "object") continue;
		const p = instPath.concat(key);
		if (child.$path) out.push({ instPath: p, dir: path.join(root, child.$path) });
		walkTree(child, p, out);
	}
}

function kindOf(src) {
	const first = src.split(/\r?\n/, 1)[0].trim();
	if (first === "--@script:server") return "Script";
	if (first === "--@script:client") return "ClientScript";
	if (first === "--@localscript") return "LocalScript";
	return "ModuleScript";
}

function collect(dir, instPath, items) {
	for (const name of fs.readdirSync(dir).sort()) {
		const full = path.join(dir, name);
		const stat = fs.statSync(full);
		if (stat.isDirectory()) {
			const init = path.join(full, "Init.luau");
			if (fs.existsSync(init)) {
				const src = fs.readFileSync(init, "utf8");
				items.push({ path: instPath.concat(name), kind: kindOf(src), source: src });
			} else {
				items.push({ path: instPath.concat(name), kind: "Folder" });
			}
			collect(full, instPath.concat(name), items);
		} else if (name.endsWith(".luau") && name !== "Init.luau") {
			const src = fs.readFileSync(full, "utf8");
			items.push({ path: instPath.concat(name.replace(/\.luau$/, "")), kind: kindOf(src), source: src });
		}
	}
}

function bundle() {
	const mounts = [];
	walkTree(project.tree, [], mounts);
	const items = [];
	for (const m of mounts) {
		items.push({ path: m.instPath, kind: "Folder", mount: true });
		collect(m.dir, m.instPath, items);
	}
	return JSON.stringify({ items });
}

const port = Number(process.env.SYNC_PORT || 34875);
http
	.createServer((req, res) => {
		try {
			const body = bundle();
			res.writeHead(200, { "Content-Type": "application/json" });
			res.end(body);
		} catch (e) {
			res.writeHead(500);
			res.end(String(e));
		}
	})
	.listen(port, "127.0.0.1", () => console.log("sync server on " + port));
