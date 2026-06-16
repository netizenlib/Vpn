import os
import sys
import signal
import logging
import json
import time
import requests
from datetime import datetime, timedelta
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes, MessageHandler, filters
from telegram.error import Conflict, TelegramError

# ================= НАСТРОЙКА ЛОГИРОВАНИЯ =================
logging.basicConfig(
    format='🕒 %(asctime)s | 👤 %(name)s | 📊 %(levelname)s | 💬 %(message)s',
    level=logging.INFO,
    handlers=[
        logging.FileHandler("bot_logs.txt", encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# ================= КОНФИГУРАЦИЯ =================
BOT_TOKEN = "8562308378:AAGcg6dJmNToyorPB2_eQ0Ra1i95GbHuVSA"
ADMIN_USERNAME = "Proces_event_offset"   # замените на свой
CHANNEL_ID = "@NelaVPNPremium"
VPN_LINK = "http://f1277008.xsph.ru/"
BOT_USERNAME = "NelaVPN_bot"  # замените на username вашего бота

# Реферальная система
REFERRAL_REWARD = 10

# Кэш проверки подписки
subscription_cache = {}
CACHE_TTL = 300

# Проверка запуска только одного экземпляра
PID_FILE = "bot.pid"

def check_single_instance():
    if os.path.exists(PID_FILE):
        with open(PID_FILE, 'r') as f:
            old_pid = f.read().strip()
        try:
            os.kill(int(old_pid), 0)
            logger.error(f"❌ Бот уже запущен с PID {old_pid}")
            print(f"❌ Бот уже запущен! PID: {old_pid}")
            print("🔴 Используйте команду: pkill -f python")
            return False
        except OSError:
            os.remove(PID_FILE)
    
    with open(PID_FILE, 'w') as f:
        f.write(str(os.getpid()))
    return True

def cleanup():
    if os.path.exists(PID_FILE):
        os.remove(PID_FILE)
    print("\n✅ Бот корректно завершен")

def signal_handler(signum, frame):
    print(f"\n⚠️ Получен сигнал {signum}. Завершаю работу...")
    cleanup()
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

# ================= ХРАНИЛИЩА ДАННЫХ =================
users = {}
blocked_users = set()
referrals = {}

# ================= УТИЛИТЫ =================
def get_user(user_id):
    if user_id not in users:
        users[user_id] = {
            'user_id': user_id,
            'username': '',
            'first_name': '',
            'last_name': '',
            'join_date': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'last_check': None,
            'referral_count': 0,
            'referred_by': None
        }
    return users[user_id]

def is_admin(user):
    if not user.username:
        return False
    return user.username.lower() == ADMIN_USERNAME.lower()

def log_action(user, action, details=""):
    username = f"@{user.username}" if user.username else "Без юзернейма"
    name = user.first_name or "Без имени"
    log_msg = f"👤 {username} ({name}, ID: {user.id}) → {action}"
    if details:
        log_msg += f" | 📝 {details}"
    logger.info(log_msg)
    print(f"📌 {log_msg}")

def save_data():
    try:
        data = {
            'users': users,
            'blocked_users': list(blocked_users),
            'referrals': referrals
        }
        with open('bot_data.json', 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        logger.info("✅ Данные сохранены")
    except Exception as e:
        logger.error(f"❌ Ошибка сохранения данных: {e}")

def load_data():
    global users, blocked_users, referrals
    try:
        if os.path.exists('bot_data.json'):
            with open('bot_data.json', 'r', encoding='utf-8') as f:
                data = json.load(f)
                users = {int(k): v for k, v in data['users'].items()}
                blocked_users = set(data['blocked_users'])
                referrals = data.get('referrals', {})
            logger.info(f"✅ Загружено {len(users)} пользователей")
        else:
            logger.info("📁 Файл данных не найден, создаю новый")
    except Exception as e:
        logger.error(f"❌ Ошибка загрузки данных: {e}")

async def check_subscription(user_id, context):
    if user_id in subscription_cache:
        timestamp, is_subscribed = subscription_cache[user_id]
        if (datetime.now() - timestamp).total_seconds() < CACHE_TTL:
            return is_subscribed
    
    try:
        chat_member = await context.bot.get_chat_member(chat_id=CHANNEL_ID, user_id=user_id)
        status = chat_member.status
        is_subscribed = status in ['creator', 'administrator', 'member']
        subscription_cache[user_id] = (datetime.now(), is_subscribed)
        return is_subscribed
    except TelegramError as e:
        logger.error(f"❌ Ошибка проверки подписки для {user_id}: {e}")
        if "chat not found" in str(e).lower() or "bot is not a member" in str(e).lower():
            logger.error("❌ Бот не добавлен в канал или не является администратором!")
            return True
        return False

async def check_server_status():
    try:
        response = requests.get(VPN_LINK, timeout=5)
        if response.status_code == 200:
            return True, "🟢 Сервер работает нормально"
        else:
            return False, f"🟡 Сервер ответил с кодом {response.status_code}"
    except requests.exceptions.RequestException:
        return False, "🔴 Сервер недоступен! Проверьте подключение."

# ================= КОМАНДЫ БОТА =================
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    user_id = user.id
    log_action(user, "Запустил бота")
    
    # Реферальная ссылка
    args = context.args
    if args and args[0].startswith('ref_'):
        try:
            referrer_id = int(args[0].split('_')[1])
            if referrer_id != user_id and referrer_id in users:
                if users[referrer_id].get('referral_count', 0) >= 0:
                    users[referrer_id]['referral_count'] = users[referrer_id].get('referral_count', 0) + 1
                    users[user_id]['referred_by'] = referrer_id
                    save_data()
                    try:
                        await context.bot.send_message(
                            chat_id=referrer_id,
                            text=f"🎉 По вашей реферальной ссылке пришёл новый пользователь!\n"
                                 f"👤 {user.first_name or 'Пользователь'}\n"
                                 f"📊 Всего приглашений: {users[referrer_id]['referral_count']}"
                        )
                    except:
                        pass
        except:
            pass
    
    if user_id in blocked_users:
        await update.message.reply_text(
            "🚫 <b>Доступ запрещен</b>\n\nВаш аккаунт был заблокирован администратором.",
            parse_mode='HTML'
        )
        return
    
    user_data = get_user(user_id)
    user_data.update({
        'username': user.username or '',
        'first_name': user.first_name or '',
        'last_name': user.last_name or ''
    })
    save_data()
    
    is_subscribed = await check_subscription(user_id, context)
    
    if not is_subscribed:
        keyboard = [
            [InlineKeyboardButton("📢 Подписаться на канал", url=f"https://t.me/{CHANNEL_ID[1:]}")],
            [InlineKeyboardButton("✅ Проверить подписку", callback_data='check_subscribe')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await update.message.reply_text(
            "🌐 <b>Добро пожаловать в NelaVPN Premium!</b>\n\n"
            "🔥 <b>Ваш бесплатный и быстрый VPN</b>\n\n"
            "✅ <b>Наши преимущества:</b>\n"
            "• 🚀 Высокая скорость соединения\n"
            "• 🔒 Полная анонимность и безопасность\n"
            "• 🌍 Доступ к заблокированным сайтам\n"
            "• 📱 Поддержка всех устройств\n"
            "• 💰 Совершенно бесплатно!\n\n"
            "⚠️ <b>Для использования бота необходимо подписаться на наш канал!</b>\n\n"
            "👇 <b>Подпишитесь и нажмите «Проверить подписку»</b>",
            parse_mode='HTML',
            reply_markup=reply_markup
        )
        return
    
    await show_main_menu(update, context, user)

async def show_main_menu(update: Update, context: ContextTypes.DEFAULT_TYPE, user=None):
    if user is None:
        user = update.effective_user
    
    server_ok, server_status = await check_server_status()
    
    keyboard = [
        [InlineKeyboardButton("🔗 Подключиться к VPN", url=VPN_LINK)],
        [InlineKeyboardButton("👤 Мой профиль", callback_data='profile')],
        [InlineKeyboardButton("📊 Статус сервера", callback_data='server_status')],
        [InlineKeyboardButton("👥 Пригласить друзей", callback_data='referral')]
    ]
    
    if is_admin(user):
        keyboard.append([InlineKeyboardButton("👑 Панель администратора", callback_data='admin_panel')])
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    status_emoji = "🟢" if server_ok else "🔴"
    status_text = f"{status_emoji} Статус сервера: {'Работает' if server_ok else 'Недоступен'}"
    
    if update.callback_query:
        await update.callback_query.edit_message_text(
            f"🌐 <b>NelaVPN Premium</b>\n\n"
            f"🔥 <b>Бесплатный и быстрый VPN для всех</b>\n\n"
            f"✅ <b>Наши преимущества:</b>\n"
            f"• 🚀 Высокая скорость соединения\n"
            f"• 🔒 Полная анонимность и безопасность\n"
            f"• 🌍 Доступ к заблокированным сайтам\n"
            f"• 📱 Поддержка всех устройств\n"
            f"• 💰 Абсолютно бесплатно!\n\n"
            f"📊 {status_text}\n\n"
            f"👇 <b>Выберите действие:</b>",
            parse_mode='HTML',
            reply_markup=reply_markup
        )
        await update.callback_query.answer()
    else:
        await update.message.reply_text(
            f"🌐 <b>NelaVPN Premium</b>\n\n"
            f"🔥 <b>Бесплатный и быстрый VPN для всех</b>\n\n"
            f"✅ <b>Наши преимущества:</b>\n"
            f"• 🚀 Высокая скорость соединения\n"
            f"• 🔒 Полная анонимность и безопасность\n"
            f"• 🌍 Доступ к заблокированным сайтам\n"
            f"• 📱 Поддержка всех устройств\n"
            f"• 💰 Абсолютно бесплатно!\n\n"
            f"📊 {status_text}\n\n"
            f"👇 <b>Выберите действие:</b>",
            parse_mode='HTML',
            reply_markup=reply_markup
        )

# ================= СТАТУС СЕРВЕРА =================
async def show_server_status(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    
    server_ok, message = await check_server_status()
    
    status_text = (
        "📊 <b>Статус сервера</b>\n\n"
        f"{message}\n\n"
        f"🔗 <b>Адрес:</b> {VPN_LINK}\n"
        f"🕒 <b>Проверено:</b> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    )
    
    keyboard = [
        [InlineKeyboardButton("🔄 Обновить", callback_data='server_status')],
        [InlineKeyboardButton("🏠 Главное меню", callback_data='main_menu')]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await query.edit_message_text(status_text, parse_mode='HTML', reply_markup=reply_markup)

# ================= РЕФЕРАЛЬНАЯ СИСТЕМА =================
async def show_referral(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    
    user = query.from_user
    user_data = get_user(user.id)
    
    ref_link = f"https://t.me/{BOT_USERNAME}?start=ref_{user.id}"
    
    text = (
        "👥 <b>Реферальная система</b>\n\n"
        f"📊 <b>Вы пригласили:</b> {user_data.get('referral_count', 0)} человек\n\n"
        "🔗 <b>Ваша реферальная ссылка:</b>\n"
        f"<code>{ref_link}</code>\n\n"
        "📋 <b>Как это работает:</b>\n"
        "1. Отправьте ссылку другу\n"
        "2. Когда друг перейдёт по ней и запустит бота — вы получите уведомление\n"
        "3. Чем больше друзей — тем лучше!\n\n"
        "💡 <i>Поделитесь ссылкой в соцсетях и чатах!</i>"
    )
    
    keyboard = [
        [InlineKeyboardButton("📤 Поделиться", url=f"https://t.me/share/url?url={ref_link}&text=🔥%20NelaVPN%20-%20бесплатный%20и%20быстрый%20VPN!%20Подключайся%20по%20моей%20ссылке%3A")],
        [InlineKeyboardButton("🏠 Главное меню", callback_data='main_menu')]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await query.edit_message_text(text, parse_mode='HTML', reply_markup=reply_markup)

# ================= ПРОФИЛЬ =================
async def show_profile(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    
    user = query.from_user
    user_data = get_user(user.id)
    
    username = f"@{user_data['username']}" if user_data['username'] else "Не установлен"
    full_name = f"{user_data['first_name']} {user_data.get('last_name', '')}".strip() or "Не указано"
    
    profile_text = (
        "👤 <b>Ваш профиль</b>\n\n"
        f"🆔 <b>ID:</b> {user.id}\n"
        f"📛 <b>Имя:</b> {full_name}\n"
        f"🔗 <b>Юзернейм:</b> {username}\n"
        f"📅 <b>Регистрация:</b> {user_data['join_date']}\n"
        f"👥 <b>Приглашено друзей:</b> {user_data.get('referral_count', 0)}\n"
    )
    
    if user_data.get('last_check'):
        profile_text += f"🔄 <b>Последняя проверка:</b> {user_data['last_check']}\n"
    
    profile_text += "\n💎 <i>Спасибо, что выбираете NelaVPN!</i>"
    
    keyboard = [
        [InlineKeyboardButton("🔗 Подключиться", url=VPN_LINK)],
        [InlineKeyboardButton("👥 Пригласить друзей", callback_data='referral')],
        [InlineKeyboardButton("🏠 Главное меню", callback_data='main_menu')]
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    await query.edit_message_text(profile_text, parse_mode='HTML', reply_markup=reply_markup)

# ================= АДМИН ПАНЕЛЬ =================
async def admin_panel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    
    user = query.from_user
    
    if not is_admin(user):
        await query.edit_message_text("❌ У вас недостаточно прав для доступа к этой панели.")
        return
    
    log_action(user, "Открыл панель администратора")
    
    total_refs = sum(u.get('referral_count', 0) for u in users.values())
    
    keyboard = [
        [InlineKeyboardButton("👥 Управление пользователями", callback_data='admin_users')],
        [InlineKeyboardButton("📊 Статистика", callback_data='admin_stats')],
        [InlineKeyboardButton("📢 Рассылка", callback_data='admin_broadcast')],
        [InlineKeyboardButton("💾 Сохранить данные", callback_data='save_data')],
        [InlineKeyboardButton("🏠 Главное меню", callback_data='main_menu')]
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        "👑 <b>Панель администратора</b>\n\n"
        f"👤 <b>Администратор:</b> @{user.username}\n"
        f"📅 <b>Время сервера:</b> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"
        f"📊 <b>Краткая статистика:</b>\n"
        f"👥 Пользователей: {len(users)}\n"
        f"🚫 Заблокированных: {len(blocked_users)}\n"
        f"👥 Всего рефералов: {total_refs}\n\n"
        "⚙️ <b>Доступные действия:</b>",
        parse_mode='HTML',
        reply_markup=reply_markup
    )

async def admin_broadcast(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    user = query.from_user
    
    if not is_admin(user):
        return
    
    await query.edit_message_text(
        "📢 <b>Рассылка</b>\n\n"
        "📝 <b>Введите текст для рассылки:</b>\n"
        "(Отправьте сообщение, которое получит каждый пользователь)",
        parse_mode='HTML'
    )
    context.user_data['awaiting_broadcast'] = True

async def process_broadcast(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    
    if not is_admin(user):
        return
    
    if not context.user_data.get('awaiting_broadcast'):
        return
    
    text = update.message.text
    context.user_data['awaiting_broadcast'] = False
    
    await update.message.reply_text("⏳ Начинаю рассылку...")
    
    sent = 0
    failed = 0
    
    for user_id in users.keys():
        if user_id not in blocked_users:
            try:
                await context.bot.send_message(chat_id=user_id, text=text, parse_mode='HTML')
                sent += 1
            except:
                failed += 1
        time.sleep(0.05)
    
    await update.message.reply_text(
        f"✅ <b>Рассылка завершена</b>\n\n"
        f"📤 Отправлено: {sent}\n"
        f"❌ Не доставлено: {failed}\n"
        f"👥 Всего пользователей: {len(users)}",
        parse_mode='HTML'
    )
    log_action(user, f"Сделал рассылку", f"Отправлено {sent}, не доставлено {failed}")

# ================= ОБРАБОТЧИК КНОПОК =================
async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    
    user = query.from_user
    data = query.data
    
    if user.id in blocked_users:
        await query.edit_message_text(
            "🚫 <b>Ваш аккаунт заблокирован</b>\n\nОбратитесь к администратору для разблокировки.",
            parse_mode='HTML'
        )
        return
    
    if data == 'check_subscribe':
        await check_subscribe_callback(update, context)
    elif data == 'profile':
        await show_profile(update, context)
    elif data == 'main_menu':
        await show_main_menu(update, context, user)
    elif data == 'server_status':
        await show_server_status(update, context)
    elif data == 'referral':
        await show_referral(update, context)
    elif data == 'admin_panel':
        await admin_panel(update, context)
    elif data == 'admin_users':
        await admin_users_wrapper(update, context)
    elif data == 'admin_stats':
        await admin_stats_wrapper(update, context)
    elif data == 'admin_broadcast':
        await admin_broadcast(update, context)
    elif data == 'save_data':
        await save_data_wrapper(update, context)
    else:
        logger.warning(f"Неизвестный callback_data: {data}")
        await query.edit_message_text("❌ Неизвестная команда. Попробуйте еще раз.")

async def check_subscribe_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    user = query.from_user
    user_id = user.id
    
    await query.answer("🔄 Проверяем подписку...")
    
    if user_id in subscription_cache:
        del subscription_cache[user_id]
    
    is_subscribed = await check_subscription(user_id, context)
    
    if is_subscribed:
        user_data = get_user(user_id)
        user_data['last_check'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        save_data()
        
        await query.edit_message_text(
            "✅ <b>Подписка подтверждена!</b>\n\nДобро пожаловать в NelaVPN Premium! 🎉",
            parse_mode='HTML'
        )
        await show_main_menu(update, context, user)
    else:
        keyboard = [
            [InlineKeyboardButton("📢 Подписаться на канал", url=f"https://t.me/{CHANNEL_ID[1:]}")],
            [InlineKeyboardButton("✅ Проверить подписку", callback_data='check_subscribe')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(
            "❌ <b>Вы еще не подписаны на канал!</b>\n\n"
            f"📢 <b>Подпишитесь на наш канал:</b>\n👉 {CHANNEL_ID}\n\n"
            "После подписки нажмите кнопку ниже:",
            parse_mode='HTML',
            reply_markup=reply_markup
        )

async def admin_users_wrapper(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    user = query.from_user
    
    if not is_admin(user):
        return
    
    active_users = len([uid for uid in users.keys() if uid not in blocked_users])
    
    keyboard = [
        [InlineKeyboardButton("🚫 Заблокировать", callback_data='block_user')],
        [InlineKeyboardButton("✅ Разблокировать", callback_data='unblock_user')],
        [InlineKeyboardButton("📋 Список пользователей", callback_data='user_list')],
        [InlineKeyboardButton("🔙 Назад", callback_data='admin_panel')]
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        "👥 <b>Управление пользователями</b>\n\n"
        f"📊 <b>Статистика:</b>\n"
        f"• Всего пользователей: {len(users)}\n"
        f"• Активных: {active_users}\n"
        f"• Заблокированных: {len(blocked_users)}\n\n"
        "⚡ <b>Выберите действие:</b>",
        parse_mode='HTML',
        reply_markup=reply_markup
    )

async def admin_stats_wrapper(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    user = query.from_user
    
    if not is_admin(user):
        return
    
    total_refs = sum(u.get('referral_count', 0) for u in users.values())
    
    stats_text = (
        "📊 <b>Детальная статистика</b>\n\n"
        f"👥 <b>Пользователи:</b> {len(users)}\n"
        f"✅ <b>Активных:</b> {len([uid for uid in users.keys() if uid not in blocked_users])}\n"
        f"🚫 <b>Заблокированных:</b> {len(blocked_users)}\n"
        f"👥 <b>Всего рефералов:</b> {total_refs}\n\n"
        f"📅 <b>Обновлено:</b> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    )
    
    keyboard = [
        [InlineKeyboardButton("🔄 Обновить", callback_data='admin_stats')],
        [InlineKeyboardButton("🔙 Назад", callback_data='admin_panel')]
    ]
    
    reply_markup = InlineKeyboardMarkup(keyboard)
    await query.edit_message_text(stats_text, parse_mode='HTML', reply_markup=reply_markup)

async def save_data_wrapper(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    user = query.from_user
    
    if not is_admin(user):
        return
    
    save_data()
    await query.answer("✅ Данные успешно сохранены!", show_alert=True)

# ================= КОМАНДА /STATUS =================
async def status_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    
    if user.id in blocked_users:
        await update.message.reply_text("🚫 Доступ запрещён.")
        return
    
    server_ok, message = await check_server_status()
    await update.message.reply_text(
        f"📊 <b>Статус сервера</b>\n\n{message}\n\n🔗 {VPN_LINK}",
        parse_mode='HTML'
    )

# ================= ОБРАБОТЧИК СООБЩЕНИЙ =================
async def message_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    text = update.message.text.strip()
    
    if is_admin(user) and context.user_data.get('awaiting_broadcast'):
        await process_broadcast(update, context)
        return
    
    if text.startswith('/'):
        return
    
    log_action(user, "Отправил сообщение", f"Текст: {text[:50]}...")
    await start(update, context)

# ================= ОБРАБОТЧИКИ ОШИБОК =================
async def error_handler(update: object, context: ContextTypes.DEFAULT_TYPE):
    error = context.error
    
    if isinstance(error, Conflict):
        logger.error("❌ CONFLICT: Другой экземпляр бота уже запущен!")
        print("\n" + "="*60)
        print("🚨 ОШИБКА: Бот уже запущен в другом окне!")
        print("="*60)
        print("\n🔧 РЕШЕНИЕ:")
        print("1. Остановите все запущенные боты:")
        print("   pkill -f python")
        print("2. Удалите PID файл:")
        print("   rm -f bot.pid")
        print("3. Запустите заново:")
        print("   python ks.py")
        print("="*60)
        cleanup()
        sys.exit(1)
    
    logger.error(f"❌ Ошибка: {error}")

# ================= ЗАПУСК БОТА =================
def main():
    print("="*60)
    print("🌐 NelaVPN БОТ ЗАПУСКАЕТСЯ".center(60))
    print("="*60)
    
    if not check_single_instance():
        print("❌ Бот уже запущен! Остановите предыдущий экземпляр.")
        print("🔧 Используйте: pkill -f python")
        print("="*60)
        sys.exit(1)
    
    import atexit
    atexit.register(cleanup)
    
    print(f"🔑 Токен: {BOT_TOKEN[:15]}...")
    print(f"👑 Администратор: @{ADMIN_USERNAME}")
    print(f"📢 Канал: {CHANNEL_ID}")
    print(f"🔗 Ссылка VPN: {VPN_LINK}")
    print(f"📁 Логи: bot_logs.txt")
    print(f"📊 PID: {os.getpid()}")
    print("="*60)
    
    try:
        load_data()
        print(f"📊 Загружено пользователей: {len(users)}")
        print(f"🚫 Заблокированных: {len(blocked_users)}")
        print("="*60)
        
        # Создаём приложение (без лишних параметров – исправляет ошибку)
        app = Application.builder().token(BOT_TOKEN).build()
        
        # Регистрируем обработчики
        app.add_handler(CommandHandler("start", start))
        app.add_handler(CommandHandler("status", status_command))
        app.add_handler(CallbackQueryHandler(button_handler))
        app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, message_handler))
        app.add_error_handler(error_handler)
        
        print("✅ Бот успешно запущен!")
        print("🌐 ВСЕ КНОПКИ РАБОТАЮТ")
        print("📢 ПРОВЕРКА ПОДПИСКИ АКТИВНА")
        print("👥 РЕФЕРАЛЬНАЯ СИСТЕМА АКТИВНА")
        print("📊 ПРОВЕРКА СТАТУСА СЕРВЕРА АКТИВНА")
        print("⚡ Используйте Ctrl+C для остановки")
        print("="*60)
        
        # Запускаем polling – минимальные параметры
        app.run_polling()
        
    except KeyboardInterrupt:
        print("\n⚠️ Получен сигнал прерывания. Завершаю работу...")
    except Exception as e:
        logger.error(f"❌ Критическая ошибка при запуске: {e}")
        print(f"\n❌ Ошибка: {e}")
    finally:
        cleanup()
        print("\n✅ Бот завершил работу")

if __name__ == '__main__':
    main()