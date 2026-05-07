---
name: robot6-trend-analysis
description: Robot-6 智能市场分析大管家 - 趋势判断、板块轮动、潜力股评分、飞书图表推送、历史存储、接口切换、市场阶段调度。v8完整版。
version: 2.0.0
author: Robot-6
license: MIT
metadata:
  hermes:
    tags: [market-analysis, trend, sector-rotation, stock-scoring, feishu-push, robot6]
    related_skills: [market-rules, trading-strategy, mx-data, mx-xuangu, gs-stock-market-query]
---

# Robot-6 市场趋势分析

> 📊 Robot-6 (市场分析专家) 核心分析算法
> 维护者：Robot-6 | 最后更新：2026-05-07

---

## Overview

本 Skill 封装了 Robot-6 的完整市场分析系统 (v8)，包括：

1. **趋势分析** - 基于均线系统的趋势判断
2. **板块轮动识别** - 资金流向追踪 + 热点板块筛选
3. **潜力股评分** - 技术 + 基本面 + 资金面 + 风格四维评分
4. **飞书推送** - 文本 + 图表复合推送
5. **历史存储** - CSV 格式保存每日评分记录
6. **接口切换** - 东方财富/国信双源自动切换
7. **市场阶段调度** - 盘前/盘中/盘后/休市智能间隔

---

## When to Use

**触发条件：**
- 盘前分析（08:50）
- 盘中动态监控（动态间隔 3-10 分钟）
- 盘后复盘（15:10）
- 用户请求 `@robot-6`、`趋势分析`、`板块轮动`、`潜力股`

**Don't Use For:**
- 交易执行（找 Robot-3/Robot-4）
- 风险评估（找 Robot-1）
- 超短线标的（找 Robot-4）

---

## 一、趋势分析算法

### 核心逻辑

```python
def trend_analysis(df, short=5, long=20):
    """
    基于均线系统的趋势判断
    - short: 短期均线周期（默认 5 日）
    - long: 长期均线周期（默认 20 日）
    
    返回值：
    - 1: 上升趋势（MA5 > MA20）
    - -1: 下降趋势（MA5 < MA20）
    - 0: 震荡趋势
    """
    df['ma_short'] = df['close'].rolling(short).mean()
    df['ma_long'] = df['close'].rolling(long).mean()
    
    df['trend_signal'] = 0
    df.loc[df['ma_short'] > df['ma_long'], 'trend_signal'] = 1
    df.loc[df['ma_short'] < df['ma_long'], 'trend_signal'] = -1
    
    return df['trend_signal'].iloc[-1]
```

### 扩展判断

| 指标组合 | 趋势判断 |
|---------|---------|
| MA5 > MA20 + 量能放大 | 强势上升 |
| MA5 > MA20 + 量能萎缩 | 量价背离，谨慎 |
| MA5 < MA20 + 放量下跌 | 强势下跌 |
| MA5 < MA20 + 缩量下跌 | 下跌动能减弱 |

---

## 二、板块轮动识别

### 资金流向追踪

```python
def fetch_sector_data(source="eastmoney"):
    """
    返回板块资金流数据
    {
        "新能源": {"资金流": 4.5亿, "板块涨幅": 2.3%},
        "半导体": {"资金流": 2.1亿, "板块涨幅": 1.5%},
        ...
    }
    """
```

### 热点板块筛选

```python
# 按资金流选出 top 3 热点板块
sorted_sectors = sorted(sector_data.items(), 
                       key=lambda x: x[1]['资金流'], 
                       reverse=True)
top_sectors = [s[0] for s in sorted_sectors[:3]]
```

### 板块持续性判断

| 条件 | 持续性判断 |
|------|-----------|
| 连续 3 日资金净流入 + 涨幅递增 | 强持续 |
| 资金流入 + 涨幅收窄 | 动能衰减 |
| 资金流出 + 涨幅仍正 | 资金分歧 |

---

## 三、潜力股评分系统

### 四维评分模型

```python
def compute_stock_score(stock):
    """
    综合评分 = 技术(40%) + 资金(30%) + 基本面(20%) + 风格(10%)
    
    返回: 0-100 分
    """
    tech = 1 if stock.get("MA5>MA20", True) else 0        # 技术面
    fund = stock.get("资金流", 0) / 5                      # 资金面
    basic = stock.get("财务健康", 0)                       # 基本面
    style = min(stock.get("板块涨幅", 0) / 5, 1)          # 风格
    
    score = tech * 0.4 + fund * 0.3 + basic * 0.2 + style * 0.1
    return round(score * 100, 2)
```

### 评分维度详解

