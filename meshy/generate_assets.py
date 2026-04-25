"""
Meshy API asset generator for Ricky's Rants studio.
Kicks off text-to-3D tasks for each prop, polls for completion, downloads GLBs.
"""
import os
import sys
import time
import json
import requests
from concurrent.futures import ThreadPoolExecutor, as_completed

API_KEY = "msy_kHE3nWPaFASgPiVNQdgF64UpYPF6VBlHUHeY"
BASE_URL = "https://api.meshy.ai/openapi/v2/text-to-3d"
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "models")
STATE_FILE = os.path.join(os.path.dirname(__file__), "tasks.json")

HEADERS = {"Authorization": f"Bearer {API_KEY}"}

# Each asset: (filename, prompt, art_style, negative_prompt)
ASSETS = [
    ("curved_desk",
     "A curved semi-circular wooden podcast desk made of polished mahogany wood with vertical wood panel front, glossy varnished top, warm brown color, standalone furniture on white background, podcast studio furniture",
     "realistic",
     "low poly, cartoon, flat, paper"),

    ("leather_armchair",
     "A modern low-back leather armchair, saddle brown tan cognac leather upholstery, wooden legs, curved backrest, single seat accent chair for podcast guest",
     "realistic",
     "office chair, gaming chair, rolling chair"),

    ("marble_bust",
     "A small white marble bust statue of a bearded classical philosopher, shoulders and head, on a square pedestal base, museum decor sculpture",
     "realistic",
     "full body, color, modern"),

    ("tall_bookshelf",
     "A tall dark wood bookshelf with multiple shelves filled with old leather-bound books and antique brass clocks, library furniture, standalone",
     "realistic",
     "empty shelf, modern, metal"),

    ("antique_clock",
     "An antique mantel clock with brass pendulum face, dark mahogany wood case, Roman numerals, standalone desk clock",
     "realistic",
     "digital clock, wall clock, modern"),

    ("oil_derrick",
     "A miniature wooden oil derrick tower model, lattice wood beam construction, industrial rig scale model on small base, tan wood color",
     "realistic",
     "full size, modern pump, offshore"),

    ("artdeco_skyscraper",
     "A miniature art deco skyscraper architecture model, tan beige stone color, stepped setback design like Empire State Building, standalone model on base",
     "realistic",
     "modern glass tower, cartoon"),

    ("coffee_table",
     "A small low square wooden coffee table with a serving tray on top holding a clear water glass and small white candle, side table furniture",
     "realistic",
     "dining table, large table, round"),

    ("workbench",
     "An industrial electronics workbench with a pegboard tool wall above holding wrenches pliers and electronic components, steel legs, wood top with circuit boards on it",
     "realistic",
     "kitchen, desk, empty"),

    ("framed_world_map",
     "An antique vintage world map framed in dark wood, sepia parchment paper color, ornamental cartography, wall hanging rectangular frame",
     "realistic",
     "modern map, political, blue"),

    ("giant_gear",
     "A large rusty bronze industrial gear cog wheel, steampunk decor, mounted wall piece, worn metal texture",
     "realistic",
     "plastic, new, small screw"),

    ("power_line_tower",
     "A miniature wooden model of an electric power transmission tower pylon, lattice steel tower scale model, tan wood construction on small base",
     "realistic",
     "full size, modern, wire only"),

    # ==== Fill-out props: extra busts, more buildings, factory diorama, etc. ====

    ("marble_bust_roman",
     "A white marble bust statue of a Roman emperor with laurel crown and stern face, shoulders and head on square pedestal, museum sculpture, standalone",
     "realistic",
     "full body, color, modern, cartoon"),

    ("marble_bust_stoic",
     "A white marble bust of a clean-shaven classical Greek philosopher with short curled hair, head and shoulders, square pedestal base, museum decor",
     "realistic",
     "full body, beard, color, modern"),

    ("marble_bust_general",
     "A white marble bust of a 19th century military general with mustache and uniform collar, shoulders and head, pedestal base, museum sculpture",
     "realistic",
     "full body, color, modern, cartoon"),

    ("skyscraper_chrysler",
     "A miniature art deco chrysler building skyscraper architectural model, stepped metallic silver crown spire, tan stone lower floors, standalone on small base",
     "realistic",
     "modern glass tower, photo, cartoon"),

    ("skyscraper_empire",
     "A miniature Empire State Building architectural model, tan beige limestone, stepped setback crown, antenna top, standalone on small base",
     "realistic",
     "modern glass tower, photo, cartoon"),

    ("skyscraper_woolworth",
     "A miniature gothic revival Woolworth style skyscraper architectural model, tan stone, pointed spires, ornate details, standalone on small base",
     "realistic",
     "modern glass tower, photo, cartoon"),

    ("factory_diorama",
     "A small industrial factory diorama model with smokestacks and brick warehouse buildings on a wooden base, vintage model train style, tan and red brick colors, scale model",
     "realistic",
     "full scale, real factory, photo"),

    ("book_stack",
     "A tall stack of old leather-bound vintage books on top of each other, assorted brown red green cloth covers with gold embossed titles, standalone decorative stack",
     "realistic",
     "single book, open book, modern"),

    ("desk_lamp",
     "A small vintage brass desk lamp with green glass shade, banker's lamp style, turned wood base, warm yellow light on, standalone desk accessory",
     "realistic",
     "floor lamp, modern, plastic"),

    ("vintage_train",
     "A miniature vintage steam locomotive train engine scale model, black iron body with red accents, brass detailing, smokestack and boiler, standalone on small track base",
     "realistic",
     "modern train, full size, cartoon"),

    ("picture_frame",
     "An antique gilt gold picture frame containing a sepia landscape photograph of rolling hills and industrial buildings, rectangular wall hanging, vintage frame",
     "realistic",
     "modern frame, photo only, empty frame"),

    ("steam_engine",
     "A miniature brass steam engine machine model with pistons flywheel and copper pipes, Victorian industrial decor, standalone on wooden base",
     "realistic",
     "modern motor, cartoon, plastic"),
]


