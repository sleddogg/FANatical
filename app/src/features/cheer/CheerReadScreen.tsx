import { lyricLines } from "./cheerUtils";
import type { CheerRecord } from "./types";

export function CheerReadScreen({ cheer }: { readonly cheer: CheerRecord }) {
  const lines = lyricLines(cheer.lyrics);
  return (
    <main className="cheer-reader" aria-labelledby="cheer-reader-title">
      <header><span className="eyebrow">{cheer.team || "League-wide"} · {cheer.sport}{cheer.league ? ` · ${cheer.league}` : ""}</span><h2 id="cheer-reader-title">{cheer.title}</h2><p>Full Cheer lyrics</p></header>
      <article dir="auto">{lines.map((line, index) => <p key={`${line}-${index}`}>{line}</p>)}</article>
    </main>
  );
}
