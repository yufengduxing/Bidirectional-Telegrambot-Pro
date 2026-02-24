# Bidirectional-Telegrambot

## 轻量双向机器人

### 机场推荐：
- 曙光云：https://dawnscloud.com
- 超实惠：https://cshjc.net

##

### VPS推荐：
- OCI：https://oci.ee

## 

- TG群组：https://t.me/yufeng_duxing
- 定制联系：https://t.me/martsccbot
- 博客：https://yufengduxing.xyz/
- Github：https://github.com/yufengduxing

##

## 宝塔部署步骤

### 前提条件
- 宝塔面板已安装 **Supervisor** 插件（软件商店搜索安装）
- 服务器已安装 Python 3.8+

---

### 步骤一：安装宝塔（这一步骤不会安装就放弃吧）

---

### 步骤二：CF里DNS解析IP，关闭小云朵

---

### 步骤三：宝塔-网站-添加站点-不创建数据库-选择PHP

---

### 步骤四：进入跟根目录删除里面所有文件

---

### 步骤五：上传文件

将整个 `Bidirectional-Telegrambot` 文件夹上传到服务器任意目录，例如 `/www/wwwroot/根目录`

---

### 步骤六：SSH 执行安装

```bash
cd /www/wwwroot/Bidirectional-Telegrambot（Bidirectional-Telegrambot替换成自己的根目录）

bash install.sh

```

脚本会引导你输入：
1. Bot Token（从 @BotFather 获取）
2. 管理员 Telegram 数字 ID（从 @userinfobot 获取）

---

### 菜单：
```bash
/www/wwwroot/根目录/install.sh
```

---
