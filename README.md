# 🖥 DisplayWindowMover (monmove)

macOSにおいて、特定モニター上にあるすべてのアプリケーションウィンドウを別のモニターへ一括移動・相互入れ替えするためのユーティリティツールです。  
メニューバーに常駐する **GUIアプリ** と、ターミナルから操作できる **CLIツール (`monmove`)** の両方を備えています。

---

## ⭐️ 特長

- **ワンクリック移動 / 相互入れ替え**: 特定のモニターのウィンドウを別モニターへ一括移動、または2つのモニター間で相互入れ替え可能。
- **メインモニターの切り替え**: 接続されている任意のモニターをワンクリック（またはCLIコマンド）で macOS の「主ディスプレイ（メインモニター）」に切替可能。
- **メニューバー常駐**: メニューバーにシンプルなアイコンを表示。作業を邪魔せずいつでも即座にアクセスできます。
- **ライト/ダークモード対応**: macOS のシステムテーマに合わせてアイコンカラーが自動適応。
- **マルチモニター最適化**: 異なる解像度やアスペクト比のモニター間でもウィンドウが画面外へはみ出さない安全設計。
- **CLI 対応 (`monmove`)**: ターミナルコマンドやスクリプト、自動化ワークフローからもウィンドウ操作が可能。

---

## 📋 動作要件

- **OS**: macOS 12.0 (Monterey) 以降
- **権限**: **アクセシビリティ権限 (Accessibility Permission)**
  ※ 他アプリケーションのウィンドウを操作するため、初回起動時にシステム設定での許可が必要です。

---

## 📦 インストール方法

リポジトリ直下にある `install_app.sh` を実行すると、ビルドと `/Applications` への配置が自動で行われます。

```bash
cd ~/wk/DisplayWindowMover
./install_app.sh
```

### 1. メニューバーアプリの起動
Finder や Launchpad の「アプリケーション」フォルダから **DisplayWindowMover** を起動してください。  
またはターミナルから以下を実行します:

```bash
open /Applications/DisplayWindowMover.app
```

### 2. CLI ツール (`monmove`) のインストール (任意)
ターミナル上のどこからでも `monmove` コマンドを実行したい場合は、以下を実行して `/usr/local/bin` へコピーします:

```bash
sudo cp ~/wk/DisplayWindowMover/.build/release/monmove /usr/local/bin/monmove
```

---

## 🚀 使い方

### 1. メニューバーアプリ (GUI)
メニューバーに表示される画面アイコン (`🖥`) をクリックするとメニューが開きます。

- **モニター 0 / モニター 1 のウィンドウ数**: 各モニター上の現在のウィンドウ数を表示
- **➡️ Display 0 の画面を全部 Display 1 へ移動**: 対象モニターの画面を一括移動
- **🔄 Display 0 と Display 1 の画面を相互入れ替え**: 画面配置の相互スワップ
- **🚀 全モニターの画面を Display X へ集約**: すべてのウィンドウを指定モニターへ集中配置

---

### 2. コマンドラインツール (`monmove`)

#### モニター一覧とウィンドウ配置の確認
```bash
monmove list
```
*出力例:*
```text
🖥  接続されているモニター一覧 (2 台):
--------------------------------------------------
  [Display 0] 'ZOWIE XL LCD' (1920x1080) - ウィンドウ数: 0 件
  [Display 1] 'LG HDR WQHD' (3440x1440) - ウィンドウ数: 6 件
       - [Google Chrome] "YouTube - Google Chrome"
       - [Finder] "デスクトップ"
```

#### ウィンドウ移動・入れ替え
```bash
# Display 1 の全ウィンドウを Display 0 へ移動
monmove move 1 0

# Display 0 と Display 1 のウィンドウを相互入れ替え
monmove swap 0 1

# すべてのモニターのウィンドウを Display 0 に集約
monmove move-all 0

# Display 1 をメインモニターに設定
monmove set-primary 1

# アクセシビリティ権限のチェックおよび設定の要求
monmove check-permission
```

---

## 🛠 プロジェクト構造

```text
DisplayWindowMover/
├── Package.swift               # Swift Package マニフェスト
├── Sources/
│   ├── DisplayManager.swift    # コアロジック (AXUIElement / NSScreen 座標変換)
│   ├── MenuBarApp.swift        # メニューバー常駐 GUI アプリ
│   └── main.swift              # CLI エントリーポイント
├── build_app.sh                # ビルド & .app バンドル生成スクリプト
└── install_app.sh              # /Applications への自動配置スクリプト
```
