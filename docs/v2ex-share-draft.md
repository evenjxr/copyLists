# V2EX「分享创造」发帖草稿（可自行改）

> 发在 <https://www.v2ex.com/go/create> → 节点选 **分享创造**。  
> 配图建议：主界面一张、预览浮窗一张、设置/隐私一张。

---

## 标题（任选或自拟）

- 开源 · 个人/非商业免费 · macOS 剪贴板历史 CopyLists（预览 / OCR / 隐私暂停）
- 写了个 macOS 剪贴板工具，带图片 OCR 和 Snipaste 式预览，开源了

---

## 正文（复制后改链接与版本号）

大家好，

最近把自用的 **macOS 剪贴板历史** 整理开源了，名字叫 **CopyLists**，**个人与非商业使用免费**、不接广告，方便在国内先找一波真实用户验证。（商业使用需邮件联系授权，见仓库 `LICENSE`。）

**它能干啥（一句话）**  
记录复制历史，按快捷键呼出，回车粘贴；支持图片缩略图、**图片内文字搜索（本地 OCR）**、**收藏永久保留**、以及类似 Snipaste 的 **`⌘P` 预览浮窗**（文字可改、图片可简单标注后写回剪贴板）。

**为什么敢用（信任）**  
- 代码开源，可自行编译。  
- **不上传、不账号**：数据在本地 `Application Support`。  
- **可暂停记录**，并可 **按 Bundle ID 排除 App**（默认带常见密码管理器）。

**怎么装**  
- 优先从 **GitHub Releases** 下 DMG：  
  https://github.com/evenjxr/copyLists/releases/latest  
- 若仓库根目录暂无 Release，可先 clone 后 `bash build_app.sh`。  
- 未做 Apple 公证的包，**首次可能需要右键 → 打开**；辅助功能权限用于模拟粘贴，README 里写了步骤。

**仓库**  
https://github.com/evenjxr/copyLists  

欢迎试用、提 Issue（装不上、想要的功能都行）。如果对你有用，帮忙点个 Star 扩散一下，感谢。

---

## 评论里可备用回复

- **和 Paste 比？** 更偏自用场景：预览浮窗 + OCR 搜索 + 收藏不淘汰 + 排除 App，功能取舍不同。  
- **会收费吗？** 个人与非商业免费用；商业嵌入/分发需联系授权（见 `LICENSE` 邮箱）。  
- **国内 clone 慢？** 可自行镜像到 Gitee，或只下 Release 的 DMG。
