#!/usr/bin/env python3
"""Render a screen inventory as Mermaid wireframes in Markdown files (no Excalidraw needed).

Usage:
  gen_mermaid.py --inventory screen-inventory.json --out-dir wireframes/ [--title "..."]

Writes <out-dir>/index.md plus one <section>.md per section. Each section file holds one
flow diagram (screens and the transitions between them) and one wireframe diagram per
screen (regions stacked in a subgraph, variants in a dashed note). Same inventory format
as gen_excalidraw.py.
"""
import argparse, json, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_excalidraw import classify, derive_sections  # noqa: E402

CLASSDEFS = """    classDef btn fill:#a5d8ff,stroke:#1971c2,color:#1e1e1e
    classDef inp fill:#ffffff,stroke:#868e96,stroke-dasharray:4 3,color:#1e1e1e
    classDef note fill:#fff3bf,stroke:#e8590c,color:#1e1e1e
    classDef blk fill:#e9ecef,stroke:#868e96,color:#1e1e1e
    classDef var fill:#ffffff,stroke:#868e96,stroke-dasharray:4 3,color:#495057
    classDef ext fill:#f8f9fa,stroke:#868e96,color:#495057"""


def mid(s):
    return re.sub(r"\W", "_", s)


def q(text):
    return '"' + text.replace('"', "#quot;").replace("\n", "<br/>") + '"'


def css_class(region):
    fill, _stroke, dashed = classify(region)
    return {"#a5d8ff": "btn", "#fff3bf": "note"}.get(fill, "inp" if dashed else "blk")


def flow_block(sec, by_id):
    ids = set(sec["ids"])
    lines = ["```mermaid", "flowchart LR"]
    for k in sec["ids"]:
        lines.append(f"    {mid(k)}[{q(by_id[k]['name'] + ' (' + k + ')')}]")
    ext = set()
    edges = []
    for k in sec["ids"]:
        for t in by_id[k].get("exit_to", []):
            if t in by_id and t != k:
                edges.append((k, t))
                if t not in ids:
                    ext.add(t)
    for t in sorted(ext):
        lines.append(f"    {mid(t)}([{q(by_id[t]['name'] + ' (' + t + ')')}])")
    lines += [f"    {mid(a)} --> {mid(b)}" for a, b in edges]
    lines.append(CLASSDEFS)
    lines += [f"    class {mid(t)} ext" for t in sorted(ext)]
    lines.append("```")
    return "\n".join(lines)


def screen_block(s):
    p = mid(s["id"])
    lines = ["```mermaid", "flowchart TB", f"    subgraph {p}_s[{q(s['name'] + '  (' + s['id'] + ')')}]", "        direction TB"]
    nodes = []
    for i, r in enumerate(s["regions"], 1):
        nodes.append(f"{p}_r{i}")
        lines.append(f"        {p}_r{i}[{q(r)}]")
    variants = s.get("variants", [])
    if variants:
        nodes.append(f"{p}_v")
        lines.append(f"        {p}_v[{q('Variants (stay on this screen):' + chr(10) + chr(10).join('- ' + v for v in variants))}]")
    lines += [f"        {a} ~~~ {b}" for a, b in zip(nodes, nodes[1:])]
    lines.append("    end")
    lines.append(CLASSDEFS)
    for i, r in enumerate(s["regions"], 1):
        lines.append(f"    class {p}_r{i} {css_class(r)}")
    if variants:
        lines.append(f"    class {p}_v var")
    lines.append("```")
    return "\n".join(lines)


def tag(s):
    if s.get("grounded") == "no":
        return " **(gap-derived proposal, not defined in the source)**"
    if s.get("debatable"):
        return " **(debatable split call)**"
    return ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--inventory", required=True)
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--title", default=None)
    a = ap.parse_args()
    data = json.load(open(a.inventory))
    screens = data["screens"] if isinstance(data, dict) else data
    title = a.title or (data.get("title") if isinstance(data, dict) else None) or "Screen wireframes"
    by_id = {s["id"]: s for s in screens}
    sections = (data.get("sections") if isinstance(data, dict) else None) or derive_sections(screens)
    os.makedirs(a.out_dir, exist_ok=True)
    index = [f"# {title}", "", f"{len(screens)} unique screens. Low-fidelity wireframes in Mermaid: structure and content, not visual design.",
             "Legend: blue = button or action, dashed white = input or control, yellow = note or banner, gray = content block.", "",
             "| Section | Screens | File |", "|---|---|---|"]
    for sec in sections:
        fname = f"{mid(sec['key']).lower()}.md"
        index.append(f"| {sec['title']} | {len(sec['ids'])} | [{fname}]({fname}) |")
        body = [f"# {sec['title']}", ""]
        if sec.get("subtitle"):
            body += [sec["subtitle"], ""]
        body += ["## Flow", "", flow_block(sec, by_id), ""]
        for k in sec["ids"]:
            s = by_id[k]
            body += [f"## {s['name']} (`{k}`){tag(s)}", "",
                     f"Platform: {s.get('platform', 'both')}. Kind: {s.get('kind', 'primary')}.", "", screen_block(s), "",
                     f"From: {', '.join(s.get('entry_from', [])) or 'none'}. To: {', '.join(s.get('exit_to', [])) or 'none'}.", ""]
        open(os.path.join(a.out_dir, fname), "w").write("\n".join(body))
    open(os.path.join(a.out_dir, "index.md"), "w").write("\n".join(index) + "\n")
    print(f"screens={len(screens)} sections={len(sections)} out_dir={a.out_dir}")


if __name__ == "__main__":
    main()