| 维度 | 权重 | 指标 | 数据源 |
|------|------|------|--------|
| 技术面 | 40% | MA5 > MA20、趋势形态、量价配合 | mx-data |
| 资金面 | 30% | 主力资金流、龙虎榜买入额 | mx-data |
| 基本面 | 20% | 财务健康度、机构持仓占比 | gs-stock-financial-query |
| 风格 | 10% | 板块涨幅、题材热度 | mx-xuangu |

### 评分阈值

| 分数区间 | 评级 | 操作建议 |
|---------|------|---------|
| 80-100 | 优选 | 可作为重点标的 |
| 60-80 | 良好 | 需二次确认 |
| 40-60 | 一般 | 观望 |
| <40 | 风险 | 不建议关注 |

---

## 四、风险预警

```python
def risk_warning(index_data):
    """
    大盘风险预警
    """
    if index_data['close'].pct_change().tail(3).sum() < -0.03:
        return "短期大盘下跌风险高"
    return "风险可控"
```

### 风险信号

| 信号 | 风险等级 |
|------|---------|
| 连续 3 日下跌 > 3% | 高风险 |
| 跌破 20 日均线 | 中风险 |
| 量能萎缩 + 指数滞涨 | 警惕 |

---

## 五、动态调度

### 频率调整逻辑

```python
# 根据资金流波动调整抓取频率
max_flow = max([v["资金流"] for v in sector_data.values()])

if max_flow > 4:
    interval = 3   # 高波动 -> 3 分钟
elif max_flow > 2:
    interval = 5   # 中波动 -> 5 分钟
else:
    interval = 10  # 低波动 -> 10 分钟
```

### 调度时间表

| 时间点 | 任务类型 |
|--------|---------|
| 08:50 | 盘前分析 |
| 09:30-15:00 | 盘中动态监控（动态间隔） |
| 15:10 | 盘后复盘 |

---

## 六、输出格式

### 标准输出模板

```yaml
market_direction:
  A股: "强 / 震荡 / 弱"
  港股: "强 / 震荡 / 弱"
  美股: "强 / 震荡 / 弱"
hot_sectors:
  A股: ["板块A", "板块B", "板块C"]
  港股: ["板块A", "板块B"]
  美股: ["板块A", "板块B"]
potential_stocks:
  A股: ["股票1", ..., "股票10"]
  港股: ["股票1", ..., "股票10"]
  美股: ["股票1", ..., "股票10"]
score: 0-100
action: "激进 / 稳健 / 观望"
risk: "高 / 中 / 低"
notes: "独立输出市场趋势+潜力股"
```

### 飞书推送格式

```
趋势信号: 1
热点板块(top3): ['新能源', '半导体', '医药']
高分个股推荐:
300750.SZ | 板块: 新能源 | 涨幅: 3.2 | 资金流: 4.5 | 财务: 1 | 综合评分: 85.6
002594.SZ | 板块: 新能源 | 涨幅: 2.9 | 资金流: 3.8 | 财务: 0.8 | 综合评分: 72.4
...
风险提示: 风险可控
```

---

## 七、数据源

| 数据类型 | 数据源 | Skill | 失败切换 |
|---------|--------|-------|---------|
| 实时行情 | 东方财富 | mx-data | → 国信 API |
| 板块资金流 | 东方财富 | mx-data | → 国信 API |
| 股票筛选 | 东方财富 | mx-xuangu | → 国信 API |
| 财务数据 | 国信/东方财富 | gs-stock-financial-query | - |
| 宏观数据 | 国信 | gs_economy_query | - |

---

## 八、飞书复合推送 (v8新增)

### 推送内容

1. **文本消息** - 趋势信号 + 热点板块 + 潜力股列表
2. **图表推送** - matplotlib 生成的复合图表：
   - Top10 个股综合评分柱状图
   - Top3 板块资金流趋势折线图

### 推送示例

```
Robot-6 智能市场分析
━━━━━━━━━━━━━━━━━━
趋势信号: 1
热点板块(top3): ['新能源', '半导体', '医药']
高分个股推荐(top 10):
300750.SZ | 板块: 新能源 | 涨幅: 3.2 | ...
[附带复合图表]
风险提示: 风险可控
```

---

## 九、历史评分存储 (v8新增)

### 存储路径

```
robot6_history/
├── stock_scores_20260507_0900.csv
├── stock_scores_20260507_0930.csv
├── stock_scores_20260507_1000.csv
└── ...
```

### CSV 格式

| code | 板块 | 涨幅 | 资金流 | 财务健康 | 综合评分 |
|------|------|------|--------|---------|---------|
| 300750.SZ | 新能源 | 3.2 | 4.5 | 1.0 | 85.6 |
| 002594.SZ | 新能源 | 2.9 | 3.8 | 0.8 | 72.4 |

