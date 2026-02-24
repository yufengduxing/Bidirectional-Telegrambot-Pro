#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import logging
import re
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes
import config

logging.basicConfig(
    format='%(asctime)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    handlers=[
        logging.FileHandler('tg_bot.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("👋 欢迎！\n\n直接发送消息给我")

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("💬 发送任何消息，我会转发给主人")


def get_user_id_from_reply(reply_msg):
    """从消息 text 或 caption 里提取用户ID"""
    text = reply_msg.text or reply_msg.caption or ""
    match = re.search(r'\((\d+)\)', text)
    return int(match.group(1)) if match else None


async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    msg = update.message

    logger.info(f"用户 {user.id} 发来消息")

    # ===== 管理员回复用户 =====
    if user.id == config.ADMIN_ID:
        if msg.reply_to_message:
            target_user_id = get_user_id_from_reply(msg.reply_to_message)
            if target_user_id:
                try:
                    if msg.text:
                        await context.bot.send_message(chat_id=target_user_id, text=msg.text)
                    elif msg.photo:
                        await context.bot.send_photo(chat_id=target_user_id, photo=msg.photo[-1].file_id, caption=msg.caption or "")
                    elif msg.sticker:
                        await context.bot.send_sticker(chat_id=target_user_id, sticker=msg.sticker.file_id)
                    elif msg.video:
                        await context.bot.send_video(chat_id=target_user_id, video=msg.video.file_id, caption=msg.caption or "")
                    elif msg.voice:
                        await context.bot.send_voice(chat_id=target_user_id, voice=msg.voice.file_id)
                    elif msg.audio:
                        await context.bot.send_audio(chat_id=target_user_id, audio=msg.audio.file_id, caption=msg.caption or "")
                    elif msg.document:
                        await context.bot.send_document(chat_id=target_user_id, document=msg.document.file_id, caption=msg.caption or "")
                    elif msg.video_note:
                        await context.bot.send_video_note(chat_id=target_user_id, video_note=msg.video_note.file_id)
                    await msg.reply_text("✅ 已回复")
                    logger.info(f"回复给用户 {target_user_id}")
                except Exception as e:
                    logger.error(f"发送失败: {e}")
                    await msg.reply_text(f"❌ 发送失败: {e}")
            else:
                await msg.reply_text("❌ 找不到用户ID，请确认是回复转发过来的消息")
        return

    # ===== 普通用户消息：转发给管理员 =====
    header = f"转发自 {user.first_name} ({user.id})\n"
    try:
        if msg.text:
            await context.bot.send_message(chat_id=config.ADMIN_ID, text=header + msg.text)
        elif msg.photo:
            await context.bot.send_photo(chat_id=config.ADMIN_ID, photo=msg.photo[-1].file_id,
                                          caption=header + (msg.caption or ""))
        elif msg.sticker:
            await context.bot.send_sticker(chat_id=config.ADMIN_ID, sticker=msg.sticker.file_id)
            await context.bot.send_message(chat_id=config.ADMIN_ID, text=header.strip())
        elif msg.video:
            await context.bot.send_video(chat_id=config.ADMIN_ID, video=msg.video.file_id,
                                          caption=header + (msg.caption or ""))
        elif msg.voice:
            await context.bot.send_voice(chat_id=config.ADMIN_ID, voice=msg.voice.file_id,
                                          caption=header.strip())
        elif msg.audio:
            await context.bot.send_audio(chat_id=config.ADMIN_ID, audio=msg.audio.file_id,
                                          caption=header + (msg.caption or ""))
        elif msg.document:
            await context.bot.send_document(chat_id=config.ADMIN_ID, document=msg.document.file_id,
                                             caption=header + (msg.caption or ""))
        elif msg.video_note:
            await context.bot.send_video_note(chat_id=config.ADMIN_ID, video_note=msg.video_note.file_id)
            await context.bot.send_message(chat_id=config.ADMIN_ID, text=header.strip())
        else:
            await context.bot.send_message(chat_id=config.ADMIN_ID, text=header + "发来了一条不支持的消息类型")
    except Exception as e:
        logger.error(f"转发失败: {e}")


async def error_handler(update, context):
    logger.error(f"异常: {context.error}")


def main():
    app = Application.builder().token(config.BOT_TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("help", help_command))
    app.add_handler(MessageHandler(
        (filters.TEXT | filters.PHOTO | filters.Sticker.ALL | filters.VIDEO |
         filters.VOICE | filters.AUDIO | filters.Document.ALL | filters.VIDEO_NOTE)
        & ~filters.COMMAND,
        handle_message
    ))
    app.add_error_handler(error_handler)
    logger.info("🤖 机器人启动...")
    app.run_polling(drop_pending_updates=True)

if __name__ == '__main__':
    main()
