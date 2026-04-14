# nftables-geo-builder

這是一個使用 Flutter 製作的單頁應用程式，用來產生 Linux `nftables` 的國家 IP 白名單部署腳本。

使用者可以透過介面設定：

- 目標國家 IP 白名單：`tw`、`jp`、`us`
- 管理員固定 IP 白名單
- 是否允許 SSH
- 是否允許 HTTP / HTTPS
- 是否開放所有 Port
- 自訂開放通訊埠
- HTTP/HTTPS、自訂 Port、全開 Port 的協定選擇（TCP / UDP / both）

系統會即時產生一段可直接部署到 Linux 伺服器的 Bash 腳本。

## 專案功能

產生的腳本會自動完成以下工作：

- 關閉舊版防火牆服務 `firewalld` 與 `ufw`
- 從 `IPdeny` 下載指定國家的 IPv4 CIDR 清單
- 生成 `/etc/nftables/country_ips.nft`
- 生成 `/etc/nftables.conf`
- 註冊每日更新國家 IP 清單的排程
- 啟用 `nftables`

## 技術棧

- Flutter
- Dart 3
- Material 3
- 支援 Web 與 Desktop 的專案結構

## 本機啟動方式

1. 安裝 Flutter SDK
2. 開啟本專案資料夾
3. 執行：

```bash
flutter pub get
flutter run -d chrome
```

如果你的環境沒有把 Flutter 加進 PATH，也可以直接指定 SDK 路徑，例如：

```powershell
C:\Users\User\Documents\flutter_sdk_plain\bin\flutter.bat run -d chrome
```

## 腳本運作流程

產生的腳本會依照以下順序執行：

1. 關閉舊的防火牆服務
2. 從 `https://www.ipdeny.com/ipblocks/data/countries/<country>.zone` 下載指定國家的 IPv4 CIDR 清單
3. 轉換成 `nftables` 的 `allow_ips` 集合
4. 套用只允許國家白名單與可選管理員固定 IP 的規則
5. 註冊每日排程，定期更新國家 IP 清單

## GitHub Pages

本專案包含 GitHub Pages 自動部署 workflow：

- push 到 `main` 後，GitHub Actions 會自動 build Flutter Web
- 使用官方 Pages workflow 自動部署站點

預設站點網址：

- `https://sos19941015.github.io/nftables-geo-builder/`

## 重要注意事項

- 國家 IP 白名單屬於 geoblocking 輔助方案，不能視為百分之百精準的地理位置判定。
- VPN、Proxy、雲端服務商出口 IP、跨境 ISP 都可能影響封鎖結果。
- 如果沒有設定管理員固定 IP，部署後有可能把自己鎖在 SSH 外面。
- SSH 正常情況下通常只需要 TCP，不建議不必要地開放 UDP。
- `nftables` 的 `set allow_ips` 必須在正確的 table scope 中載入，因此目前產生的腳本已將 `include "/etc/nftables/country_ips.nft"` 放在 `table inet filter { ... }` 內。

## 驗證方式

目前開發過程中使用過的檢查方式：

- `flutter analyze`
- `flutter test`

## 授權

目前尚未加入 License。
