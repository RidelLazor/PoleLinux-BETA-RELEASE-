#!/usr/bin/env python3
"""Serves a build progress dashboard on localhost:9090"""
import http.server
import json
import os
import subprocess
import time
from datetime import datetime, timedelta

HOST = "0.0.0.0"
PORT = 9090
BUILD_DIR = "/home/danish/Projects/my-distro"
LOG_FILE = f"{BUILD_DIR}/build-output.log"
CONTAINER_FILTER = "ancestor=polelinux-arch-builder"

start_time = time.time()
last_bytes = 0
last_time = time.time()
speed_history = []

def get_progress():
    global last_bytes, last_time, speed_history

    now = time.time()
    elapsed = now - start_time

    # Check container status
    result = subprocess.run(
        ["docker", "ps", "--format", "{{.Status}}", "--filter", CONTAINER_FILTER],
        capture_output=True, text=True, timeout=5
    )
    container_status = result.stdout.strip()

    # Get network IO
    result = subprocess.run(
        ["docker", "stats", "--no-stream", "--format", "{{.NetIO}}", "--filter", CONTAINER_FILTER],
        capture_output=True, text=True, timeout=5
    )
    net_io = result.stdout.strip()

    # Parse net IO to get bytes downloaded
    downloaded_mb = 0
    if net_io:
        parts = net_io.split("/")
        if parts:
            val = parts[0].strip()
            if "GB" in val:
                downloaded_mb = float(val.replace("GB", "").strip()) * 1024
            elif "MB" in val:
                downloaded_mb = float(val.replace("MB", "").strip())
            elif "kB" in val:
                downloaded_mb = float(val.replace("kB", "").strip()) / 1024

    # Speed calculation
    speed = 0
    if downloaded_mb > last_bytes:
        speed = (downloaded_mb - last_bytes) / max(now - last_time, 1)
        speed_history.append(speed)
        if len(speed_history) > 10:
            speed_history.pop(0)
        last_bytes = downloaded_mb
        last_time = now

    avg_speed = sum(speed_history) / max(len(speed_history), 1) if speed_history else 0

    # Total download size
    total_mb = 1331.68

    # Build-env size
    result = subprocess.run(
        ["du", "-sh", f"{BUILD_DIR}/build-env/"],
        capture_output=True, text=True, timeout=5
    )
    build_env_size = result.stdout.split()[0] if result.stdout else "0"

    # Check for ISO
    result = subprocess.run(
        ["ls", f"{BUILD_DIR}/build-env/out/"],
        capture_output=True, text=True, timeout=5
    )
    iso_files = [f for f in result.stdout.split() if f.endswith(".iso")] if result.stdout else []
    iso_size = ""
    if iso_files:
        result = subprocess.run(
            ["du", "-h", f"{BUILD_DIR}/build-env/out/{iso_files[0]}"],
            capture_output=True, text=True, timeout=5
        )
        iso_size = result.stdout.split()[0] if result.stdout else ""

    # Last log lines
    log_tail = ""
    try:
        with open(LOG_FILE) as f:
            lines = f.readlines()
            log_tail = "".join(lines[-15:])
    except FileNotFoundError:
        log_tail = "Build log not found yet..."

    # Determine stage
    stage = "Starting..."
    pct = 0
    if iso_files:
        stage = "ISO ready!"
        pct = 100
    elif "Setting up SYSLINUX" in log_tail:
        stage = "Setting up SYSLINUX BIOS boot"
        pct = 75
    elif "Setting up systemd-boot" in log_tail:
        stage = "Setting up systemd-boot UEFI"
        pct = 80
    elif "customize_airootfs.sh" in log_tail:
        stage = "Customizing system (branding, user, initramfs)"
        pct = 65
    elif "version files" in log_tail or "list of installed" in log_tail:
        stage = "Finalizing package installation"
        pct = 60
    elif "Installing packages" in log_tail or "mkinitcpio" in log_tail or "installing" in log_tail.lower():
        stage = "Installing packages"
        pct = 40
        if build_env_size.endswith("G"):
            val = float(build_env_size[:-1])
            pct = min(55, 30 + val / 4.07 * 25)
    elif "Retrieving packages" in log_tail or "downloading" in log_tail.lower() or "Synchronizing" in log_tail:
        stage = "Downloading packages"
        pct = min(35, downloaded_mb / total_mb * 35)
    elif "Creating archiso profile" in log_tail or "Copying" in log_tail:
        stage = "Setting up build profile"
        pct = 5

    # Prediction
    eta = ""
    if avg_speed > 0 and pct < 100 and pct > 5:
        remaining_mb = total_mb - downloaded_mb
        remaining_secs = remaining_mb / avg_speed
        if remaining_secs > 0:
            eta_dt = datetime.now() + timedelta(seconds=remaining_secs)
            eta = eta_dt.strftime("%H:%M")
        elif "SYSLINUX" in log_tail or "systemd-boot" in log_tail:
            eta = "~2 min"

    if pct >= 100:
        eta = "Done!"

    container_running = bool(container_status)

    return {
        "stage": stage,
        "pct": round(pct),
        "eta": eta,
        "elapsed": str(timedelta(seconds=int(elapsed))),
        "downloaded": f"{downloaded_mb:.0f} MB",
        "total": f"{total_mb:.0f} MB",
        "speed": f"{avg_speed:.1f} MB/s" if avg_speed > 0 else "N/A",
        "build_env": build_env_size,
        "container": container_status or "exited/finished",
        "iso": iso_files[0] if iso_files else "",
        "iso_size": iso_size,
        "running": container_running,
        "log": log_tail.strip()
    }


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/api/progress":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps(get_progress()).encode())
            return

        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        html = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PoleLinux Build Progress</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #0d0d1a; color: #e0e0f0;
    display: flex; justify-content: center; align-items: center;
    min-height: 100vh;
  }
  .container { max-width: 800px; width: 100%; padding: 2rem; }
  h1 { font-size: 1.8rem; margin-bottom: 0.5rem; color: #64B4FF; }
  .subtitle { color: #9090b0; margin-bottom: 2rem; font-size: 0.9rem; }
  .stats { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 2rem; }
  .stat-card {
    background: #1a1a2e; border-radius: 12px; padding: 1.2rem;
    border: 1px solid #2a2a44;
  }
  .stat-card .label { font-size: 0.75rem; text-transform: uppercase; color: #7070a0; letter-spacing: 1px; }
  .stat-card .value { font-size: 1.4rem; font-weight: 700; margin-top: 0.3rem; color: #fff; }
  .stat-card .value.green { color: #4ade80; }
  .stat-card .value.blue { color: #64B4FF; }
  .stat-card .value.yellow { color: #fbbf24; }
  .stat-card.full { grid-column: 1 / -1; }
  .progress-bar { height: 8px; background: #2a2a44; border-radius: 4px; margin: 1rem 0; overflow: hidden; }
  .progress-fill { height: 100%; background: linear-gradient(90deg, #64B4FF, #4ade80); border-radius: 4px; transition: width 0.5s; }
  .stage { font-size: 1.1rem; margin-bottom: 0.5rem; }
  pre {
    background: #12121e; padding: 1rem; border-radius: 8px;
    font-size: 0.75rem; line-height: 1.4; overflow-x: auto;
    max-height: 300px; overflow-y: auto; color: #b0b0d0;
    border: 1px solid #2a2a44;
  }
  .status-dot {
    display: inline-block; width: 10px; height: 10px; border-radius: 50%;
    margin-right: 6px;
  }
  .status-dot.running { background: #4ade80; animation: pulse 1.5s infinite; }
  .status-dot.stopped { background: #f87171; }
  .status-dot.done { background: #64B4FF; }
  @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.4; } }
  @media (max-width: 600px) { .stats { grid-template-columns: 1fr; } }
</style>
</head>
<body>
<div class="container">
  <h1>PoleLinux Build</h1>
  <p class="subtitle">Live progress dashboard — <span id="refresh">auto-refreshing</span></p>

  <div class="stats" id="stats">
    <div class="stat-card">
      <div class="label">Stage</div>
      <div class="value blue" id="stage">Starting...</div>
    </div>
    <div class="stat-card">
      <div class="label">Progress</div>
      <div class="value green" id="pct">0%</div>
    </div>
    <div class="stat-card">
      <div class="label">Elapsed</div>
      <div class="value" id="elapsed" style="color:#e0e0f0">0:00:00</div>
    </div>
    <div class="stat-card">
      <div class="label">ETA</div>
      <div class="value yellow" id="eta">--:--</div>
    </div>
    <div class="stat-card">
      <div class="label">Downloaded</div>
      <div class="value" id="downloaded" style="color:#e0e0f0">0 MB</div>
    </div>
    <div class="stat-card">
      <div class="label">Speed</div>
      <div class="value" id="speed" style="color:#e0e0f0">N/A</div>
    </div>
    <div class="stat-card">
      <div class="label">Build Dir</div>
      <div class="value" id="build_env" style="color:#e0e0f0">0</div>
    </div>
    <div class="stat-card">
      <div class="label">Container</div>
      <div class="value" id="container" style="font-size:0.9rem;color:#9090b0">waiting...</div>
    </div>
    <div class="stat-card full">
      <div class="label">Build Log</div>
      <pre id="log">Waiting for log output...</pre>
    </div>
  </div>

  <div class="progress-bar"><div class="progress-fill" id="bar" style="width:0%"></div></div>
  <div id="iso-info" style="display:none;margin-top:1rem;padding:1rem;background:#1a2e1a;border-radius:8px;border:1px solid #4ade80;">
    <strong style="color:#4ade80">ISO Ready!</strong>
    <span id="iso-name"></span> (<span id="iso-size"></span>)
  </div>
</div>

<script>
function fmt(t) {
  if (t < 10) return '0' + t;
  return '' + t;
}
function secsToHms(s) {
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = Math.floor(s % 60);
  if (h > 0) return h + ':' + fmt(m) + ':' + fmt(sec);
  return m + ':' + fmt(sec);
}
async function fetchProgress() {
  try {
    const r = await fetch('/api/progress');
    const d = await r.json();
    document.getElementById('stage').textContent = d.stage;
    document.getElementById('pct').textContent = d.pct + '%';
    document.getElementById('bar').style.width = d.pct + '%';
    document.getElementById('elapsed').textContent = d.elapsed;
    document.getElementById('eta').textContent = d.eta || '--:--';
    document.getElementById('downloaded').textContent = d.downloaded + ' / ' + d.total;
    document.getElementById('speed').textContent = d.speed;
    document.getElementById('build_env').textContent = d.build_env;
    document.getElementById('container').textContent = d.container || 'exited';

    if (d.log) {
      document.getElementById('log').textContent = d.log;
      const pre = document.getElementById('log');
      pre.scrollTop = pre.scrollHeight;
    }

    if (d.iso) {
      document.getElementById('iso-info').style.display = 'block';
      document.getElementById('iso-name').textContent = d.iso;
      document.getElementById('iso-size').textContent = d.iso_size;
    }

    if (d.pct >= 100 && !d.running) {
      document.getElementById('refresh').textContent = 'build complete';
    }
  } catch(e) {
    document.getElementById('log').textContent = 'Error fetching progress: ' + e;
  }
}
fetchProgress();
setInterval(fetchProgress, 3000);
</script>
</body>
</html>"""
        self.wfile.write(html.encode())


if __name__ == "__main__":
    server = http.server.HTTPServer((HOST, PORT), Handler)
    print(f"Progress dashboard at http://localhost:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()
