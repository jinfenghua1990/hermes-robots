# Hermes Robot角色定义

## 功能介绍

### 核心定位
**Hermes多智能体系统的5个Robot角色定义**，每个Robot有独立职责和权限。

### 角色架构
```
┌─────────────────────────────────────────────────┐
│              Hermes集群                         │
├─────────────────────────────────────────────────┤
│  Robot-1 攻城师 → 唯一修改权限              │
│  Robot-2 市场热点 → 板块轮动分析            │
│  Robot-3 持仓管理 → 持仓监控与止盈止损      │
│  Robot-4 超短线 → 短线交易信号               │
│  Robot-5 四维分析 → 个股综合分析            │
└─────────────────────────────────────────────────┘
```

### 各Robot职责

| Robot | 名称 | 职责 | 权限 |
|-------|------|------|------|
| **Robot-1** | 攻城师 | 系统维护、代码修改、版本发布 | 唯一写权限 |
| **Robot-2** | 市场热点 | 板块轮动监控、资金流向分析 | 只读权限 |
| **Robot-3** | 持仓管理 | 持仓监控、止盈止损提醒 | 只读权限 |
| **Robot-4** | 超短线 | 短线交易信号、龙头股筛选 | 只读权限 |
| **Robot-5** | 四维分析 | 个股四维评级、综合分析 | 只读权限 |

### 部署架构
- 每个Robot独立目录: `~/.hermes-robot-1`、`~/.hermes-robot-2` 等
- 共享配置: `~/.hermes/shared-roles/robots-manifest.md`
- 信号汇总: Robot-1收集所有Robot输出推送给用户

## 版本历史

- **v1.0.0** - 初始版本

## 安装使用

### 下载
```bash
# 从GitHub下载
git clone https://github.com/jinfenghua1990/hermes-robots.git

# 或从Gitee下载（国内更快）
git clone https://gitee.com/ginohei/hermes-robots.git
```

### 安装依赖
见各系统内的 INSTALL.md

### 发版本
```bash
./release.sh v1.1.0 "更新说明"
```

## 下载地址

- **GitHub**: https://github.com/jinfenghua1990/hermes-robots/releases
- **Gitee** (推荐): https://gitee.com/ginohei/hermes-robots/releases

## 其他说明

本系统是股票分析系统的一部分，其他6个相关系统：
- 板块轮动预警: https://gitee.com/ginohei/sector-rotation-alert
- 超短线交易: https://gitee.com/ginohei/ultrashort-trading
- 四维分析: https://gitee.com/ginohei/stock-4d-analysis
- 信号汇总: https://gitee.com/ginohei/trading-signal-hub
- 持仓管理: https://gitee.com/ginohei/position-monitor
- Hermes Robots: https://gitee.com/ginohei/hermes-robots
- 妙想Skills: https://gitee.com/ginohei/mx-skills-kit
