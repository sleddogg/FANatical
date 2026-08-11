import { useEffect, useRef, useState } from "react";

function recordingDataUrl(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.addEventListener("load", () => typeof reader.result === "string" ? resolve(reader.result) : reject(new Error("Recording could not be encoded.")));
    reader.addEventListener("error", () => reject(reader.error));
    reader.readAsDataURL(blob);
  });
}

export function CheerRecording({ recordingUrl, onChange }: { readonly recordingUrl: string | null; readonly onChange: (url: string | null) => void }) {
  const recorderRef = useRef<MediaRecorder | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const [status, setStatus] = useState<"idle" | "requesting" | "recording" | "unavailable">("idle");
  const [message, setMessage] = useState("");
  const supported = typeof MediaRecorder !== "undefined" && Boolean(navigator.mediaDevices?.getUserMedia);

  useEffect(() => () => {
    if (recorderRef.current?.state === "recording") recorderRef.current.stop();
    streamRef.current?.getTracks().forEach((track) => track.stop());
  }, []);

  const start = async () => {
    if (!supported) {
      setStatus("unavailable");
      return;
    }
    try {
      setStatus("requesting");
      setMessage("");
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const recorder = new MediaRecorder(stream);
      chunksRef.current = [];
      streamRef.current = stream;
      recorderRef.current = recorder;
      recorder.addEventListener("dataavailable", (event) => event.data.size && chunksRef.current.push(event.data));
      recorder.addEventListener("stop", async () => {
        const blob = new Blob(chunksRef.current, { type: recorder.mimeType || "audio/webm" });
        try {
          onChange(await recordingDataUrl(blob));
          setMessage("Reference recording saved with this Cheer.");
        } catch {
          setMessage("The reference recording could not be saved. Try recording it again.");
        }
        stream.getTracks().forEach((track) => track.stop());
        streamRef.current = null;
        setStatus("idle");
      });
      recorder.start();
      setStatus("recording");
    } catch {
      setStatus("unavailable");
      setMessage("Microphone permission was unavailable. You can still build and save this Cheer without a recording.");
    }
  };

  const stop = () => recorderRef.current?.state === "recording" && recorderRef.current.stop();
  const remove = () => {
    onChange(null);
    setMessage("Reference recording removed.");
  };

  return (
    <section className="cheer-recording" aria-labelledby="cheer-recording-title">
      <div><span className="eyebrow">Optional reference</span><h3 id="cheer-recording-title">Record the idea</h3><p>This recording stays local and is for learning or practice—not synchronized live playback.</p></div>
      {!supported || status === "unavailable" ? <p className="cheer-recording__notice">{message || "Browser audio recording is unavailable here. Continue with lyrics and choreography."}</p> : null}
      <div className="cheer-recording__controls">
        {status === "recording" ? <button type="button" onClick={stop}><span className="cheer-recording__live" /> Stop</button> : <button type="button" disabled={status === "requesting" || !supported} onClick={() => void start()}>{recordingUrl ? "Replace recording" : status === "requesting" ? "Requesting microphone…" : "Start recording"}</button>}
        {recordingUrl ? <button type="button" onClick={remove}>Delete recording</button> : null}
      </div>
      {recordingUrl ? <audio controls src={recordingUrl}>Your browser does not support audio playback.</audio> : null}
      {message && status !== "unavailable" ? <p role="status">{message}</p> : null}
    </section>
  );
}
