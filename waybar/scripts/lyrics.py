#!/usr/bin/env python3
# lyrics.py — synced Spotify lyrics island (lyrics from lrclib.net).
# No args: print waybar JSON, a few lines around the current one with that
# line bold. Empty text while toggled off, so waybar hides the module.
# `lyrics.py toggle` flips the island and pokes waybar via its signal.
import hashlib, html, json, os, re, subprocess, sys, urllib.parse, urllib.request

RUN = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
FLAG = f"{RUN}/waybar-lyrics-on"
CACHE = f"{RUN}/waybar-lyrics"
SIGNAL = 8  # keep in sync with "signal" in modules-right.jsonc


def parse_lrc(lrc):
    """'[mm:ss.xx] line' -> [(seconds, line)], sorted."""
    out = []
    for raw in lrc.splitlines():
        stamps = re.findall(r"\[(\d+):(\d+(?:\.\d+)?)\]", raw)
        text = re.sub(r"\[[^\]]*\]", "", raw).strip()
        out += [(int(m) * 60 + float(s), text) for m, s in stamps]
    return sorted(out)


def current(lines, pos):
    """Index of the last line whose timestamp has passed, or -1."""
    return sum(1 for t, _ in lines if t <= pos) - 1


def fetch(artist, title):
    path = f"{CACHE}/{hashlib.md5(f'{artist}|{title}'.encode()).hexdigest()}.json"
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        pass
    q = urllib.parse.urlencode({"artist_name": artist, "track_name": title})
    req = urllib.request.Request(f"https://lrclib.net/api/search?{q}",
                                 headers={"User-Agent": "waybar-lyrics"})
    try:
        with urllib.request.urlopen(req, timeout=5) as r:
            hits = json.load(r)
    except OSError:
        return {}  # offline: don't cache, retry next tick
    hit = next((h for h in hits if h.get("syncedLyrics")), hits[0] if hits else {})
    res = {"synced": hit.get("syncedLyrics"), "plain": hit.get("plainLyrics")}
    os.makedirs(CACHE, exist_ok=True)
    with open(path, "w") as f:
        json.dump(res, f)
    return res


def main():
    if sys.argv[1:] == ["toggle"]:
        os.remove(FLAG) if os.path.exists(FLAG) else open(FLAG, "w").close()
        subprocess.run(["pkill", f"-RTMIN+{SIGNAL}", "-x", "waybar"])
        return
    if sys.argv[1:] == ["test"]:
        ls = parse_lrc("[00:01.00]a\n[00:03.50][01:00.00]b\n[ar:x]")
        assert ls == [(1.0, "a"), (3.5, "b"), (60.0, "b")], ls
        assert [current(ls, p) for p in (0, 1, 4, 99)] == [-1, 0, 1, 2]
        return print("ok")
    if not os.path.exists(FLAG):
        return print(json.dumps({"text": ""}))
    meta = subprocess.run(
        ["playerctl", "-p", "spotify", "metadata", "--format",
         "{{xesam:artist}}\t{{xesam:title}}\t{{position}}"],
        capture_output=True, text=True).stdout.strip().split("\t")
    if len(meta) != 3:  # spotify not running
        return print(json.dumps({"text": ""}))
    artist, title, pos = meta
    lyr = fetch(artist, title)
    esc = html.escape
    if lyr.get("synced"):
        lines = parse_lrc(lyr["synced"])
        i = current(lines, int(pos) / 1e6)
        # ponytail: fixed 7-line window; widen if you want more context
        lo = max(i - 2, 0)
        text = "\n".join(f"<b>{esc(t or '♪')}</b>" if j == i
                         else f"<span alpha='50%'>{esc(t or '♪')}</span>"
                         for j, (_, t) in enumerate(lines[lo:lo + 7], lo))
    else:
        text = "󰎈 unsynced lyrics" if lyr.get("plain") else "󰎈 no lyrics"
    print(json.dumps({"text": text,
                      "class": "synced" if lyr.get("synced") else "missing"}))


if __name__ == "__main__":
    main()
