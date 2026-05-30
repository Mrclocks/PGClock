<div align="center">
  <img src="Preview.png" alt="PGClock Preview">
</div>

<h1 align="center">PGClock</h1>

<p align="center">
تمپلیت صفحه کاربری پنل پاسارگارد </p>

<br>

## ✨ ویژگی‌ها

* طراحی مینیمال با سبک شیشه ای
* نمایش اطلاعات کاربر
* دریافت لیست اپلیکیشن‌ها و اعلان ها از پنل
* نمایش لینک کانفیگ‌ها و QR Code
* کدنویسی سبک، تمیز و بهینه

---

## 🚀 نصب خودکار

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/Mrclocks/PGClock/main/install.sh)
```

یا:

```bash
sudo bash <(wget -qO- https://raw.githubusercontent.com/Mrclocks/PGClock/main/install.sh)
```

اسکریپت نصب به‌صورت خودکار:

* قالب را دانلود و نصب می‌کند
* مقادیر لازم را به `.env` اضافه یا بروزرسانی می‌کند
* سرویس PasarGuard را ریستارت می‌کند

---

## 🔧 نصب دستی

فایل `index.html` را دانلود کرده و در مسیر زیر قرار دهید:

```text
/var/lib/pasarguard/templates/subscription/index.html
```

فایل تنظیمات را ویرایش کنید:

```bash
sudo nano /opt/pasarguard/.env
```

و مقادیر زیر را اضافه یا اصلاح نمایید:

```env
CUSTOM_TEMPLATES_DIRECTORY="/var/lib/pasarguard/templates/"
SUBSCRIPTION_PAGE_TEMPLATE="subscription/index.html"
```

در پایان سرویس را ریستارت کنید:

```bash
sudo pasarguard restart
```
