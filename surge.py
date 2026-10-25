"""Flood /api/score with concurrent requests to trigger 502s.

Usage: python3.11 surge.py [url] [concurrency] [duration_seconds]
"""

import sys
import time
import threading
import urllib.request
import urllib.error

def hit(url: str, results: list) -> None:
    try:
        with urllib.request.urlopen(url, timeout=3) as r:
            results.append(r.status)
    except urllib.error.HTTPError as e:
        results.append(e.code)
    except Exception:
        results.append(0)


def main() -> None:
    url         = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8080/api/score"
    concurrency = int(sys.argv[2]) if len(sys.argv) > 2 else 20
    duration    = int(sys.argv[3]) if len(sys.argv) > 3 else 60

    print(f"Surging {url} — {concurrency} concurrent workers for {duration}s")
    print("Press Ctrl+C to stop early.\n")

    stop = threading.Event()
    results: list[int] = []
    lock = threading.Lock()

    def worker():
        while not stop.is_set():
            r: list[int] = []
            hit(url, r)
            with lock:
                results.extend(r)

    threads = [threading.Thread(target=worker, daemon=True) for _ in range(concurrency)]
    for t in threads:
        t.start()

    start = time.time()
    try:
        while time.time() - start < duration:
            time.sleep(2)
            with lock:
                total = len(results)
                ok    = results.count(200)
                errs  = total - ok
            print(f"  {int(time.time()-start):3d}s  total={total:4d}  ok={ok:4d}  errors={errs:4d}")
    except KeyboardInterrupt:
        pass

    stop.set()
    print("\nSurge complete.")


if __name__ == "__main__":
    main()
