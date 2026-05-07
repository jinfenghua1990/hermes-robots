"""
Robot-6 市场分析脚本 v6
======================
核心功能：趋势分析 + 板块轮动 + 潜力股评分 + 飞书推送 + 动态调度

维护者：Robot-6
版本：v6.0
更新日期：2026-05-07
"""

import pandas as pd
import datetime
import numpy as np
import requests
import json
import time

# -----------------------------
# 飞书 Webhook 配置
# -----------------------------
FEISHU_WEBHOOK = "https://open.feishu.cn/open-apis/bot/v2/hook/你的WebhookKey"


def push_to_feishu(message):
    """推送消息到飞书群"""
    headers = {"Content-Type": "application/json"}
    data = {"msg_type": "text", "content": {"text": message}}
    try:
        r = requests.post(FEISHU_WEBHOOK, headers=headers, data=json.dumps(data))
        if r.status_code == 200:
            print("飞书推送成功")
        else:
            print(f"飞书推送失败: {r.text}")
    except Exception as e:
        print(f"飞书推送异常: {e}")


# -----------------------------
# 数据抓取
# -----------------------------
def fetch_index_data(source="eastmoney"):
    """
    获取大盘指数数据
    - date: 日期
    - open/high/low/close: OHLC
    - volume: 成交量
    - turnover: 成交额
    """
    # TODO: 替换为实际 API 调用（mx-data skill）
    df = pd.DataFrame({
        'date': pd.date_range(end=datetime.date.today(), periods=60),
        'open': np.random.rand(60) * 100,
        'high': np.random.rand(60) * 100,
        'low': np.random.rand(60) * 100,
        'close': np.random.rand(60) * 100,
        'volume': np.random.rand(60) * 1e7,
        'turnover': np.random.rand(60) * 1e8
    })
    return df


def fetch_sector_data(source="eastmoney"):
    """
    获取板块资金流数据
    返回: {板块名: {"资金流": float, "板块涨幅": float}}
    """
    # TODO: 替换为实际 API 调用（mx-data skill）
    sectors = ["新能源", "半导体", "医药"]
    data = {}
    for s in sectors:
        data[s] = {"资金流": np.random.rand() * 5, "板块涨幅": np.random.rand() * 3}
    return data


def fetch_stock_pool(source="eastmoney"):
    """
    获取板块内个股数据
    返回: {板块名: {股票代码: {指标...}}}
    """
    # TODO: 替换为实际 API 调用（mx-xuangu skill）
    return {
        "新能源": {
            "300750.SZ": {"涨幅": 3.2, "资金流": 4.5, "MA5>MA20": True,
                          "机构持仓占比": 15.2, "龙虎榜买入额": 1.2e7, "财务健康": 1},
            "002594.SZ": {"涨幅": 2.9, "资金流": 3.8, "MA5>MA20": True,
                          "机构持仓占比": 10.5, "龙虎榜买入额": 5.1e6, "财务健康": 0.8}
        },
        "半导体": {
            "688126.SH": {"涨幅": 1.8, "资金流": 2.1, "MA5>MA20": True,
                          "机构持仓占比": 12.0, "龙虎榜买入额": 8e6, "财务健康": 0.9},
            "603986.SH": {"涨幅": 1.5, "资金流": 1.9, "MA5>MA20": True,
                          "机构持仓占比": 10.0, "龙虎榜买入额": 5e6, "财务健康": 0.7}
        },
        "医药": {
            "600276.SH": {"涨幅": 1.2, "资金流": 1.5, "MA5>MA20": True,
                          "机构持仓占比": 9.0, "龙虎榜买入额": 2e6, "财务健康": 0.85},
            "000538.SZ": {"涨幅": 1.0, "资金流": 1.2, "MA5>MA20": True,
                          "机构持仓占比": 8.5, "龙虎榜买入额": 1.5e6, "财务健康": 0.8}
        }
    }


# -----------------------------
# 核心分析与评分
# -----------------------------
def trend_analysis(df, short=5, long=20):
    """
    趋势分析：基于均线系统判断趋势方向

    参数:
        df: DataFrame, 包含 'close' 列
        short: 短期均线周期（默认 5 日）
        long: 长期均线周期（默认 20 日）

    返回:
        1  = 上升趋势（MA_short > MA_long）
        -1 = 下降趋势（MA_short < MA_long）
        0  = 无数据或震荡
    """
    df['ma_short'] = df['close'].rolling(short).mean()
    df['ma_long'] = df['close'].rolling(long).mean()
    df['trend_signal'] = 0
    df.loc[df['ma_short'] > df['ma_long'], 'trend_signal'] = 1
    df.loc[df['ma_short'] < df['ma_long'], 'trend_signal'] = -1
    return df['trend_signal'].iloc[-1]


