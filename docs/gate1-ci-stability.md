# Gate1 云 Runner CI 稳定性修复规范

> **范围**：适用于 HomeOps 仓库在云端（Gate1）Runner 上执行的 `make setup → make lint → make test` 金路径检查。本规范仅描述待解决的问题与机判验收要求，具体实现方案由执行者自定。

## 背景

- HomeOps 在 PR 合并前必须通过 Gate1（金路径基础检查）与 Gate2（真实硬件集成验收）。
- 近期 Gate1 在云 Runner 上频繁失败，导致 PR 长期阻塞或需要大量人工干预。
- 目标是恢复 Gate1 的可重复性与机器可判验，通过后再进入 Gate2 阶段。

## 已观测到的问题

1. **依赖/环境安装失败**
   - `make setup` 在云 Runner 上经常因为 PEP 668（externally-managed environment）或缺失写权限而无法创建/更新虚拟环境。
   - ansible-lint / yamllint 在执行时会扫描系统级或 Runner 预装的 `site-packages`，触发与 HomeOps 无关的报错。
2. **Makefile 与目标不稳定**
   - `make lint` / `make test` 偶发出现 “missing separator” 或目标缺失，通常来自 Makefile 缩进或条件判断在不同 shell 上行为不一致。
3. **Lint 范围不受控**
   - ansible-lint、yamllint 会尝试检查 Runner 上的第三方插件或 `.venv` 中的集合，导致非仓库代码的警告/错误。
   - 在外部插件文件上出现大量样式错误（行宽、缩进、truthy 值等），扰乱真正需要修复的问题。
4. **职责与文档不清晰**
   - Gate1 与 Gate2 的职责边界模糊，`make itest` 未在文档中明确引用 `docs/verification-spec.md` 作为唯一机判标准。
   - AGENTS.md / 文档的指引存在描述不一致，导致自动化代理无法确认权威规范。
5. **缺乏受限环境的降级策略**
   - 当云 Runner 无法安装系统级依赖时，CI 直接失败，没有可回退或隔离的替代路径。

## 交付要求（实现者需满足）

1. **Gate1 必须稳定通过**
   - 在云 Runner 上连续执行 `make setup`、`make lint`、`make test` 均返回 exit code 0。
   - 所有 lint/test 行为应限制在仓库源码（`playbooks/`、`inventory/`、`roles/` 等），不应扫描 Runner 的全局/虚拟环境目录。
2. **日志可机判**
   - `make setup` 日志需显示所使用的虚拟环境路径与关键版本（至少包含 ansible、ansible-lint、yamllint）。
   - `make lint` 日志仅可出现仓库代码的警告或错误，若有忽略规则需明确记录。
   - `make test` 应输出自检 playbook 成功执行的证据，并产出 `artifacts/test/`（或在日志中呈现等价信息）。
3. **环境隔离或降级策略**
   - 提供在受限云 Runner 环境下可执行的安装/配置方案；若需要额外集合或依赖，必须在仓库可控路径内完成并可清理。
   - 禁止要求对 Runner 进行全局管理员级修改，除非先行获得批准。
4. **文档一致性**
   - 若对 AGENTS.md 或 `docs/verification-spec.md` 有调整，需确保 `make itest` 与 Gate2 相关描述引用同一权威文档。
5. **可追溯的交付物**
   - 提交/PR 必须附带：
     - Commit 或 PR 链接；
     - Gate1 执行日志或 Actions 链接（覆盖 `make setup`、`make lint`、`make test`）；
     - “Testing Done” 摘要（格式如下）。

### Testing Done 摘要格式

- make setup: `<一句话，显示 venv 路径 & ansible version>`（或明确说明失败原因）
- make lint: `<一句话，说明 lint 是否通过 & 列出 1–3 条关键警告（如有）>`
- make test: `<一句话，说明自检 playbook 是否成功 & 报告位置（artifacts/test/ 或日志链接）>`

## 非目标

- 本规范不提供具体实现步骤、脚本或代码示例。
- 不要求修改 Gate2（自托管 Runner）的现有流程，但 Gate1 的修复不得破坏 Gate2 的后续执行。
- 不涉及对仓库外部系统的永久性修改（例如云 Runner 全局依赖安装）。

## 验收标准

完成修复后，应能通过以下机判要求：

1. 云 Runner 上 `make setup`、`make lint`、`make test` 均成功且日志符合上文约束。
2. CI 日志不再出现 `Error loading plugin 'community.general.yaml'`、`Could not load 'yaml' callback plugin` 或同类插件加载错误。
3. Gate1 与 Gate2 的职责在 AGENTS.md 与相关文档中描述一致，`make itest` 明确引用 `docs/verification-spec.md` 为权威验收依据。
4. PR 或提交包含完整的“Testing Done” 摘要与日志证明，供 Reviewer/CI 复查。

