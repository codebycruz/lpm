import { useEffect, useRef } from "preact/hooks";
import { render } from "preact";
import { CopyButton } from "./CopyButton";

export default function CodeBlocks() {
	useEffect(() => {
		document.querySelectorAll<HTMLElement>(".markdown pre").forEach((pre) => {
			const code = pre.querySelector("code");
			const getText = () => (code ? code.innerText : pre.innerText);

			const container = document.createElement("div");
			container.className = "absolute top-2 right-2";
			pre.style.position = "relative";
			pre.appendChild(container);

			render(<CopyButton getText={getText} />, container);
		});
	}, []);

	return null;
}
