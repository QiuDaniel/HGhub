import React, { useEffect, useRef, useState } from "react";
import Hls from "hls.js";
import { asWkVideo, fmtTime, hasElementFullscreen, playSrc, preferNativeHls } from "../api";
import { ICompress, IExpand, IPauseF, IPlayF, IVol, IVolMute } from "../icons";

type Props = {
  src: string;              // 原始 m3u8 地址
  poster?: string;          // 已处理好的封面地址（本地协议）
  autoPlay?: boolean;
  muted?: boolean;
  loop?: boolean;
  onEnded?: () => void;
  onPlaying?: () => void;
  onTogglePlay?: (playing: boolean) => void;
  onToggleMute?: () => void;
  controls?: boolean;
  className?: string;
};

export default function Player({
  src, poster, autoPlay, muted = false, loop = false, onEnded, onPlaying,
  onTogglePlay, onToggleMute, controls = true, className = "",
}: Props) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  const hlsRef = useRef<Hls | null>(null);
  /** 本次 src 是否走原生 <video> 播放（见 preferNativeHls）：error 事件只在原生路径上报 */
  const nativeRef = useRef(false);
  const [playing, setPlaying] = useState(false);
  const [waiting, setWaiting] = useState(false);
  const [time, setTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [full, setFull] = useState(false);
  const [rate, setRate] = useState(1);
  const [errMsg, setErrMsg] = useState<string>("");

  useEffect(() => {
    const video = videoRef.current;
    if (!video || !src) return;
    const url = playSrc(src);

    if (hlsRef.current) { hlsRef.current.destroy(); hlsRef.current = null; }

    if (!preferNativeHls && Hls.isSupported()) {
      nativeRef.current = false;
      const hls = new Hls({
        enableWorker: true,
        lowLatencyMode: false,
        maxBufferLength: 24,
        backBufferLength: 30,
        manifestLoadingTimeOut: 20000,
        manifestLoadingMaxRetry: 3,
        fragLoadingMaxRetry: 4,
      });
      hlsRef.current = hls;
      hls.loadSource(url);
      hls.attachMedia(video);
      hls.on(Hls.Events.MANIFEST_PARSED, () => {
        if (autoPlay) video.play().catch(() => setPlaying(false));
      });
      hls.on(Hls.Events.ERROR, (_e, data) => {
        if (!data.fatal) return;
        const detail = `${data.type}/${data.details}/${data.response?.code ?? ""}/${String(data.reason ?? "").slice(0, 80)}`;
        (window as unknown as { __hlsErr?: string }).__hlsErr = detail;
        setErrMsg(detail);
        if (data.type === Hls.ErrorTypes.NETWORK_ERROR) hls.startLoad();
        else if (data.type === Hls.ErrorTypes.MEDIA_ERROR) hls.recoverMediaError();
        else { hls.destroy(); hlsRef.current = null; }
      });
    } else {
      // 原生 HLS：iOS（AVPlayer）/ Safari / 部分 WebView，直接播 Rust 改写后的 m3u8
      nativeRef.current = true;
      video.src = url;
      if (autoPlay) video.play().catch(() => setPlaying(false));
    }

    return () => {
      if (hlsRef.current) { hlsRef.current.destroy(); hlsRef.current = null; }
    };
  }, [src, autoPlay]);

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;
    video.muted = muted;
  }, [muted]);

  /* 全屏状态同步：标准 fullscreenchange（桌面 / iPad）+ webkitbegin/endfullscreen
     （iPhone 原生视频全屏，fullscreenchange 不会触发）。 */
  useEffect(() => {
    const onFs = () => setFull(!!document.fullscreenElement);
    const onWk = () => setFull(!!asWkVideo(videoRef.current)?.webkitDisplayingFullscreen);
    const video = asWkVideo(videoRef.current);
    document.addEventListener("fullscreenchange", onFs);
    video?.addEventListener("webkitbeginfullscreen", onWk);
    video?.addEventListener("webkitendfullscreen", onWk);
    return () => {
      document.removeEventListener("fullscreenchange", onFs);
      video?.removeEventListener("webkitbeginfullscreen", onWk);
      video?.removeEventListener("webkitendfullscreen", onWk);
    };
  }, []);

  const toggle = () => {
    const video = videoRef.current;
    if (!video) return;
    if (video.paused) video.play().catch(() => {});
    else video.pause();
  };

  const onSeek = (e: React.ChangeEvent<HTMLInputElement>) => {
    const video = videoRef.current;
    if (!video || !duration) return;
    const pct = Number(e.target.value) / 1000;
    video.currentTime = pct * duration;
    setTime(video.currentTime);
  };

  const cycleRate = () => {
    const video = videoRef.current;
    if (!video) return;
    const next = rate === 1 ? 1.25 : rate === 1.25 ? 1.5 : rate === 1.5 ? 2 : 1;
    video.playbackRate = next;
    setRate(next);
  };

  const toggleFull = () => {
    const video = asWkVideo(videoRef.current);
    if (document.fullscreenElement) { document.exitFullscreen().catch(() => {}); return; }
    if (video?.webkitDisplayingFullscreen) { video.webkitExitFullscreen?.(); return; }
    const el = wrapRef.current;
    /* 桌面 / iPad：容器元素全屏。iPhone 的 WKWebView 没有该 API
       （hasElementFullscreen 为 false），退回 <video> 原生播放器全屏。 */
    if (hasElementFullscreen && el) { el.requestFullscreen().catch(() => {}); return; }
    video?.webkitEnterFullscreen?.();
  };

  const pct = duration > 0 ? (time / duration) * 100 : 0;

  return (
    <div ref={wrapRef} className={`relative bg-black overflow-hidden group ${className}`}>
      <video
        ref={videoRef}
        poster={poster}
        playsInline
        loop={loop}
        className="w-full h-full object-contain bg-black"
        onClick={toggle}
        onPlay={() => { setPlaying(true); onTogglePlay?.(true); }}
        onPause={() => { setPlaying(false); onTogglePlay?.(false); }}
        onWaiting={() => setWaiting(true)}
        onPlaying={() => { setWaiting(false); onPlaying?.(); }}
        onTimeUpdate={(e) => setTime((e.target as HTMLVideoElement).currentTime)}
        onLoadedMetadata={(e) => setDuration((e.target as HTMLVideoElement).duration || 0)}
        onEnded={() => onEnded?.()}
        onError={() => {
          if (!nativeRef.current) return;
          const code = videoRef.current?.error?.code;
          setErrMsg(`video/${code ?? "?"}`);
        }}
      />

      {errMsg && (
        <div className="absolute left-2 top-2 z-30 max-w-[80%] rounded bg-black/70 px-2 py-1 text-[10px] leading-tight text-red-300 break-all">
          {errMsg}
        </div>
      )}

      {waiting && (
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
          <div className="w-9 h-9 spinner" />
        </div>
      )}

      {!playing && !waiting && (
        <button onClick={toggle} aria-label="播放"
          className="absolute inset-0 flex items-center justify-center">
          <span className="w-16 h-16 rounded-full bg-black/45 backdrop-blur-sm flex items-center justify-center elev-2 pressable">
            <IPlayF size={26} className="text-white ml-0.5" />
          </span>
        </button>
      )}

      {controls && (
        <div className="absolute inset-x-0 bottom-0 px-3 pb-2 pt-8 bg-gradient-to-t from-black/80 to-transparent opacity-0 group-hover:opacity-100 transition-opacity">
          <input type="range" min={0} max={1000} value={Math.round(pct * 10)} onChange={onSeek}
            className="hg-range w-full" style={{ "--fill": `${pct}%` } as React.CSSProperties} />
          <div className="flex items-center gap-3 mt-1 text-white">
            <button onClick={toggle} aria-label={playing ? "暂停" : "播放"} className="pressable">
              {playing ? <IPauseF size={16} /> : <IPlayF size={16} />}
            </button>
            <button onClick={() => onToggleMute?.()} aria-label="静音" className="pressable">
              {muted ? <IVolMute size={16} /> : <IVol size={16} />}
            </button>
            <span className="text-[11px] tabular-nums text-white/85">{fmtTime(time)} / {fmtTime(duration)}</span>
            <div className="flex-1" />
            <button onClick={cycleRate} className="text-[11px] font-bold text-white/85 pressable tabular-nums">{rate}x</button>
            <button onClick={toggleFull} aria-label="全屏" className="pressable">
              {full ? <ICompress size={16} /> : <IExpand size={16} />}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}