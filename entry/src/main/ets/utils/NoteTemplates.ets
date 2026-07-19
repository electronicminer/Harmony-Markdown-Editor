/**
 * 校园专用笔记模板库
 * 每个模板为 markdown 骨架,含标准结构 + 占位提示,一键生成标准化课堂笔记。
 * 排版:emoji 分节 + 引用块元信息 + 分隔线分区 + 表格数据。
 */

export interface NoteTemplate {
  id: string;
  name: string;
  icon: string;
  description: string;
  content: string;
}

const classNote: NoteTemplate = {
  id: 'class',
  name: '课堂笔记',
  icon: '📝',
  description: '康奈尔笔记法:要点/记录/总结/复习',
  content: `# 📚 课堂笔记 · [课程名]

> 📅 **日期** YYYY/MM/DD 　👤 **讲师** 　📍 **地点**
> 📖 **章节主题**

---

## 📌 核心要点
-

## 📝 课堂记录
-

## 💡 总结与思考
-

## 🔖 待办与复习
- [ ]
- [ ]
`
};

const labReport: NoteTemplate = {
  id: 'lab',
  name: '实验报告',
  icon: '🔬',
  description: '目的/原理/步骤/数据/结论',
  content: `# 🔬 实验报告 · [实验名称]

> 📅 **日期** YYYY/MM/DD 　📘 **课程** 　👨‍🏫 **指导教师**
> 👥 **合作者**

---

## 🎯 实验目的
-

## 📖 实验原理
-

## 🧪 实验器材
-

## 📋 实验步骤
1.
2.
3.

## 📊 数据记录
| 次数 | 测量值 | 单位 | 备注 |
|---|---|---|---|
| 1 |  |  |  |
| 2 |  |  |  |
| 3 |  |  |  |

## 📈 数据处理与结果
-

## ✅ 结论
-

## ⚠️ 误差分析
-
`
};

const readingNote: NoteTemplate = {
  id: 'reading',
  name: '读书笔记',
  icon: '📖',
  description: '书目/摘要/摘录/感悟',
  content: `# 📖 读书笔记 · 《[书名]》

> ✍️ **作者** 　📅 **阅读日期** YYYY/MM/DD
> 🏷️ **类别** 　⭐ **评分** ⭐⭐⭐⭐⭐

---

## 📝 内容摘要
-

## ✍️ 摘录与批注
>

## 💡 核心观点
1.
2.
3.

## 🤔 读后感悟
-
`
};

const reviewOutline: NoteTemplate = {
  id: 'review',
  name: '复习提纲',
  icon: '📋',
  description: '知识点/重点/易错/真题',
  content: `# 📋 复习提纲 · [科目 / 章节]

> 📅 **考试日期** YYYY/MM/DD 　⏳ **剩余** X 天

---

## ✅ 知识点清单
- [ ]
- [ ]

## ⭐ 重点难点
-

## 📐 公式速记
-

## ⚠️ 易错点
-

## 📝 真题练习
1.
2.

## 🔖 待巩固
- [ ]
`
};

const discussionNote: NoteTemplate = {
  id: 'discussion',
  name: '小组讨论',
  icon: '💬',
  description: '议题/观点/决议/分工',
  content: `# 💬 小组讨论记录 · [议题]

> 📅 **日期** YYYY/MM/DD 　✍️ **记录人**
> 👥 **参与人**
> 🔜 **下次会议** YYYY/MM/DD

---

## 📌 议题背景
-

## 🗣️ 讨论观点
- **同学 A**:
- **同学 B**:
- **同学 C**:

## ⚖️ 分歧与共识
-

## ✅ 决议
1.
2.

## 🔧 待办分工
- [ ] 同学 A:
- [ ] 同学 B:
- [ ] 同学 C:
`
};

const studyPlan: NoteTemplate = {
  id: 'plan',
  name: '学习计划',
  icon: '📅',
  description: '目标/周计划/打卡',
  content: `# 📅 学习计划 · [目标]

> 🚩 **总目标**
> 📅 **起止** YYYY/MM/DD — YYYY/MM/DD

---

## 🎯 阶段目标
- **第一阶段**:
- **第二阶段**:
- **第三阶段**:

## 📆 每周计划
| 周 | 任务 | 状态 |
|---|---|---|
| 1 |  | ⬜ |
| 2 |  | ⬜ |
| 3 |  | ⬜ |

## ✅ 每日打卡
- [ ] 周一 　- [ ] 周二 　- [ ] 周三
- [ ] 周四 　- [ ] 周五 　- [ ] 周六
- [ ] 周日

## 🔄 复盘与调整
-
`
};

const speechOutline: NoteTemplate = {
  id: 'speech',
  name: '答辩提纲',
  icon: '🎤',
  description: '主题/结构/要点/Q&A',
  content: `# 🎤 演讲提纲 · [主题]

> 🏛️ **场合** 　⏱️ **时长** X 分钟 　📅 **日期** YYYY/MM/DD
> 👥 **听众**

---

## 🎬 开场
- **引子**:
- **主题引入**:

## 📑 主体结构
### 一、
-

### 二、
-

### 三、
-

## 💡 论据 / 案例
1.
2.

## 🎯 总结
- **升华**:
- **行动号召**:

## ❓ Q&A 预判
- **Q**:
  **A**:
`
};

const formulaNote: NoteTemplate = {
  id: 'formula',
  name: '公式笔记',
  icon: '🧮',
  description: '概念/公式(LaTeX)/例题/易错',
  content: `# 🧮 公式笔记 · [章节]

> 📅 **日期** YYYY/MM/DD 　📘 **科目**

---

## 📖 关键概念
-

## 📐 重要公式
**行内示例**:$E = mc^2$

**块级示例**:
$$\\int_a^b f(x)\\,dx = F(b) - F(a)$$

## 🎯 适用条件
-

## ✏️ 典型例题
1. **题目**:
   **解**:

## ⚠️ 易错点
-
`
};

export const NOTE_TEMPLATES: NoteTemplate[] = [
  classNote,
  labReport,
  readingNote,
  reviewOutline,
  discussionNote,
  studyPlan,
  speechOutline,
  formulaNote
];
