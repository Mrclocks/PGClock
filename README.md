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


## 🔧 نصب و راه اندازی 

از طریق ترمینال وارد سرور پاسارگارد شوید 

فایل `index.html` را دانلود کنید :
```bash
sudo wget -N -P /var/lib/pasarguard/templates/subscription/ https://raw.githubusercontent.com/Mrclocks/PGClock/main/index.html
```

فایل .env را ویرایش کنید:

```bash
sudo nano /opt/pasarguard/.env
```

و مقادیر زیر را اضافه یا اصلاح نمایید:

```env
CUSTOM_TEMPLATES_DIRECTORY="/var/lib/pasarguard/templates/"
SUBSCRIPTION_PAGE_TEMPLATE="subscription/index.html"
```

در پایان پاسارگارد را ریستارت کنید:

```bash
sudo pasarguard restart
```