def load_state():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, "r") as f:
            return json.load(f)
    return {}


def save_state(state):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


def create_preview_task(name, prompt, art_style, negative_prompt):
    payload = {
        "mode": "preview",
        "prompt": prompt,
        "art_style": art_style,
        "negative_prompt": negative_prompt,
        "should_remesh": True,
        "topology": "triangle",
        "target_polycount": 30000,
    }
    r = requests.post(BASE_URL, headers=HEADERS, json=payload, timeout=30)
    r.raise_for_status()
    data = r.json()
    task_id = data.get("result") or data.get("id") or data.get("task_id")
    print(f"[{name}] preview task created: {task_id}")
    return task_id


def poll_task(task_id, name, timeout=900):
    start = time.time()
    last_progress = -1
    while time.time() - start < timeout:
        r = requests.get(f"{BASE_URL}/{task_id}", headers=HEADERS, timeout=30)
        r.raise_for_status()
        data = r.json()
        status = data.get("status")
        progress = data.get("progress", 0)
        if progress != last_progress:
            print(f"[{name}] {status} {progress}%")
            last_progress = progress
        if status == "SUCCEEDED":
            return data
        if status in ("FAILED", "CANCELED", "EXPIRED"):
            print(f"[{name}] task ended with status {status}: {data.get('task_error', {})}")
            return None
        time.sleep(8)
    print(f"[{name}] timeout after {timeout}s")
    return None


def download_glb(url, outpath, name):
    r = requests.get(url, stream=True, timeout=120)
    r.raise_for_status()
    with open(outpath, "wb") as f:
        for chunk in r.iter_content(chunk_size=8192):
            f.write(chunk)
    print(f"[{name}] downloaded -> {outpath}")


def process_asset(name, prompt, art_style, negative_prompt, state):
    outpath = os.path.join(OUT_DIR, f"{name}.glb")
    if os.path.exists(outpath):
        print(f"[{name}] already downloaded, skipping")
        return True

    entry = state.get(name, {})
    task_id = entry.get("preview_task_id")

    if not task_id:
        try:
            task_id = create_preview_task(name, prompt, art_style, negative_prompt)
        except Exception as e:
            print(f"[{name}] create failed: {e}")
            return False
        entry["preview_task_id"] = task_id
        state[name] = entry
        save_state(state)

    data = poll_task(task_id, name)
    if not data:
        return False

    model_urls = data.get("model_urls", {})
    glb_url = model_urls.get("glb")
    if not glb_url:
        print(f"[{name}] no glb url in response")
        return False

    try:
        download_glb(glb_url, outpath, name)
        entry["downloaded"] = True
        entry["glb_path"] = outpath
        state[name] = entry
        save_state(state)
        return True
    except Exception as e:
        print(f"[{name}] download failed: {e}")
        return False


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    state = load_state()

    only = sys.argv[1:] if len(sys.argv) > 1 else None

    with ThreadPoolExecutor(max_workers=6) as pool:
        futures = {}
        for name, prompt, art_style, neg in ASSETS:
            if only and name not in only:
                continue
            futures[pool.submit(process_asset, name, prompt, art_style, neg, state)] = name

        results = {}
        for fut in as_completed(futures):
            name = futures[fut]
            try:
                results[name] = fut.result()
            except Exception as e:
                print(f"[{name}] exception: {e}")
                results[name] = False

    print("\n=== summary ===")
    for name, ok in results.items():
        print(f"  {name}: {'OK' if ok else 'FAIL'}")


if __name__ == "__main__":
    main()
