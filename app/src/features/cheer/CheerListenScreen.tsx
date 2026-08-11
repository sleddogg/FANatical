import { useEffect, useRef, useState } from "react";
import { CHEER_PLAYBACK_BPM } from "./cheerUtils";
import { CheerRecording } from "./CheerRecording";
import type { CheerRecord } from "./types";

export function CheerListenScreen({ cheer, onRecordingChange }: { readonly cheer: CheerRecord; readonly onRecordingChange: (recordingUrl: string | null) => void }) {
  const audioRef = useRef<HTMLAudioElement>(null);
  const [playing, setPlaying] = useState(false);
  const [recordingOpen, setRecordingOpen] = useState(false);

  useEffect(() => {
    setPlaying(false);
    setRecordingOpen(false);
    if (audioRef.current) audioRef.current.currentTime = 0;
  }, [cheer.id, cheer.recordingUrl]);

  const play = () => {
    if (!audioRef.current || !cheer.recordingUrl) return;
    void audioRef.current.play().then(() => setPlaying(true)).catch(() => setPlaying(false));
  };

  const pause = () => {
    audioRef.current?.pause();
    setPlaying(false);
  };

  const restart = () => {
    if (!audioRef.current || !cheer.recordingUrl) return;
    audioRef.current.currentTime = 0;
    void audioRef.current.play().then(() => setPlaying(true)).catch(() => setPlaying(false));
  };

  return (
    <main className="cheer-listener" aria-labelledby="cheer-listener-title">
      <header><span className="eyebrow">Creator reference recording</span><h2 id="cheer-listener-title">{cheer.title}</h2><p>{cheer.team || "League-wide"} · {cheer.sport} · {CHEER_PLAYBACK_BPM} BPM</p></header>
      <section>
        <div className="cheer-listener__disc" data-playing={playing ? "true" : undefined} aria-hidden="true"><span>♪</span></div>
        {cheer.recordingUrl ? <><audio ref={audioRef} src={cheer.recordingUrl} preload="metadata" onPlay={() => setPlaying(true)} onPause={() => setPlaying(false)} onEnded={() => setPlaying(false)}>Your browser does not support audio playback.</audio><p>Reference recording attached by the Cheer creator.</p><div className="cheer-playback-controls" aria-label="Listen playback controls"><button type="button" disabled={playing} onClick={play}>Play</button><button type="button" disabled={!playing} onClick={pause}>Pause</button><button type="button" onClick={restart}>Restart</button><button type="button" aria-expanded={recordingOpen} onClick={() => setRecordingOpen((current) => !current)}>Replace Recording</button></div></> : <><p>No reference recording is attached to this Cheer yet.</p><button className="cheer-primary-button" type="button" aria-expanded={recordingOpen} onClick={() => setRecordingOpen((current) => !current)}>Record Reference</button></>}
        {recordingOpen ? <CheerRecording recordingUrl={cheer.recordingUrl} onChange={onRecordingChange} /> : null}
      </section>
    </main>
  );
}
