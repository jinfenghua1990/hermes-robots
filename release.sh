#!/bin/bash
# 自动发布脚本 - 放到每个仓库中
# 使用: ./release.sh v1.1.0 "更新说明"

set -e

REPO_NAME=$(basename $(git rev-parse --show-toplevel))
VERSION=${1:-"v1.0.0"}
NOTES=${2:-"版本 $VERSION 发布"}

echo "=== 发布 $VERSION ==="

# 提交代码
git add . 2>/dev/null || true
git commit -m "$NOTES" 2>/dev/null || echo "无新变更"

# 推送到GitHub
git push github main
git tag -d $VERSION 2>/dev/null || true
git tag -a $VERSION -m "$NOTES"
git push github $VERSION --force

# 创建GitHub Release
gh release create $VERSION --title "$VERSION" --notes "$NOTES" || true

# 推送到Gitee
git push gitee main
git push gitee $VERSION --force

echo ""
echo "=== 发布成功 ==="
echo "GitHub: https://github.com/jinfenghua1990/$REPO_NAME/releases/tag/$VERSION"
echo "Gitee:  https://gitee.com/ginohei/$REPO_NAME/releases/tag/$VERSION"
