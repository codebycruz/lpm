import { useState } from "preact/hooks";
import { GITHUB_RELEASES_URL } from "../data/info";

function detectOS(): string {
	const p = navigator.platform.toLowerCase();
	if (p.includes("win")) return "windows";
	return "linux";
}

const tabs = [
	{
		id: "linux",
		label: "Linux",
		command:
			"curl -fsSL https://raw.githubusercontent.com/codebycruz/lpm/HEAD/install.sh | sh",
	},
	{
		id: "windows",
		label: "Windows",
		command:
			"irm https://raw.githubusercontent.com/codebycruz/lpm/HEAD/install.ps1 | iex",
	},
] as const;

function CopyButton({ text }: { text: string }) {
	const [copied, setCopied] = useState(false);

	const handleCopy = () => {
		navigator.clipboard.writeText(text).then(() => {
			setCopied(true);
			setTimeout(() => setCopied(false), 2000);
		});
	};

	return (
		<button
			type="button"
			onClick={handleCopy}
			class="ml-auto px-2 py-1 rounded cursor-pointer opacity-50 hover:opacity-100 transition-opacity"
			title="Copy to clipboard"
		>
			{copied ? (
				<svg
					xmlns="http://www.w3.org/2000/svg"
					class="w-5 h-5 text-green-500"
					viewBox="0 0 24 24"
					fill="none"
					stroke="currentColor"
					stroke-width="2"
					stroke-linecap="round"
					stroke-linejoin="round"
				>
					<title>Copied</title>
					<polyline points="20 6 9 17 4 12" />
				</svg>
			) : (
				<svg
					xmlns="http://www.w3.org/2000/svg"
					class="w-5 h-5"
					viewBox="0 0 24 24"
					fill="none"
					stroke="currentColor"
					stroke-width="2"
					stroke-linecap="round"
					stroke-linejoin="round"
				>
					<title>Copy</title>
					<rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
					<path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
				</svg>
			)}
		</button>
	);
}

export default function InstallTabs() {
	const [active, setActive] = useState<string>(detectOS);

	return (
		<div class="flex flex-col gap-4">
			<h2 class="text-xl font-medium">Install latest version</h2>
			<div class="w-212">
				<div class="flex">
					{tabs.map((tab, i) => {
						const isFirst = i === 0;
						const isLast = i === tabs.length - 1;
						const isActive = active === tab.id;

						let rounding = "rounded-t-lg";
						if (isFirst)
							rounding =
								"rounded-tl-lg rounded-tr-lg rounded-bl-none";
						if (isLast)
							rounding =
								"rounded-tl-lg rounded-tr-lg rounded-br-none";

						return (
							<button
								key={tab.id}
								type="button"
								onClick={() => setActive(tab.id)}
								class={`px-4 py-2 cursor-pointer ${rounding} ${
									isActive
										? "bg-gray-100 dark:bg-gray-800"
										: "bg-gray-300 dark:bg-gray-700"
								}`}
							>
								{tab.label}
							</button>
						);
					})}
					<a
						href={GITHUB_RELEASES_URL}
						target="_blank"
						rel="noopener noreferrer"
						class="px-4 py-2 text-sm opacity-40 hover:opacity-100 transition-opacity cursor-pointer"
					>
						Or download manually
					</a>
				</div>
				{tabs.map((tab) => (
					<div
						key={tab.id}
						class={`flex items-center p-4 gap-2 bg-gray-100 dark:bg-gray-800 rounded-b-lg rounded-tr-lg ${active !== tab.id ? "hidden" : ""}`}
					>
						<code>{tab.command}</code>
						<CopyButton text={tab.command} />
					</div>
				))}
			</div>
		</div>
	);
}
