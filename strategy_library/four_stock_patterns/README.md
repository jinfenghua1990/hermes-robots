# 四种选股模式策略库

用途：给 Hermes / OpenClaw 读取、执行、回测和后续版本对照。

当前策略主线：`四种选股模式_原版_v1.0` 为永久 baseline，所有优化版必须与 baseline 做 AB 对照，禁止直接覆盖原版。

## 目录

```text
strategy_library/four_stock_patterns/
├── README.md
├── manifest.yaml
├── baseline/
│   └── four_stock_patterns_original_v1.yaml
├── optimized/
│   └── four_stock_patterns_optimized_v1_1.yaml
├── runtime/
│   └── selector_engine.py
└── hermes_openclaw/
    └── agent_instruction.md
```

## 版本说明

### baseline/original v1.0

来自用户上传文档《四种选股模式（原版）》，整理时间 2026-03-25，回测验证区间为 2025年11月 - 2026年2月。

原则：

- 四个模式独立运行。
- 每个模式的买入条件必须同时满足。
- 不加入大盘过滤、板块强度、AI 权重、自学习参数或额外升级条件。
- 永不覆盖，只作为对照组。

### optimized v1.1

优化目标：不是改变原版买入逻辑，而是增强 Hermes/OpenClaw 的工程可执行性。

优化内容：

- 增加统一字段命名。
- 增加 `entry_gate`、`score_rules`、`select_rule` 三段式结构。
- 增加 `risk_notes` 和 `ab_test_required`。
- 增加运行时 selector_engine，用于机器人读取策略并输出候选模式。

## Hermes/OpenClaw 接入建议

1. 机器人启动时读取 `manifest.yaml`。
2. 默认加载 `optimized/four_stock_patterns_optimized_v1_1.yaml`。
3. 同时保留 `baseline/four_stock_patterns_original_v1.yaml` 做对照。
4. 每次选股输出必须包含：
   - stock_code
   - stock_name
   - matched_patterns
   - pattern_scores
   - matched_conditions
   - failed_conditions
   - selected_version
   - baseline_comparison

## 重要声明

本策略库只负责选股信号研究与记录，不构成投资建议。实盘必须结合风险控制、止损、仓位管理和基本面风险。
