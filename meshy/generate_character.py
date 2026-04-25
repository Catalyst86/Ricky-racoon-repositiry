"""
Generate Ricky the raccoon host: text-to-3D mesh, then rig it via Meshy's rigging API.
Downloads a rigged GLB (mesh + skeleton) ready for Godot AnimationPlayer.

Falls back gracefully if rigging is unavailable on the API tier - you still get
the un-rigged GLB and can drive a fake walk with procedural limb/body animation.
"""
import os
import sys
import time
import json
import requests

API_KEY = "msy_kHE3nWPaFASgPiVNQdgF64UpYPF6VBlHUHeY"
BASE = "https://api.meshy.ai/openapi"
HEADERS = {"Authorization": f"Bearer {API_KEY}"}

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "models")
STATE = os.path.join(os.path.dirname(__file__), "character.json")

PROMPT = (
    "Anthropomorphic raccoon character standing upright on two legs, Pixar Disney "
    "animation style, bright orange rust-colored fur, white furry muzzle and chest "
    "and belly, dark brown/black classic raccoon mask markings around large "
    "expressive blue eyes, small rounded ears with orange inside, wearing a buttoned "
    "royal blue suit jacket with white dress shirt and black necktie, black paws, "
    "bushy ringed tail with orange and dark brown stripes, full body T-pose, neutral "
    "facial expression, stylized cartoon character, clean white background"
)
NEG = (
    "photorealistic, scary, evil, low poly, flat, sitting, lying down, multiple "
    "characters, weapons, blood, nudity"
)


def load_state():
    return json.load(open(STATE)) if os.path.exists(STATE) else {}


def save_state(st):
    json.dump(st, open(STATE, "w"), indent=2)


def poll(url, label, timeout=1500):
    start = time.time()
    last = -1
    while time.time() - start < timeout:
        r = requests.get(url, headers=HEADERS, timeout=30)
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


def text_to_3d_preview(state):
    if state.get("preview_task_id"):
        return state["preview_task_id"]
    payload = {
        "mode": "preview",
        "prompt": PROMPT,
        "art_style": "realistic",
        "negative_prompt": NEG,
        "should_remesh": True,
        "topology": "quad",
        "target_polycount": 40000,
    }
    r = requests.post(f"{BASE}/v2/text-to-3d", headers=HEADERS, json=payload, timeout=30)
    r.raise_for_status()
    tid = r.json().get("result")
    print(f"[preview] task created: {tid}")
    state["preview_task_id"] = tid
    save_state(state)
    return tid


def text_to_3d_refine(state, preview_id):
    if state.get("refine_task_id"):
        return state["refine_task_id"]
    payload = {
        "mode": "refine",
        "preview_task_id": preview_id,
        "enable_pbr": True,
        "texture_prompt": "anthropomorphic orange raccoon with bright blue eyes wearing a blue suit jacket white shirt black necktie, pixar style",
    }
    r = requests.post(f"{BASE}/v2/text-to-3d", headers=HEADERS, json=payload, timeout=30)
    r.raise_for_status()
    tid = r.json().get("result")
    print(f"[refine] task created: {tid}")
    state["refine_task_id"] = tid
    save_state(state)
    return tid


def try_rigging(state, input_task_id):
    """Try Meshy's rigging endpoint. Returns task_id or None if the API rejects it."""
    if state.get("rig_task_id"):
        return state["rig_task_id"]
    # Meshy's rigging API. Endpoint / schema has moved around across versions — try both.
    for endpoint, payload in [
        (f"{BASE}/v1/rigging", {"input_task_id": input_task_id, "height_meters": 1.5}),
        (f"{BASE}/v1/rigging", {"preview_task_id": input_task_id, "height_meters": 1.5}),
    ]:
        try:
            r = requests.post(endpoint, headers=HEADERS, json=payload, timeout=30)
            if r.status_code in (200, 201, 202):
                tid = r.json().get("result") or r.json().get("id")
                if tid:
                    print(f"[rig] task created: {tid}")
                    state["rig_task_id"] = tid
                    save_state(state)
                    return tid
            else:
                print(f"[rig] endpoint returned {r.status_code}: {r.text[:300]}")
        except Exception as e:
            print(f"[rig] attempt failed: {e}")
    return None


def download(url, outpath, label):
    r = requests.get(url, stream=True, timeout=180)
    r.raise_for_status()
    with open(outpath, "wb") as f:
        for chunk in r.iter_content(8192):
            f.write(chunk)
    print(f"[{label}] downloaded -> {outpath}")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    state = load_state()

    # 1. Preview generation
    preview_id = text_to_3d_preview(state)
    preview_data = poll(f"{BASE}/v2/text-to-3d/{preview_id}", "preview")
    if not preview_data:
        print("preview failed")
        sys.exit(1)

    # 2. Refine with PBR textures for color
    refine_id = text_to_3d_refine(state, preview_id)
    refine_data = poll(f"{BASE}/v2/text-to-3d/{refine_id}", "refine")
    if not refine_data:
        print("refine failed, falling back to preview output")
        refine_data = preview_data

    # Save the non-rigged version first (always useful as fallback)
    glb_url = refine_data.get("model_urls", {}).get("glb")
    if glb_url:
        download(glb_url, os.path.join(OUT_DIR, "ricky_unrigged.glb"), "unrigged")

    # 3. Attempt rigging
    rig_id = try_rigging(state, refine_id if state.get("refine_task_id") else preview_id)
    if not rig_id:
        print("\nNOTE: rigging API was not available or rejected the request.")
        print("      The unrigged model is at assets/models/ricky_unrigged.glb")
        print("      You can rig it externally (Mixamo, Blender) and save as assets/models/ricky.glb")
        return

    rig_data = poll(f"{BASE}/v1/rigging/{rig_id}", "rig")
    if not rig_data:
        print("rigging failed")
        return
    rigged_url = (
        rig_data.get("model_urls", {}).get("glb")
        or rig_data.get("result_url")
        or rig_data.get("glb_url")
    )
    if rigged_url:
        download(rigged_url, os.path.join(OUT_DIR, "ricky.glb"), "rigged")
    else:
        print(f"rigged task succeeded but no GLB url found. raw: {rig_data}")


if __name__ == "__main__":
    main()
