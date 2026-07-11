<div align="center">
  <img src="Preview.png" alt="PGClock Preview" width="900">
</div>

<h1 align="center">PGClock</h1>

<p align="center">
  نسخهٔ استاندارد — قالب شیشه‌ای صفحهٔ اشتراک برای Pasarguard
</p>

<p align="center">
  <a href="#نصب-خودکار">نصب خودکار</a> ·
  <a href="#نصب-دستی">نصب دستی</a> ·
  <a href="#تنظیمات-پنل">تنظیمات پنل</a> ·
  <a href="#نسخه‌های-دیگر">نسخه‌های دیگر</a>
</p>

---

## ویژگی‌ها

- رابط شیشه‌ای برای موبایل، تبلت و دسکتاپ
- اطلاعات اشتراک، هشدارها و نمودار مصرف
- اپلیکیشن‌ها و اعلان‌ها از پنل
- کپی، QR و دانلود WireGuard برای کانفیگ‌ها
- تشخیص OS و مرتب‌سازی اپ‌ها
- یک فایل HTML — بدون Node.js و build

---

## نصب خودکار

روی سرور **Ubuntu** با Pasarguard نصب‌شده:

```bash
curl -fsSL https://raw.githubusercontent.com/Mrclocks/PGClock/main/install.sh -o /tmp/pgclock-install.sh && sudo bash /tmp/pgclock-install.sh
```

یا:

```bash
wget -qO /tmp/pgclock-install.sh https://raw.githubusercontent.com/Mrclocks/PGClock/main/install.sh && sudo bash /tmp/pgclock-install.sh
```

در منو گزینه **۲) PGClock** را انتخاب کنید.

### اسکریپت چه کار می‌کند؟

1. منوی انتخاب نسخه (`Lite` / `PGClock` / `Pro`)
2. ذخیرهٔ `index.html` در:

```text
/var/lib/pasarguard/templates/subscription/index.html
```

3. به‌روزرسانی `/opt/pasarguard/.env`:

```env
CUSTOM_TEMPLATES_DIRECTORY="/var/lib/pasarguard/templates/"
SUBSCRIPTION_PAGE_TEMPLATE="subscription/index.html"
```

4. اجرای `pasarguard restart`

> **پیش‌نیازها:** `wget`، `curl`، `python3`

---

## نصب دستی

### ۱. دانلود قالب

```bash
sudo mkdir -p /var/lib/pasarguard/templates/subscription/
sudo wget -N -O /var/lib/pasarguard/templates/subscription/index.html \
  https://raw.githubusercontent.com/Mrclocks/PGClock/main/index.html
```

### ۲. تنظیم Pasarguard

```bash
sudo nano /opt/pasarguard/.env
```

اضافه یا به‌روز کنید:

```env
CUSTOM_TEMPLATES_DIRECTORY="/var/lib/pasarguard/templates/"
SUBSCRIPTION_PAGE_TEMPLATE="subscription/index.html"
```

### ۳. راه‌اندازی مجدد

```bash
sudo pasarguard restart
```

---

## تنظیمات پنل

1. پنل Pasarguard → **Settings → Subscription**
2. ویرایش **announcement** و **announcement link**
3. افزودن/ویرایش اپ‌ها در بخش apps

---

## نسخه‌های دیگر

- [PGClock Lite](https://github.com/Mrclocks/PGClockLite) — سبک‌تر و سریع‌تر
- [PGClock Pro](https://github.com/Mrclocks/PGClockPRO) — برند، زیرعنوان و لوگوی سفارشی