def risk_warning(index_data):
    """
    大盘风险预警

    触发条件:
    - 连续 3 日累计跌幅 > 3% → 短期大盘下跌风险高
    - 否则 → 风险可控
    """
    if index_data['close'].pct_change().tail(3).sum() < -0.03:
        return "短期大盘下跌风险高"
    return "风险可控"


def compute_stock_score(stock):
    """
    四维评分模型

    综合评分 = 技术(40%) + 资金(30%) + 基本面(20%) + 风格(10%)

    参数:
        stock: dict, 包含以下键:
            - MA5>MA20: bool, 技术面信号
            - 资金流: float, 主力资金流（归一化前）
            - 财务健康: float, 0-1 财务健康度
            - 板块涨幅: float, 板块涨幅百分比

    返回:
        float, 0-100 综合评分
    """
    tech = 1 if stock.get("MA5>MA20", True) else 0
    fund = stock.get("资金流", 0) / 5
    basic = stock.get("财务健康", 0)
    style = min(stock.get("板块涨幅", 0) / 5, 1)

    score = tech * 0.4 + fund * 0.3 + basic * 0.2 + style * 0.1
    return round(score * 100, 2)


def generate_market_signal(index_data, sector_data, stock_pool, top_n=5):
    """
    生成完整的市场信号报告

    流程:
    1. 趋势分析
    2. 热点板块筛选（按资金流 top3）
    3. 个股评分排序
    4. 组装飞书推送消息
    """
    # Step 1: 趋势分析
    trend = trend_analysis(index_data)

    # Step 2: 按资金流选出 top 3 热点板块
    sorted_sectors = sorted(sector_data.items(),
                            key=lambda x: x[1]['资金流'],
                            reverse=True)
    top_sectors = [s[0] for s in sorted_sectors[:3]]

    # Step 3: 评分排序
    scored_stocks = []
    for sector in top_sectors:
        if sector in stock_pool:
            for code, s in stock_pool[sector].items():
                s["板块涨幅"] = sector_data[sector]["板块涨幅"]
                s["板块"] = sector
                score = compute_stock_score(s)
                s["综合评分"] = score
                scored_stocks.append((score, code, s))

    scored_stocks.sort(key=lambda x: x[0], reverse=True)
    top_stocks = scored_stocks[:top_n]

    # Step 4: 组装消息
    message = f"趋势信号: {trend}\n"
    message += f"热点板块(top3): {top_sectors}\n"
    message += "高分个股推荐:\n"
    for score, code, s in top_stocks:
        message += (f"{code} | 板块: {s['板块']} | 涨幅: {s['涨幅']} | "
                    f"资金流: {s['资金流']} | 财务: {s['财务健康']} | "
                    f"综合评分: {score}\n")
    message += f"风险提示: {risk_warning(index_data)}"

    return message


# -----------------------------
# 动态盘中任务
# -----------------------------
def intraday_task_dynamic():
    """
    盘中动态分析任务
    根据市场波动自动调整下次抓取间隔
    """
    index_data = fetch_index_data(source="guosen")
    sector_data = fetch_sector_data(source="guosen")
    stock_pool = fetch_stock_pool(source="guosen")

    message = generate_market_signal(index_data, sector_data, stock_pool, top_n=5)
    push_to_feishu(message)

    # 动态间隔调整
    max_flow = max([v["资金流"] for v in sector_data.values()])
    if max_flow > 4:
        interval = 3   # 高波动 -> 3 分钟
    elif max_flow > 2:
        interval = 5   # 中波动 -> 5 分钟
    else:
        interval = 10  # 低波动 -> 10 分钟

    print(f"下次抓取间隔: {interval} 分钟")
    return interval


# -----------------------------
# 调度时间表
# -----------------------------
# 盘前 08:50
# schedule.every().weekday.at("08:50").do(lambda: intraday_task_dynamic())
# 盘中循环抓取，可改为守护线程执行动态间隔
# 盘后 15:10
# schedule.every().weekday.at("15:10").do(lambda: intraday_task_dynamic())
