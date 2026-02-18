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

const maxCommand = tabs.reduce(
	(max, t) => (t.command.length > max.length ? t.command : max),
	"",
);

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
			class="ml-auto shrink-0 p-1.5 rounded-md cursor-pointer opacity-40 hover:opacity-100 transition-opacity"
			title="Copy to clipboard"
		>
			{copied ? (
				<svg
					xmlns="http://www.w3.org/2000/svg"
					class="w-4 h-4 text-green-400"
					viewBox="0 0 24 24"
					fill="none"
					stroke="currentColor"
					stroke-width="2.5"
					stroke-linecap="round"
					stroke-linejoin="round"
				>
					<title>Copied</title>
					<polyline points="20 6 9 17 4 12" />
				</svg>
			) : (
				<svg
					xmlns="http://www.w3.org/2000/svg"
					class="w-4 h-4"
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

	const activeTab = tabs.find((t) => t.id === active) ?? tabs[0];

	return (
		<div class="flex flex-col gap-4">
			<h2 class="text-xl font-medium">Install latest version</h2>
			<div>
				<div class="flex">
					{tabs.map((tab, i) => {
						const isFirst = i === 0;
						const isActive = active === tab.id;

						return (
							<button
								key={tab.id}
								type="button"
								onClick={() => setActive(tab.id)}
								class={`px-4 py-2 cursor-pointer transition-colors ${
									isFirst ? "rounded-tl-lg" : ""
								} ${
									i === tabs.length - 1 ? "rounded-tr-lg" : ""
								} ${
									isActive
										? "bg-gray-900 text-gray-200 dark:bg-gray-800 dark:text-gray-200"
										: "bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600"
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
						class="px-4 py-2 text-sm opacity-40 hover:opacity-100 transition-opacity cursor-pointer flex items-center"
					>
						Or download manually
					</a>
				</div>
				<div class="flex items-center px-4 py-3 bg-gray-900 dark:bg-gray-800 rounded-b-lg rounded-tr-lg">
					<span class="text-blue-400 mr-3 select-none font-mono text-sm">
						$
					</span>
					<div class="relative flex items-center">
						<code class="text-sm text-gray-200 font-mono whitespace-nowrap invisible">
							{maxCommand}
						</code>
						<code class="text-sm text-gray-200 font-mono whitespace-nowrap absolute inset-0 flex items-center">
							{activeTab.command}
						</code>
					</div>
					<div class="ml-6">
						<CopyButton text={activeTab.command} />
					</div>
				</div>
			</div>
		</div>
	);
}
