"""
Refine every previewed prop so they come back with PBR textures + base colors
instead of the white geometry output from preview mode.

Reads tasks.json for the preview_task_id of each asset, fires a refine task for
each in parallel, polls, and downloads the textured GLB (overwriting the
preview version in assets/models/).

Costs more Meshy credits than preview. Runs ~6 refines concurrently.
"""
import os
import sys
import time
import json
import requests
from concurrent.futures import ThreadPoolExecutor, as_completed

API_KEY = "msy_kHE3nWPaFASgPiVNQdgF64UpYPF6VBlHUHeY"
BASE = "https://api.meshy.ai/openapi/v2/text-to-3d"
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "models")
STATE_FILE = os.path.join(os.path.dirname(__file__), "tasks.json")
HEADERS = {"Authorization": f"Bearer {API_KEY}"}

# Texture hints per asset so Meshy paints the right colors during refine.
# Without these, it often defaults to a generic beige.
TEXTURE_PROMPTS = {
    "curved_desk":         "polished dark mahogany wood desk with warm brown varnished grain",
    "leather_armchair":    "saddle brown cognac leather armchair with wooden legs",
    "marble_bust":         "white polished marble sculpture bust with dark stone pedestal",
    "marble_bust_roman":   "white polished marble Roman emperor bust with gold laurel crown details",
    "marble_bust_stoic":   "white polished marble Greek philosopher bust",
    "marble_bust_general": "white polished marble military general bust with bronze uniform accents",
    "tall_bookshelf":      "dark walnut wood bookshelf with leather bound burgundy green and brown books",
    "antique_clock":       "antique brass mantel clock with dark mahogany case and white porcelain face",
    "oil_derrick":         "weathered tan wooden oil derrick tower model with rusty iron fittings",
    "artdeco_skyscraper":  "art deco skyscraper model tan limestone with dark bronze accents",
    "skyscraper_chrysler": "chrysler building model with silver metallic spire and tan stone base",
    "skyscraper_empire":   "Empire State Building model tan beige limestone with dark window rows",
    "skyscraper_woolworth":"gothic Woolworth skyscraper model tan stone with dark green copper spires",
    "coffee_table":        "light oak wood coffee table with clear glass of water and white candle",
    "workbench":           "industrial steel workbench with wooden top pegboard with colorful tools wrenches pliers",
    "framed_world_map":    "antique sepia parchment world map in dark wood frame with gold inlay",
    "giant_gear":          "massive rusty bronze industrial gear cog with weathered metal patina",
    "power_line_tower":    "tan wooden electric transmission tower with dark iron steel lattice",
    "factory_diorama":     "red brick industrial factory buildings with dark gray smokestacks on wooden base",
    "book_stack":          "stack of vintage leather bound books brown red green burgundy with gold embossed spines",
    "desk_lamp":           "vintage brass banker desk lamp with emerald green glass shade on dark wood base",
    "vintage_train":       "black iron steam locomotive with red accents gold brass detailing wooden tracks",
    "picture_frame":       "gilded gold ornate frame with sepia landscape photograph",
    "steam_engine":        "polished brass Victorian steam engine with copper pipes on dark wood base",
}


def load_state():
    return json.load(open(STATE_FILE))


def save_state(st):
    json.dump(st, open(STATE_FILE, "w"), indent=2)


def create_refine(name, preview_task_id):
    payload = {
        "mode": "refine",
        "preview_task_id": preview_task_id,
        "enable_pbr": True,
    }
    tp = TEXTURE_PROMPTS.get(name)
    if tp:
        payload["texture_prompt"] = tp
    r = requests.post(BASE, headers=HEADERS, json=payload, timeout=30)
    r.raise_for_status()
    tid = r.json().get("result")
    print(f"[{name}] refine started: {tid}")
    return tid


def poll(task_id, label, timeout=1500):
    start = time.time()
    last = -1
    while time.time() - start < timeout:
        r = requests.get(f"{BASE}/{task_id}", headers=HEADERS, timeout=30)
        r.raise_for_status()
        data = r.json()
        status = data.get("status")
        progress = data.get("progress", 0)
        if progress != last:
            print(f"[{label}] {status} {progress}%")
            last = progress
        if status == "SUCCEEDED":
            return data
        if status in ("FAILED", "CANCELED", "EXPIRED"):
            print(f"[{label}] ended {status}: {data.get('task_error')}")
            return None
        time.sleep(8)
    return None


def download(url, outpath, label):
    r = requests.get(url, stream=True, timeout=180)
    r.raise_for_status()
    with open(outpath, "wb") as f:
        for chunk in r.iter_content(8192):
            f.write(chunk)
    print(f"[{label}] -> {outpath}  ({os.path.getsize(outpath)/1024:.0f} KB)")


def process(name, state):
    entry = state.get(name, {})
    preview_id = entry.get("preview_task_id")
    if not preview_id:
        print(f"[{name}] no preview_task_id — skip")
        return False

    if entry.get("refined"):
        print(f"[{name}] already refined, skip")
        return True

    refine_id = entry.get("refine_task_id")
    if not refine_id:
        try:
            refine_id = create_refine(name, preview_id)
        except Exception as e:
            print(f"[{name}] refine create failed: {e}")
            return False
        entry["refine_task_id"] = refine_id
        state[name] = entry
        save_state(state)

    data = poll(refine_id, name)
    if not data:
        return False
    url = data.get("model_urls", {}).get("glb")
    if not url:
        print(f"[{name}] no glb url")
        return False

    out = os.path.join(OUT_DIR, f"{name}.glb")
    try:
        download(url, out, name)
        entry["refined"] = True
        state[name] = entry
        save_state(state)
        return True
    except Exception as e:
        print(f"[{name}] download failed: {e}")
        return False


def main():
    state = load_state()
    only = sys.argv[1:] if len(sys.argv) > 1 else list(state.keys())

    names = [n for n in only if n in state]
    if not names:
        print("no valid asset names")
        return

    print(f"refining {len(names)} props with up to 6 in parallel...\n")
    ok = {}
    with ThreadPoolExecutor(max_workers=6) as pool:
        futs = {pool.submit(process, name, state): name for name in names}
        for fut in as_completed(futs):
            nm = futs[fut]
            try:
                ok[nm] = fut.result()
            except Exception as e:
                print(f"[{nm}] exception: {e}")
                ok[nm] = False

    print("\n=== summary ===")
    for nm, good in ok.items():
        print(f"  {nm}: {'OK' if good else 'FAIL'}")


if __name__ == "__main__":
    main()
