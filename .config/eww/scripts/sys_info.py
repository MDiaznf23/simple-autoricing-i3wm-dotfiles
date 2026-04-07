#!/usr/bin/env python3
"""
sys_info.py — System info tanpa blocking sleep
Simpan /proc/stat sebelumnya di file cache, diff saat dipanggil berikutnya.
"""

import json
import os
import re
import sys
from pathlib import Path

CACHE_FILE = Path("/tmp/eww_cpu_stat_cache")

# ─── CPU Usage ────────────────────────────────────────────────────────────────


def read_proc_stat() -> tuple[int, int]:
    """Return (total, idle) dari /proc/stat baris cpu."""
    line = Path("/proc/stat").read_text().splitlines()[0]
    fields = line.split()[1:]  # skip label "cpu"
    vals = [int(f) for f in fields]
    total = sum(vals)
    idle = vals[3]  # index 3 = idle
    return total, idle


def get_cpu_usage() -> int:
    total2, idle2 = read_proc_stat()

    if CACHE_FILE.exists():
        try:
            total1, idle1 = map(int, CACHE_FILE.read_text().split())
            diff_total = total2 - total1
            diff_idle = idle2 - idle1
            usage = (
                int(100 * (diff_total - diff_idle) / diff_total)
                if diff_total > 0
                else 0
            )
        except (ValueError, ZeroDivisionError):
            usage = 0
    else:
        usage = 0

    # Simpan state sekarang untuk pemanggilan berikutnya
    CACHE_FILE.write_text(f"{total2} {idle2}")
    return usage


# ─── CPU Temp ─────────────────────────────────────────────────────────────────


def get_cpu_temp() -> int:
    # Metode 1: hwmon label
    for input_file in Path("/sys/class/hwmon").glob("hwmon*/temp*_input"):
        label_file = Path(str(input_file).replace("_input", "_label"))
        if not label_file.exists():
            continue
        label = label_file.read_text().strip()
        if re.match(r"^(Package id|Core 0|Tctl|Tccd)", label):
            try:
                val = int(input_file.read_text())
                if val > 0:
                    return val // 1000
            except (ValueError, OSError):
                continue

    # Metode 2: thermal_zone
    for zone in Path("/sys/class/thermal").glob("thermal_zone*"):
        try:
            zone_type = (zone / "type").read_text().strip()
            if zone_type in ("x86_pkg_temp", "cpu-thermal", "cpu_thermal"):
                val = int((zone / "temp").read_text())
                if val > 0:
                    return val // 1000 if val > 1000 else val
        except (ValueError, OSError):
            continue

    return 0


# ─── RAM ──────────────────────────────────────────────────────────────────────


def get_mem() -> dict:
    info = {}
    for line in Path("/proc/meminfo").read_text().splitlines():
        key, *rest = line.split()
        info[key.rstrip(":")] = int(rest[0])

    total_kb = info.get("MemTotal", 0)
    available_kb = info.get("MemAvailable", 0)
    used_kb = total_kb - available_kb

    def fmt(kb: int) -> str:
        if kb >= 1048576:
            return f"{kb/1048576:.1f}G"
        return f"{kb/1024:.0f}M"

    perc = int(100 * used_kb / total_kb) if total_kb > 0 else 0
    return {
        "mem_perc": perc,
        "mem_used": fmt(used_kb),
        "mem_total": fmt(total_kb),
    }


# ─── Disk ─────────────────────────────────────────────────────────────────────


def get_disk() -> dict:
    st = os.statvfs("/")
    total = st.f_blocks * st.f_frsize
    free = st.f_bfree * st.f_frsize
    used = total - free
    perc = int(100 * used / total) if total > 0 else 0

    def fmt(b: int) -> str:
        if b >= 1_073_741_824:
            return f"{b/1_073_741_824:.1f}G"
        return f"{b/1_048_576:.0f}M"

    return {
        "disk_perc": perc,
        "disk_used": fmt(used),
        "disk_total": fmt(total),
    }


# ─── Main ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    result = {
        "cpu_usage": get_cpu_usage(),
        "cpu_temp": get_cpu_temp(),
        **get_mem(),
        **get_disk(),
    }
    print(json.dumps(result, ensure_ascii=False))
