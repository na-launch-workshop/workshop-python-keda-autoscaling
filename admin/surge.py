"""Flood /api/score with concurrent requests to trigger 503s.

Usage: python3.11 surge.py [url] [concurrency] [duration_seconds]

Set SURGE_INSECURE=1 to skip TLS verification (e.g. self-signed cluster certs).
"""

import os
import ssl
import sys
import time
import threading
import urllib.request
import urllib.error

_CTX = ssl._create_unverified_context() if os.getenv("SURGE_INSECURE") else None


def hit(url: str) -> int:
    try:
        with urllib.request.urlopen(url, timeout=3, context=_CTX) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:
        return 0


def main() -> None:
    url         = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8080/api/score"
    concurrency = int(sys.argv[2]) if len(sys.argv) > 2 else 20
    duration    = int(sys.argv[3]) if len(sys.argv) > 3 else 60

    print(f"Surging {url} — {concurrency} concurrent workers for {duration}s")
    print("Press Ctrl+C to stop early.\n")

    stop = threading.Event()
    counts = {"total": 0, "ok": 0}
    lock = threading.Lock()

    def worker():
        while not stop.is_set():
            status = hit(url)
            with lock:
                counts["total"] += 1
                if status == 200:
                    counts["ok"] += 1

    threads = [threading.Thread(target=worker, daemon=True) for _ in range(concurrency)]
    for t in threads:
        t.start()

    start = time.time()
    try:
        while time.time() - start < duration:
            time.sleep(2)
            with lock:
                total = counts["total"]
                ok    = counts["ok"]
                errs  = total - ok
            print(f"  {int(time.time()-start):3d}s  total={total:4d}  ok={ok:4d}  errors={errs:4d}")
    except KeyboardInterrupt:
        pass

    stop.set()
    print("\nSurge complete.")


if __name__ == "__main__":
    main()