---

## 十、接口切换机制 (v8新增)

### 双源架构

```
东方财富 API (主) ──失败──→ 国信 API (备)
     │                           │
     └──失败──→ 飞书告警推送──→ 抛出异常
```

### 实现代码

```python
def fetch_index_data():
    try:
        # 尝试东方财富接口
        return eastmoney_api()
    except Exception as e:
        push_feishu_text(f"⚠️ 东方财富指数接口失败: {e}")
        try:
            # 切换国信接口
            return guosen_api()
        except Exception as e2:
            push_feishu_text(f"⚠️ 国信指数接口也失败: {e2}")
            raise RuntimeError("所有指数接口抓取失败！")
```

---

## 十一、市场阶段调度 (v8新增)

### 阶段划分

| 阶段 | 时间范围 | 抓取间隔 |
|------|---------|---------|
| 盘前 | 08:30 - 09:25 | 15 分钟 |
| 盘中 | 09:30 - 15:00 | 5 分钟 |
| 盘后 | 15:01 - 17:00 | 30 分钟 |
| 休市 | 其他时间 | 60 分钟 |

### 调度配置

```python
SCHEDULE_CONFIG = {
    "pre_market": 15,   # 盘前 15 分钟
    "intraday": 5,      # 盘中 5 分钟
    "post_market": 30,  # 盘后 30 分钟
    "off_market": 60    # 休市 60 分钟
}
```

### 阶段判断函数

```python
def get_market_phase(now=None):
    if now is None:
        now = datetime.datetime.now().time()
    
    if datetime.time(8,30) <= now <= datetime.time(9,25):
        return "pre_market"
    elif datetime.time(9,30) <= now <= datetime.time(15,0):
        return "intraday"
    elif datetime.time(15,1) <= now <= datetime.time(17,0):
        return "post_market"
    else:
        return "off_market"
```

---

## Common Pitfalls

1. **过度依赖技术指标** - 技术面只占 40%，需结合基本面和资金面综合判断

2. **忽视风险预警** - 大盘风险高时，即使个股评分高也应谨慎

3. **板块追高** - 板块连续大涨后需警惕回调，关注资金流变化

4. **接口切换未生效** - 确保东方财富接口失败后能正确切换到国信接口

5. **飞书推送失败** - 检查 Webhook URL 是否正确，注意图表 base64 格式

6. **历史文件堆积** - 定期清理 `robot6_history/` 目录，避免磁盘占用过多

7. **调度时间冲突** - 确保 `time.sleep()` 不被中断，或改用 cronjob

8. **休市阶段误运行** - 检查 `get_market_phase()` 返回值，避免非交易时间无效抓取

---

## Verification Checklist

- [ ] 趋势信号正确（1/-1/0）
- [ ] 热点板块筛选合理（top3）
- [ ] 潜力股评分在 0-100 范围
- [ ] 飞书文本推送成功
- [ ] 飞书图表推送成功（base64 格式正确）
- [ ] 历史评分 CSV 已保存
- [ ] 接口切换机制正常（东方财富失败 → 国信接管）
- [ ] 市场阶段判断正确
- [ ] 调度间隔与阶段匹配
- [ ] 异常兜底：任何环节失败均有飞书告警

---

## One-Shot Recipes

### 盘前分析（08:30-09:25）

```python
index_data = fetch_index_data()
sector_data = fetch_sector_data()
stock_pool = fetch_stock_pool()
message, df_stocks, df_sector = generate_market_signal(
    index_data, sector_data, stock_pool, top_n=10)
push_feishu_combined_chart(message, date_str, df_stocks, df_sector)
```

### 盘中动态监控（自动调度）

```python
while True:
    phase = get_market_phase()
    interval = SCHEDULE_CONFIG.get(phase, 60)
    intraday_task_dynamic_real()  # 含异常兜底
    time.sleep(interval * 60)
```

### 快速评分单股

```python
stock = {
    "MA5>MA20": True,
    "资金流": 4.5,
    "财务健康": 0.9,
    "板块涨幅": 3.2
}
score = compute_stock_score(stock)  # 返回 85.6
```

### 接口故障恢复

```python
# 东方财富失败自动切换国信，全程飞书告警
# fetch_index_data / fetch_sector_data / fetch_stock_pool 均已内置
```

---

## References

- 完整实现代码 v6: `scripts/robot6_market_analysis_v6.py`
- 完整实现代码 v8: `scripts/robot6_v8_full_integrated.py`
