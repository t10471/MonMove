#!/usr/bin/env zsh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "========================================================"
echo "🖥  DisplayWindowMover - インストールスクリプト"
echo "========================================================"

# 1. ビルド & アプリバンドル生成
echo "\n📦 アプリケーションをビルド中..."
./build_app.sh

APP_NAME="DisplayWindowMover.app"
SOURCE_APP="${DIR}/${APP_NAME}"
TARGET_DIR="/Applications"
TARGET_APP="${TARGET_DIR}/${APP_NAME}"

# 2. /Applications ディレクトリへの配置
echo "\n🚀 ${TARGET_DIR} へ ${APP_NAME} を配置します..."

if [ -d "${TARGET_APP}" ]; then
    echo "ℹ️  既存の ${TARGET_APP} を更新します..."
    rm -rf "${TARGET_APP}"
fi

if [ -w "${TARGET_DIR}" ]; then
    cp -R "${SOURCE_APP}" "${TARGET_APP}"
else
    echo "🔒 /Applications への書き込みに sudo 権限が必要です..."
    sudo cp -R "${SOURCE_APP}" "${TARGET_APP}"
fi

echo "✅ ${TARGET_APP} に正常に配置されました！"

# 3. CLI バイナリの配置
CLI_SOURCE="${DIR}/.build/release/monmove"

if [ -d "$HOME/.homebrew/bin" ] && [ -w "$HOME/.homebrew/bin" ]; then
    cp "${CLI_SOURCE}" "$HOME/.homebrew/bin/monmove"
    echo "✅ CLI ツール 'monmove' を $HOME/.homebrew/bin/monmove に配置しました。"
elif [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
    cp "${CLI_SOURCE}" "/usr/local/bin/monmove"
    echo "✅ CLI ツール 'monmove' を /usr/local/bin/monmove に配置しました。"
else
    echo "💡 コマンドラインから 'monmove' を使えるようにするには、以下を実行してください:"
    echo "   sudo cp ${CLI_SOURCE} /usr/local/bin/monmove"
fi

echo "\n========================================================"
echo "🎉 インストールが完了しました！"
echo "========================================================"
echo "・ Launchpad または Finder の「アプリケーション」フォルダから"
echo "  「DisplayWindowMover」を起動できます。"
echo "・ コマンドで直接起動する場合:"
echo "  open /Applications/DisplayWindowMover.app"
echo "========================================================"
