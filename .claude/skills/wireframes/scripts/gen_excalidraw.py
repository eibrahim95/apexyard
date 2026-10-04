#!/usr/bin/env python3
"""Render a screen inventory as low-fidelity wireframe cards in one .excalidraw file.

Usage:
  gen_excalidraw.py --inventory screen-inventory.json --out wireframes.excalidraw \
      [--title "..."] [--origin-x 2400] [--origin-y -400]

Inventory: a JSON array of screens, or {"title", "sections": [...], "screens": [...]}.
Screen fields: id, name, journey, kind, platform, regions[], variants[], entry_from[],
exit_to[]. Optional: debatable (bool), grounded ("no" marks a gap-derived proposal).
Optional sections: [{"key", "title", "subtitle", "color", "ids": [...]}]. Without them,
sections are derived: hubs (id starts "hub-"), cross-cutting, then one per journey.
"""
import argparse, json, random, re

CW, GAP_X, GAP_Y, PER_ROW, PAD, FS, FS_S = 360, 80, 90, 5, 14, 14, 12
PALETTE = ["#d3f9d8", "#fff3bf", "#e5dbff", "#ffd8a8", "#c5f6fa", "#ffdeeb", "#e9fac8"]

BTN = re.compile(r"(\baction\b|\bsubmit\b|\bsave\b|\bpay\b|\bbuy\b|\bconfirm\b|\bcancel\b|\bretry\b|\ballow\b|not-now|\bkeep\b)", re.I)
INP = re.compile(r"(input|field|picker|switch|selection|choose |channel)", re.I)
NOTE = re.compile(r"^(note|statement|banner|warranty|message area)", re.I)


def classify(region):
    """Return (fill, stroke, dashed) for a region by its wording."""
    if NOTE.search(region.strip()):
        return "#fff3bf", "#e8590c", False
    if BTN.search(region):
        return "#a5d8ff", "#1971c2", False
    if INP.search(region):
        return "#ffffff", "#868e96", True
    return "#e9ecef", "#868e96", False


class Scene:
    def __init__(self):
        self.els, self.n = [], 0

    def nid(self, p):
        self.n += 1
        return f"{p}{self.n}"

    def base(self, t, x, y, w, h, **kw):
        e = dict(id=self.nid(t[:2]), type=t, x=x, y=y, width=w, height=h, angle=0,
                 strokeColor="#1e1e1e", backgroundColor="transparent", fillStyle="solid",
                 strokeWidth=1, strokeStyle="solid", roughness=1, opacity=100, groupIds=[],
                 frameId=None, roundness=None, seed=random.randint(1, 2**31), version=1,
                 versionNonce=random.randint(1, 2**31), isDeleted=False, boundElements=None,
                 updated=1, link=None, locked=False)
        e.update(kw)
        return e

    def rect(self, x, y, w, h, fill="transparent", stroke="#1e1e1e", dashed=False, gid=None, rounded=False, sw=1):
        e = self.base("rectangle", x, y, w, h, backgroundColor=fill, strokeColor=stroke,
                      strokeStyle="dashed" if dashed else "solid", strokeWidth=sw,
                      roundness={"type": 3} if rounded else None)
        if gid:
            e["groupIds"] = [gid]
        self.els.append(e)

    def text(self, x, y, txt, width, fs=FS, color="#1e1e1e", gid=None):
        lines = wrap(txt, width, fs)
        body = "\n".join(lines)
        e = self.base("text", x, y, width, len(lines) * fs * 1.25, strokeColor=color, text=body,
                      fontSize=fs, fontFamily=5, textAlign="left", verticalAlign="top",
                      containerId=None, originalText=body, autoResize=True, lineHeight=1.25, roughness=0)
        if gid:
            e["groupIds"] = [gid]
        self.els.append(e)
        return len(lines) * fs * 1.25


def wrap(text, width_px, fs):
    cpl = max(8, int(width_px / (fs * 0.56)))
    out = []
    for para in text.split("\n"):
        line = ""
        for w in para.split(" "):
            if len(line) + len(w) + (1 if line else 0) <= cpl:
                line = f"{line} {w}" if line else w
            else:
                out.append(line)
                line = w
        out.append(line)
    return out


def variants_text(s):
    return "Variants (stay on this screen)\n" + "\n".join("- " + v for v in s.get("variants", []))


def footer_text(s):
    return "From: " + ", ".join(s.get("entry_from", [])) + "\nTo: " + ", ".join(s.get("exit_to", []))


def measure(s):
    inner = CW - 2 * PAD
    h = PAD + len(wrap(s["name"], inner, 18)) * 22.5 + 6 + 28
    for r in s["regions"]:
        h += len(wrap(r, inner - 20, FS)) * FS * 1.25 + 28
    h += len(wrap(variants_text(s), inner - 20, FS_S)) * FS_S * 1.25 + 30
    h += len(wrap(footer_text(s), inner, FS_S)) * FS_S * 1.25 + PAD
    return h


def tag_for(s):
    if s.get("grounded") == "no":
        return "GAP-DERIVED PROPOSAL", "#e03131", 150
    if s.get("debatable"):
        return "DEBATABLE SPLIT", "#e8590c", 130
    return None


