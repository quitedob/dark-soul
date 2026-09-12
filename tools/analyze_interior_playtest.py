"""Report observed interior playtests without treating scripted checks as players."""
import argparse
import collections
import html
import json
import pathlib
import statistics

parser = argparse.ArgumentParser()
parser.add_argument("events", type=pathlib.Path)
parser.add_argument("--output", type=pathlib.Path, required=True)
args = parser.parse_args()
rows = [json.loads(line) for line in args.events.read_text(encoding="utf-8").splitlines() if line.strip()]
human = [r for r in rows if r.get("source") == "interactive"]
solves = [r for r in human if r.get("kind") == "puzzle_solved"]
timed = [r["seconds"] for r in solves if r.get("entered_observed") and isinstance(r.get("seconds"), (int, float))]
deaths = [r for r in human if r.get("kind") == "death" and r.get("first_ascent")]
counts = collections.Counter(r.get("floor") for r in deaths)
args.output.mkdir(parents=True, exist_ok=True)
median = f"{statistics.median(timed):.1f} 秒（{len(timed)} 次完整计时）" if timed else "未测：没有完整的玩家解谜计时。"
no_read = f"{sum(not r.get('read_clue') for r in solves) / len(solves):.1%}（分母 {len(solves)} 次解开）" if solves else "未测：没有玩家完成记录。"
report = ["# 楼内首轮体验指标", "", f"数据：{len(human)} 条交互运行事件；排除 {len(rows)-len(human)} 条自动化事件。", "",
          "## 卡一：解谜时间中位数", "", median, "", "计时从首次站上该楼层到解开机关，含战斗与死亡等待；缺少进入事件的读档样本不计入。", "",
          "## 卡二：未读碑解开比例", "", no_read, "", "统计解开前从未读取该碑的完成事件。此值不能区分观察、猜测和旁人提示，需要访谈配对。", "",
          "## 卡三：首轮死亡位置", "", f"死亡样本 {len(deaths)}；一层 {counts[1]}，二层 {counts[2]}，三层 {counts[3]}。" if deaths else "未测：没有首轮玩家死亡记录。", "",
          "有数据时见 death-heatmap.svg。小样本与零死亡均不证明威胁曲线达标。"]
report += ["", "## 按关卡与楼层", "", "| 关卡 | 楼层 | 完成数 | 完整计时中位数 | 未读碑比例 |", "|---|---|---|---|---|"]
groups = collections.defaultdict(list)
for event in solves:
    groups[(event.get("level_id", "unknown"), event.get("floor", 0))].append(event)
for (level, floor), group in sorted(groups.items()):
    durations = [r["seconds"] for r in group if r.get("entered_observed") and isinstance(r.get("seconds"), (int, float))]
    duration = f"{statistics.median(durations):.1f} 秒 (n={len(durations)})" if durations else "未测"
    unread = sum(not r.get("read_clue") for r in group) / len(group)
    report.append(f"| {level} | {floor} | {len(group)} | {duration} | {unread:.1%} |")
if not groups:
    report.append("| 未测 | — | 0 | 未测 | 未测 |")
(args.output / "metrics.md").write_text("\n".join(report) + "\n", encoding="utf-8")
cells = collections.Counter((r["floor"], max(0,min(6,int((r["position"][0]+21)/6))), max(0,min(6,int((r["position"][2]+21)/6)))) for r in deaths)
svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="840" height="340" viewBox="0 0 840 340">', '<rect width="840" height="340" fill="#111820"/>', '<text x="20" y="28" fill="#eee" font-family="sans-serif" font-size="18">First-ascent player deaths — observed samples only</text>']
highest = max(cells.values(), default=1)
for floor in range(1,4):
    x0 = 20+(floor-1)*275
    svg.append(f'<text x="{x0}" y="57" fill="#ddd" font-family="sans-serif">Floor {floor} · n={counts[floor]}</text>')
    for x in range(7):
        for z in range(7):
            n = cells[(floor,x,z)]
            color = f'rgb({50+int(190*n/highest)}, {60-int(25*n/highest)}, {72-int(40*n/highest)})'
            svg.append(f'<rect x="{x0+x*34}" y="{70+z*34}" width="32" height="32" fill="{color}"><title>{html.escape(str(n))} observed deaths</title></rect>')
svg.append('</svg>')
(args.output / "death-heatmap.svg").write_text("\n".join(svg), encoding="utf-8")
print(f"INTERIOR_PLAYTEST_REPORT interactive_events={len(human)} solves={len(solves)} deaths={len(deaths)}")
