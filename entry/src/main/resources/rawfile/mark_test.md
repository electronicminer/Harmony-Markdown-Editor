# Markdown 全语法测试文档

## 1. 标题 (Headers)

# 一级标题 (H1)

## 二级标题 (H2)

### 三级标题 (H3)

#### 四级标题 (H4)

##### 五级标题 (H5)

###### 六级标题 (H6)

---

## 2. 文本样式 (Text Styling)

**粗体文本 (Bold)** 或 __粗体文本__
*斜体文本 (Italic)* 或 _斜体文本_
***粗斜体文本 (Bold Italic)***
~~删除线文本 (Strikethrough)~~
==高亮文本 (Highlight)== (需扩展支持)
X^2^ (上标)
H~2~O (下标)

---

## 3. 列表 (Lists)

### 无序列表

- 项目 1
- 项目 2
  - 子项目 2.1
  - 子项目 2.2
    - 子子项目 2.2.1

### 有序列表

1. 第一步
2. 第二步
3. 第三步
   1. 子步骤 3.1
   2. 子步骤 3.2

### 任务列表 (Task Lists)

- [X] 已完成任务
- [ ] 未完成任务
- [ ] 正在进行的任务

---

## 4. 链接与图片 (Links & Images)

[百度一下](https://www.baidu.com)
[带标题的链接](https://www.google.com "Google")

**请求的图片展示：**

![1000157461.jpg](http://lsky.nchm.asia/i/2025/11/11/6912edae1e716.jpg)

---

## 5. 引用 (Blockquotes)

> 这是一个引用块。
>
>> 这是一个嵌套引用块。
>>
>>> 三级嵌套引用。
>>>
>>

---

## 6. 代码 (Code)

### 代码块

```python
def add(a, b):
    return a + b
```

```cpp
//冒泡排序
#include <iostream>

void bubbleSort(int arr[], int n) {
    for (int i = 0; i < n - 1; i++) {
        // 每次循环将最大的元素"冒泡"到末尾
        for (int j = 0; j < n - i - 1; j++) {
            // 比较相邻元素，如果顺序错误则交换
            if (arr[j] > arr[j + 1]) {
                // 交换元素
                int temp = arr[j];
                arr[j] = arr[j + 1];
                arr[j + 1] = temp;
            }
        }
    }
}

```

---

## 7. 表格 (Tables)

| 左对齐   | 居中对齐 |   右对齐 |
| :------- | :------: | -------: |
| 单元格 1 | 单元格 2 | 单元格 3 |
| Left     |  Center  |    Right |

---

## 8. 数学公式 (Math Formulas)

### 行内公式

质能方程 $E = mc^2$

### 块级公式

$$
x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}
$$

---

## 9. 分割线 (Horizontal Rules)

---

## 10. HTML 标签支持

`<u>`带下划线的文本 `</u>`
`<kbd>`Ctrl `</kbd>` + `<kbd>`C `</kbd>`

<center>居中对齐的文本</center>

## 11. 脚注 (Footnotes)

这是一个脚注引用[^1]。

[^1]: 这是脚注的说明内容。
