import { useState, useEffect } from "preact/hooks";

export interface RegistryPackage {
	name: string;
	description: string | null;
	authors: string[];
	latest: string | null;
	git: string;
	lastUpdated: string | null;
}

const REGISTRY_URL =
	"https://raw.githubusercontent.com/lde-org/registry/refs/heads/dist/index.json";

const CACHE_KEY = "lde-registry-index";
const CACHE_TTL = 5 * 60 * 1000;

function loadCached(): RegistryPackage[] | null {
	try {
		const raw = localStorage.getItem(CACHE_KEY);
		if (!raw) return null;
		const { data, ts } = JSON.parse(raw);
		if (Date.now() - ts > CACHE_TTL) return null;
		return data;
	} catch {
		return null;
	}
}

function saveCache(data: RegistryPackage[]) {
	try {
		localStorage.setItem(
			CACHE_KEY,
			JSON.stringify({ data, ts: Date.now() }),
		);
	} catch {}
}

function sortByDate(packages: RegistryPackage[]): RegistryPackage[] {
	return [...packages].sort((a, b) => {
		if (!a.lastUpdated && !b.lastUpdated)
			return a.name.localeCompare(b.name);
		if (!a.lastUpdated) return 1;
		if (!b.lastUpdated) return -1;
		return (
			new Date(b.lastUpdated).getTime() -
			new Date(a.lastUpdated).getTime()
		);
	});
}

export function useRegistry() {
	const [packages, setPackages] = useState<RegistryPackage[]>([]);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState<string | null>(null);

	useEffect(() => {
		const cached = loadCached();
		if (cached) {
			setPackages(cached);
			setLoading(false);
			return;
		}

		fetch(REGISTRY_URL)
			.then((r) => {
				if (!r.ok)
					throw new Error(`Failed to fetch registry (${r.status})`);
				return r.json();
			})
			.then((data: RegistryPackage[]) => {
				const sorted = sortByDate(data);
				saveCache(sorted);
				setPackages(sorted);
				setLoading(false);
			})
			.catch((e) => {
				setError(e.message);
				setLoading(false);
			});
	}, []);

	return { packages, loading, error };
}
