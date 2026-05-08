#!/usr/bin/env bash
set -euo pipefail
BASE="$HOME/.hermes"
mkdir -p \
"$BASE/inbox/strategy_reports" \
"$BASE/inbox/execution_reports" \
"$BASE/inbox/result_reports" \
"$BASE/processed/strategy_reports" \
"$BASE/processed/execution_reports" \
"$BASE/processed/result_reports" \
"$BASE/memory/archive" \
"$BASE/feedback/global" \
"$BASE/cache" \
"$BASE/reports/daily" \
"$BASE/reports/weekly" \
"$BASE/main" \
"$BASE/logs"
cat > "$BASE/main/collector.py" <<'PY'
import json
from pathlib import Path
from datetime import datetime
BASE = Path.home() / ".hermes"
JOBS = {
"strategy_reports": BASE / "memory" / "picks.jsonl",
"execution_reports": BASE / "memory" / "executions.jsonl",
"result_reports": BASE / "memory" / "results.jsonl",
}
def append_jsonl(path, data):
path.parent.mkdir(parents=True, exist_ok=True)
with path.open("a", encoding="utf-8") as f:
f.write(json.dumps(data, ensure_ascii=False) + "\n")
def process(folder, output):
inbox = BASE / "inbox" / folder
processed = BASE / "processed" / folder
inbox.mkdir(parents=True, exist_ok=True)
processed.mkdir(parents=True, exist_ok=True)
for file in sorted(inbox.glob("*.json")):
try:
data = json.loads(file.read_text(encoding="utf-8"))
data["_collector"] = {
"collected_at": datetime.now().isoformat(),
"source_file": file.name,
"folder": folder
}
append_jsonl(output, data)
file.rename(processed / file.name)
except Exception as e:
with (BASE / "logs" / "collector_errors.log").open("a", encoding="utf-8") as f:
f.write(f"[{datetime.now().isoformat()}] {file}: {e}\n")
def main():
for folder, output in JOBS.items():
process(folder, output)
if __name__ == "__main__":
main()
PY
cat > "$BASE/main/context_builder.py" <<'PY'
import json
from pathlib import Path
from datetime import date, datetime
BASE = Path.home() / ".hermes"
ROBOTS = ["robot-2", "robot-4", "robot-5", "robot-7", "robot-8", "robot-9", "robot-10"]
def read_jsonl(path):
if not path.exists():
return []
rows = []
for line in path.read_text(encoding="utf-8").splitlines():
try:
rows.append(json.loads(line))
except Exception:
pass
return rows
def parse_date(x):
try:
return datetime.fromisoformat(str(x).replace(" ", "T")[:19]).date()
except Exception:
return None
def score_lesson(x):
success = int(x.get("success_count", 0) or 0)
failed = int(x.get("failed_count", 0) or 0)
confidence = float(x.get("confidence", 0.5) or 0.5)
base = success * 2 - failed * 3 + confidence * 5
d = parse_date(x.get("date") or x.get("created_at"))
if d:
age = (date.today() - d).days
if age <= 7:
base += 3
elif age <= 30:
base += 2
elif age <= 90:
base += 1
elif age > 180:
base -= 99
return base
def build_for_robot(robot):
lessons = read_jsonl(BASE / "memory" / "lessons.jsonl")
filtered = []
for x in lessons:
targets = x.get("target_robot", [])
if "all" in targets or robot in targets or x.get("scope") == "global":
if x.get("status", "active") == "active":
filtered.append(x)
filtered = sorted(filtered, key=score_lesson, reverse=True)[:12]
lines = []
lines.append(f"# main 经验注入 - {robot}")
lines.append("")
lines.append(f"生成时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
lines.append("")
lines.append("你必须参考以下经验，但不必盲从。")
lines.append("如果你的独立判断与经验冲突，必须说明原因。")
lines.append("")
if not filtered:
lines.append("- 暂无可注入经验。")
else:
for i, x in enumerate(filtered, 1):
lines.append(f"{i}. {x.get('lesson', '')}")
rule = x.get("rule", "")
if rule:
lines.append(f" - 规则：{rule}")
cond = x.get("condition", "")
if cond:
lines.append(f" - 适用条件：{cond}")
avoid = x.get("avoid_condition", "")
if avoid:
lines.append(f" - 回避条件：{avoid}")
out = BASE / "cache" / f"{robot}_context.md"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text("\n".join(lines), encoding="utf-8")
def main():
for robot in ROBOTS:
build_for_robot(robot)
if __name__ == "__main__":
main()
PY
cat > "$BASE/main/memory_builder.py" <<'PY'
import json
from pathlib import Path
from datetime import date, datetime, timedelta
from collections import Counter
BASE = Path.home() / ".hermes"
PICKS = BASE / "memory" / "picks.jsonl"
LESSONS = BASE / "memory" / "lessons.jsonl"
def read_jsonl(path):
if not path.exists():
return []
rows = []
for line in path.read_text(encoding="utf-8").splitlines():
try:
rows.append(json.loads(line))
except Exception:
pass
return rows
def write_jsonl(path, rows):
path.parent.mkdir(parents=True, exist_ok=True)
with path.open("w", encoding="utf-8") as f:
for r in rows:
f.write(json.dumps(r, ensure_ascii=False) + "\n")
def parse_day(x):
try:
return datetime.fromisoformat(str(x).replace(" ", "T")[:19]).date()
except Exception:
return None
def main():
rows = read_jsonl(PICKS)
today = date.today()
strategies = Counter()
risks = Counter()
markets = Counter()
for r in rows:
d = parse_day(r.get("time") or r.get("_collector", {}).get("collected_at"))
if not d or (today - d).days > 30:
continue
markets[r.get("market_state", "未知行情")] += 1
for stock in r.get("stocks", []):
for tag in stock.get("strategy_tags", []):
strategies[tag] += 1
for risk in stock.get("risk", []):
risks[risk] += 1
old = read_jsonl(LESSONS)
new = []
for tag, count in strategies.most_common(10):
new.append({
"id": f"lesson_{today}_strategy_{abs(hash(tag))}",
"date": str(today),
"scope": "global",
"target_robot": ["all"],
"strategy_tags": [tag],
"lesson": f"近30天「{tag}」出现 {count} 次，需要跟踪其真实有效性，避免只因高频出现而过度使用。",
"rule": f"使用「{tag}」时必须说明适用行情、失败条件、风险点。",
"condition": "该策略与当前行情匹配",
"avoid_condition": "行情退潮、量能不足、风险标签集中",
"success_count": 0,
"failed_count": 0,
"confidence": min(0.9, 0.45 + count * 0.03),
"status": "active",
"created_at": str(today),
"last_verified_at": str(today),
"expire_at": str(today + timedelta(days=180)),
"source": "main_memory_builder"
})
for risk, count in risks.most_common(10):
new.append({
"id": f"lesson_{today}_risk_{abs(hash(risk))}",
"date": str(today),
"scope": "global",
"target_robot": ["all"],
"strategy_tags": [],
"lesson": f"近30天风险点「{risk}」出现 {count} 次，推荐时需要降低盲目乐观。",
"rule": f"出现「{risk}」时，confidence 不应过高，必须给出回避条件。",
"condition": "推荐理由中出现该风险",
"avoid_condition": "风险未释放、市场缩量、情绪退潮",
"success_count": 0,
"failed_count": 0,
"confidence": min(0.95, 0.5 + count * 0.04),
"status": "active",
"created_at": str(today),
"last_verified_at": str(today),
"expire_at": str(today + timedelta(days=180)),
"source": "main_memory_builder"
})
ids = {x.get("id") for x in old}
merged = old + [x for x in new if x.get("id") not in ids]
write_jsonl(LESSONS, merged)
layers = {
"lessons_hot_7d.jsonl": 7,
"lessons_recent_30d.jsonl": 30,
"lessons_mid_90d.jsonl": 90,
"lessons_long_180d.jsonl": 180,
}
for filename, days in layers.items():
subset = []
for x in merged:
d = parse_day(x.get("date") or x.get("created_at"))
if d and (today - d).days <= days and x.get("status", "active") == "active":
subset.append(x)
write_jsonl(BASE / "memory" / filename, subset)
archive = []
for x in merged:
d = parse_day(x.get("date") or x.get("created_at"))
if d and (today - d).days > 180:
archive.append(x)
write_jsonl(BASE / "memory" / "archive" / "lessons_before_180d.jsonl", archive)
if __name__ == "__main__":
main()
PY
cat > "$BASE/main/daily_review.py" <<'PY'
import json
from pathlib import Path
from datetime import date, datetime
from collections import Counter
BASE = Path.home() / ".hermes"
PICKS = BASE / "memory" / "picks.jsonl"
OUT = BASE / "reports" / "daily" / f"{date.today().isoformat()}.md"
def read_jsonl(path):
if not path.exists():
return []
rows = []
for line in path.read_text(encoding="utf-8").splitlines():
try:
rows.append(json.loads(line))
except Exception:
pass
return rows
def main():
today = date.today().isoformat()
rows = []
for r in read_jsonl(PICKS):
t = str(r.get("time") or r.get("_collector", {}).get("collected_at", ""))
if t.startswith(today):
rows.append(r)
robots = Counter(r.get("robot", "unknown") for r in rows)
stocks = Counter()
tags = Counter()
risks = Counter()
for r in rows:
for s in r.get("stocks", []):
label = f"{s.get('code','')} {s.get('name','')}".strip()
if label:
stocks[label] += 1
for tag in s.get("strategy_tags", []):
tags[tag] += 1
for risk in s.get("risk", []):
risks[risk] += 1
lines = [
f"# Hermes 每日策略复盘 - {today}",
"",
f"生成时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
"",
f"- 今日策略复盘包：{len(rows)} 份",
f"- 参与机器人：{len(robots)} 个",
"",
"## 机器人交作业统计",
""
]
for k, v in robots.most_common():
lines.append(f"- {k}: {v}")
lines += ["", "## 高频策略", ""]
for k, v in tags.most_common(20):
lines.append(f"- {k}: {v}")
if not tags:
lines.append("- 暂无")
lines += ["", "## 重复推荐股票", ""]
repeated = [(k, v) for k, v in stocks.most_common() if v >= 2]
if repeated:
for k, v in repeated:
lines.append(f"- {k}: {v}")
else:
lines.append("- 暂无")
lines += ["", "## 风险集中点", ""]
for k, v in risks.most_common(20):
lines.append(f"- {k}: {v}")
if not risks:
lines.append("- 暂无")
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(lines), encoding="utf-8")
print(OUT)
if __name__ == "__main__":
main()
PY
cat > "$BASE/inbox/strategy_reports/robot-test_$(date +%Y%m%d_%H%M%S).json" <<'JSON'
{
"type": "strategy_report",
"robot": "robot-test",
"version": "v-test",
"role": "测试机器人",
"time": "2026-05-08 14:30:00",
"market_state": "测试行情",
"stocks": [
{
"code": "000001",
"name": "测试股票",
"strategy_tags": ["测试策略"],
"reason": "测试理由",
"confidence": 88,
"risk": ["测试风险"],
"expected_horizon": ["T+1", "T+3", "T+5"]
}
],
"self_review": "测试复盘"
}
JSON
python3 "$BASE/main/collector.py"
python3 "$BASE/main/memory_builder.py"
python3 "$BASE/main/context_builder.py"
python3 "$BASE/main/daily_review.py"
echo "✅ Hermes 经验系统增强版部署完成"
echo "检查："
echo " ls ~/.hermes/memory"
echo " ls ~/.hermes/cache"
echo " cat ~/.hermes/reports/daily/$(date +%F).md"