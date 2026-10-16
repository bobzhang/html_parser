# Native 产物体积优化

2026-10-16，以 `26e3be9480d90571906689d9c9a7a18bc96d06f2` 为基线，在 macOS arm64 上使用同一套工具链和入口对比。本次基线是 parser 当前 HEAD，区别于最初比较的 Mooncakes 0.2.0 发布版。

工具链：`moon 0.1.20261012 (748b63c)`、`moonc v0.10.15+943464bfa`、Apple clang 21.0.0。两个版本均使用 `--target native --release`，由该工具链以 `cc -O2` 编译。`strip` 数据来自对可执行文件副本执行相同的 `strip -o OUTPUT INPUT`。

## 体积结果

| 产物 | 基线 / 字节 | 优化后 / 字节 | 减少 |
| --- | ---: | ---: | ---: |
| html2md 最小转换程序，release | 2,209,120 | 1,371,808 | 817.7 KiB / 37.9% |
| 同一转换程序，额外 strip | 1,662,696 | 1,141,608 | 508.9 KiB / 31.3% |
| parser 完整 `cmd/justhtml`，release | 2,928,576 | 2,304,432 | 609.5 KiB / 21.3% |
| 同一 CLI，额外 strip | 2,234,104 | 1,927,768 | 299.2 KiB / 13.7% |

转换程序使用 html2md `a00a27c`，通过 `moon.work` 分别选择基线 parser 和当前源码；代码从命令行读取 HTML，调用 `html2md.convert` 并输出结果。两个入口、消费者代码和构建参数相同。不同消费者会保留不同的依赖代码，因此最终增量取决于调用的 API、平台和工具链。

## 实现

- 将 2,125 个带分号实体和 106 个无分号实体的巨大 `StringView match` 合并为紧凑的只读字节表，共 26,715 字节：记录 22,345 字节、偏移索引 4,252 字节、首字符边界索引 118 字节。偏移的最高位标记无分号实体，无运行时哈希表初始化。
- 保留常见实体的常量字符串快速路径；其他名称在首字符范围内二分查找。实体值保留完整 Unicode，支持多码点和非 BMP 字符。
- 无分号实体的最长前缀查找只尝试至多六个字符；生成器和全量映射测试同时验证这个上界。
- 错误码分类改为只读表，SVG 名称调整共享二分查找，84 个特殊标签共享一份表，并简化外来属性名的恒等映射。
- 可读的完整实体映射保存在 `scripts/generate_named_entities.mbtx`，生成 `internal/tokenizer/named_entities_data.mbt`。测试另存原始映射，对全部值和无分号标记逐项检查，并覆盖未知名称、大小写、前缀及切片输入。

更新实体映射后，在仓库根目录运行：

```sh
moon run --target native scripts/generate_named_entities.mbtx
moonfmt -w internal/tokenizer/named_entities_data.mbt
moon run --target native scripts/generate_named_entities.mbtx --check
```

生成校验已加入 `scripts/check_ci.mbtx`。生成器的 `--check` 忽略格式化空白，比较完整生成内容。

## 正确性与接口

- `moon check --target all --deny-warn` 通过。
- `moon test --target all --release`：wasm、wasm-gc、js、native 各 953 项测试全部通过，包括 50,000 层嵌套回归测试。
- HTML5 tree-construction：1791/1791 通过，0 失败，4 个依赖脚本执行的用例按原有规则跳过。
- `moon info` 完成，没有公共 `.mbti` 变化；API 和完整实体集合保持不变。
- 原有总 CI 脚本的运行在当前机器上被 `moonbitlang/x@0.4.43` 的旧 `moon.mod.json` 格式阻塞；未修改的基线也复现相同错误。实体生成器校验已单独运行通过，测试清单计数独立核对为 953。

## 查询性能

为优先缩小体积，罕见实体使用紧凑表查找并按需解码 UTF-8，替代原来的常量字符串分支。因此罕见实体存在查询时间和分配的取舍；常见实体保留快速路径。以下微基准取三轮基线/优化交替运行的均值中位数，测量时没有同时运行测试或构建。它衡量实体解码，不代表整份 HTML 的转换耗时。

| 工作负载 | 基线 / µs | 优化后 / µs | 时间变化 |
| --- | ---: | ---: | ---: |
| 10 个常见实体 | 0.6413 | 0.6251 | -2.5% |
| 5 个罕见实体 | 0.4403 | 0.6865 | +55.9% |
| 未知名称与长前缀 | 0.8591 | 1.0204 | +18.8% |
| 无实体 Unicode 文本 | 0.06912 | 0.06907 | -0.1% |

常见实体和无实体文本接近原速；不将几个百分点的变化解释为普遍性能提升。罕见实体示例是 `&NotEqualTilde; &Gopf; &CounterClockwiseContourIntegral; &zwnj; &fjlig;`，五个实体合计增加约 0.25 µs。本次按体积优先选择此取舍。

工作负载分别包括常见实体、五个罕见实体、未知名称及长前缀、无实体 Unicode 文本。测试入口和原始 JSON 记录保留在本次临时分析目录 `/tmp/html-parser-size-ZCDxja`。
