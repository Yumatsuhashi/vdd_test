# Answers — 解答 config キャッシュ

`original/*.html` から抽出・検証済みの解答 config を問題単位でキャッシュする。
ccie-qa スキルが回答時に自動生成・参照する（運用ルールの正本は `.claude/skills/ccie-qa/SKILL.md`）。

## ルール

- 命名: `Answers/patternN/patternN_qX.md`（`Questions/` の命名をミラー）。パターン・問題番号が特定できないものは `Answers/general/<概要>.md`
- `QA/`（追記専用の Q&A ログ）と異なり、**キャッシュなので上書き更新可**
- **正本はあくまで `original/*.html`**。キャッシュと original が矛盾した場合は original を再確認し、このディレクトリ側を修正する
- 各ファイルには出典（original/ のファイル名・該当セクション、EI_v2.yaml の該当ノード等）を必ず残す
