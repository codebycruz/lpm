import { readFileSync } from "fs";
import { resolve } from "path";
import type { APIContext } from "astro";

const script = readFileSync(resolve("../install.ps1"), "utf-8");

export async function GET(_context: APIContext) {
	return new Response(script, {
		headers: {
			"Content-Type": "text/plain; charset=utf-8",
		},
	});
}
