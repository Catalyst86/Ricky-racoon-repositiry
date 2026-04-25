"""
Re-fetch the completed rigging task and download the rigged character + animation GLBs.
Meshy returns these under result.rigged_character_glb_url and result.basic_animations.*,
which my original script didn't know about.
"""
import os
import json
import requests

API_KEY = "msy_kHE3nWPaFASgPiVNQdgF64UpYPF6VBlHUHeY"
BASE = "https://api.meshy.ai/openapi"
HEADERS = {"Authorization": f"Bearer {API_KEY}"}

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "models")
STATE = os.path.join(os.path.dirname(__file__), "character.json")


def download(url, outpath, label):
    r = requests.get(url, stream=True, timeout=180)
    r.raise_for_status()
    with open(outpath, "wb") as f:
        for chunk in r.iter_content(8192):
            f.write(chunk)
    size = os.path.getsize(outpath)
    print(f"[{label}] -> {outpath}  ({size/1024:.0f} KB)")


def main():
    state = json.load(open(STATE))
    rig_task_id = state.get("rig_task_id")
    if not rig_task_id:
        print("No rig_task_id in character.json")
        return
    r = requests.get(f"{BASE}/v1/rigging/{rig_task_id}", headers=HEADERS, timeout=30)
    r.raise_for_status()
    data = r.json()
    if data.get("status") != "SUCCEEDED":
        print(f"Rig task not succeeded: {data.get('status')}")
        return

    result = data.get("result", {})
    rigged_glb = result.get("rigged_character_glb_url")
    anims = result.get("basic_animations", {})
    walk_glb = anims.get("walking_glb_url")
    run_glb = anims.get("running_glb_url")

    if rigged_glb:
        download(rigged_glb, os.path.join(OUT_DIR, "ricky.glb"), "ricky (rigged T-pose)")
    if walk_glb:
        download(walk_glb, os.path.join(OUT_DIR, "ricky_walk.glb"), "ricky_walk")
    if run_glb:
        download(run_glb, os.path.join(OUT_DIR, "ricky_run.glb"), "ricky_run")

    print("\nDone. Ricky models saved.")


if __name__ == "__main__":
    main()
