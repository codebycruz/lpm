import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

const learn = defineCollection({
	loader: glob({ pattern: "**/*.md", base: "./src/content/learn" }),
	schema: z.object({
		title: z.string(),
		order: z.number(),
	}),
});

export const collections = { learn };