def draw_card(sc, s, x, y, H):
    gid, inner = sc.nid("g"), CW - 2 * PAD
    sc.rect(x, y, CW, H, fill="#ffffff", gid=gid, rounded=True, sw=2)
    cy = y + PAD
    cy += sc.text(x + PAD, cy, s["name"], inner, 18, gid=gid) + 6
    sc.text(x + PAD, cy, f'{s["id"]}  |  {s.get("platform", "both")}  |  {s.get("kind", "primary")}', inner, FS_S, "#868e96", gid)
    tag = tag_for(s)
    if tag:
        sc.text(x + CW - tag[2] - PAD, cy, tag[0], tag[2], FS_S, tag[1], gid)
    cy += 28
    for r in s["regions"]:
        fill, stroke, dashed = classify(r)
        bh = len(wrap(r, inner - 20, FS)) * FS * 1.25 + 20
        sc.rect(x + PAD, cy, inner, bh, fill=fill, stroke=stroke, dashed=dashed, gid=gid, rounded=True)
        sc.text(x + PAD + 10, cy + 10, r, inner - 20, FS, gid=gid)
        cy += bh + 8
    v = variants_text(s)
    vh = len(wrap(v, inner - 20, FS_S)) * FS_S * 1.25 + 20
    sc.rect(x + PAD, cy, inner, vh, stroke="#868e96", dashed=True, gid=gid)
    sc.text(x + PAD + 10, cy + 10, v, inner - 20, FS_S, "#495057", gid)
    cy += vh + 10
    sc.text(x + PAD, cy, footer_text(s), inner, FS_S, "#868e96", gid)


def derive_sections(screens):
    hubs = [s["id"] for s in screens if s["id"].startswith("hub-")]
    cross = [s["id"] for s in screens if s.get("journey") == "cross-cutting"]
    out = []
    if hubs:
        out.append(dict(key="hubs", title="Shared hubs (defined once, reused by journeys)", subtitle="", color="#d0ebff", ids=hubs))
    if cross:
        out.append(dict(key="cross", title="Cross-cutting screens", subtitle="Used by several journeys", color="#ffe3e3", ids=cross))
    seen = []
    for s in screens:
        j = s.get("journey")
        if j and j != "cross-cutting" and not s["id"].startswith("hub-") and j not in seen:
            seen.append(j)
    for i, j in enumerate(seen):
        ids = [s["id"] for s in screens if s.get("journey") == j and not s["id"].startswith("hub-")]
        out.append(dict(key=j, title=f"Journey {j}", subtitle="", color=PALETTE[i % len(PALETTE)], ids=ids))
    return out


def section(sc, by_id, sec, y, ox):
    width = PER_ROW * CW + (PER_ROW - 1) * GAP_X
    gid = sc.nid("g")
    sc.rect(ox, y, width, 96, fill=sec["color"], gid=gid, rounded=True, sw=2)
    sc.text(ox + 24, y + 14, sec["title"], width - 48, 28, gid=gid)
    if sec.get("subtitle"):
        sc.text(ox + 24, y + 56, sec["subtitle"], width - 48, 16, "#343a40", gid)
    y += 136
    ids = sec["ids"]
    for i in range(0, len(ids), PER_ROW):
        row = ids[i:i + PER_ROW]
        H = max(measure(by_id[k]) for k in row)
        for c, k in enumerate(row):
            draw_card(sc, by_id[k], ox + c * (CW + GAP_X), y, H)
        y += H + GAP_Y
    return y + 40


def legend(sc, title, count, y, ox):
    width = PER_ROW * CW + (PER_ROW - 1) * GAP_X
    gid = sc.nid("g")
    sc.rect(ox, y, width, 250, fill="#f8f9fa", gid=gid, rounded=True, sw=2)
    sc.text(ox + 24, y + 14, f"{title} ({count} unique screens)", width - 48, 30, gid=gid)
    sc.text(ox + 24, y + 62,
            "Low-fidelity wireframes: structure and content, not visual design. A state is its own screen only when the task or "
            "primary action changes, or it is a decision point. Loading, empty, inline errors and toggles are listed as Variants "
            "inside the screen. Shared hubs are drawn once and referenced by ID. TBD values stay TBD as in the source documents.",
            width - 48, 15, "#343a40", gid)
    kx, ky = ox + 24, y + 168
    for label, style in [("Button / action", ("#a5d8ff", "#1971c2", False)), ("Input / control", ("#ffffff", "#868e96", True)),
                         ("Note / statement / banner", ("#fff3bf", "#e8590c", False)), ("Content block", ("#e9ecef", "#868e96", False))]:
        sc.rect(kx, ky, 54, 30, fill=style[0], stroke=style[1], dashed=style[2], gid=gid, rounded=True)
        sc.text(kx + 64, ky + 6, label, 240, 15, gid=gid)
        kx += 330
    sc.text(ox + 24, ky + 44, "Orange tag = debatable split call. Red tag = gap-derived proposal not defined in the source.",
            width - 48, 15, "#e8590c", gid)
    return y + 310


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--inventory", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--title", default=None)
    ap.add_argument("--origin-x", type=int, default=0)
    ap.add_argument("--origin-y", type=int, default=0)
    a = ap.parse_args()
    random.seed(7)
    data = json.load(open(a.inventory))
    screens = data["screens"] if isinstance(data, dict) else data
    title = a.title or (data.get("title") if isinstance(data, dict) else None) or "Screen wireframes"
    by_id = {s["id"]: s for s in screens}
    sections = (data.get("sections") if isinstance(data, dict) else None) or derive_sections(screens)
    sc, y = Scene(), a.origin_y
    y = legend(sc, title, len(screens), y, a.origin_x)
    for sec in sections:
        y = section(sc, by_id, sec, y, a.origin_x)
    json.dump({"type": "excalidraw", "version": 2, "source": "apexyard /wireframes", "elements": sc.els,
               "appState": {"viewBackgroundColor": "#ffffff"}, "files": {}}, open(a.out, "w"))
    print(f"elements={len(sc.els)} screens={len(screens)} bottom_y={y} out={a.out}")


if __name__ == "__main__":
    main()
