import { getCollection } from "astro:content";
import type { APIContext } from "astro";
import { SITE_URL } from "../data/info";

export async function GET(_context: APIContext) {
	const docs = (await getCollection("docs")).sort((a, b) => {
		const aDir = a.id.split("/").slice(0, -1).join("/");
		const bDir = b.id.split("/").slice(0, -1).join("/");
		if (aDir !== bDir) return aDir.localeCompare(bDir);
		return a.data.order - b.data.order;
	});

	const lines: string[] = [
		`# lpm Documentation`,
		``,
		`> lpm is a fast, modern package manager and runtime for Lua.`,
		`> Source: ${SITE_URL}/docs`,
		``,
	];

	for (const doc of docs) {
		lines.push(`---`);
		lines.push(`## ${doc.data.title}`);
		lines.push(`URL: ${SITE_URL}/docs/${doc.id}/`);
		lines.push(``);
		lines.push(doc.body ?? "");
		lines.push(``);
	}

	return new Response(lines.join("\n"), {
		headers: {
			"Content-Type": "text/plain; charset=utf-8",
		},
	});
}
