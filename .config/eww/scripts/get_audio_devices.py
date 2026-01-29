#!/usr/bin/env python3

import subprocess
import json
import sys
import select

# Mode: sink atau source
MODE = sys.argv[1] if len(sys.argv) > 1 else "sink"


def get_data():
    # --- LOGIC LAMA (Copy-Paste bagian ini) ---
    try:
        cmd = f"pactl -f json list {MODE}s"
        result = subprocess.run(cmd.split(), capture_output=True, text=True)
        # ... (Kode parsing JSON sama persis dengan script sebelumnya)
        # Biar ringkas di chat, asumsikan fungsi get_devices() ada di sini
        # dan mengembalikan list dictionary
        return get_devices_logic(result.stdout)
    except:
        return []
    # ------------------------------------------


def get_devices_logic(json_str):
    # Re-use logic parsing dari script sebelumnya di sini
    # Agar script ini standalone, pastikan function parsing tadi dimasukkan
    data = json.loads(json_str)
    # ... logic parsing volume & active port ...
    # (Saya simplify disini biar gak kepanjangan, pakai logic script pertama)

    # --- CONTOH SIMPLIFIED RETURNS ---
    # Implementasikan logic parsing full di sini seperti script pertama
    processed_data = []

    # Ambil default device
    try:
        def_cmd = f"pactl get-default-{MODE}"
        default_dev = subprocess.run(
            def_cmd.split(), capture_output=True, text=True
        ).stdout.strip()
    except:
        default_dev = ""

    for item in data:
        # Logic volume calculation
        vol_avg = 0
        if "volume" in item:
            vals = [
                int(v["value_percent"].strip("%")) for k, v in item["volume"].items()
            ]
            vol_avg = sum(vals) // len(vals) if vals else 0

        processed_data.append(
            {
                "id": item.get("index"),
                "name": item.get("description"),
                "name_short": item.get("description")[:25],
                "volume": vol_avg,
                "is_active": item.get("name") == default_dev,
                "type": MODE,
            }
        )
    return processed_data


def main():
    # 1. Print state awal saat widget pertama kali load
    print(json.dumps(get_data()), flush=True)

    # 2. Subscribe ke event PulseAudio
    # Kita hanya peduli event pada 'sink' atau 'source'
    cmd = ["pactl", "subscribe"]
    process = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )

    # 3. Infinite loop membaca output stdout dari 'pactl subscribe'
    while True:
        line = process.stdout.readline()
        if not line:
            break

        # Filter event. Contoh output: "Event 'change' on sink #48"
        # Kita refresh data CUMA kalau eventnya relevan
        if MODE in line or "server" in line:
            # 'server' event biasanya mentrigger default device change
            print(json.dumps(get_data()), flush=True)


if __name__ == "__main__":
    main()
