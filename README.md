# เว็บเช็คชื่อคลาส Claude AI

**เวอร์ชัน 2.0.1** · เว็บจริง: https://naweevar-ui.github.io/Claude_check_in_wan/ · ดูการเปลี่ยนแปลงทั้งหมดใน [CHANGELOG.md](CHANGELOG.md)

เว็บเช็คชื่อผู้เข้าเรียน โทนน้ำตาลน่ารัก ใช้ได้ทั้งมือถือ แท็บเล็ต และคอมพิวเตอร์ ผู้เรียนแตะชื่อตัวเอง เซ็นชื่อ แล้วกดยืนยัน ระบบบันทึกเวลาจากเซิร์ฟเวอร์และบอกว่ามาตรงเวลาหรือสาย ข้อมูลทั้งหมดเก็บใน **Supabase**

## ใครทำอะไรได้บ้าง
| | ผู้เรียน (ไม่ต้องล็อกอิน) | ผู้ดูแล (ล็อกอินด้วย Google) |
|---|---|---|
| ดูรายชื่อ ค้นหา กรอง | ได้ (เห็นแค่ชื่อ บริษัท เวลาเช็คอิน) | ได้ (เห็นอีเมล เบอร์โทร ลายเซ็นด้วย) |
| เช็คอินพร้อมเซ็นชื่อ | ได้ คนละ 1 ครั้ง | ได้ |
| ยกเลิกเช็คอิน, ดูลายเซ็น | ไม่ได้ | ได้ |
| นำเข้ารายชื่อ CSV / Excel, เพิ่มชื่อ walk-in | ไม่ได้ | ได้ |
| ส่งออก CSV / คัดลอกไป Google Sheet | ไม่ได้ | ได้ |
| ตั้งค่าเวลาเริ่มเรียน เวลาผ่อนผัน บังคับเซ็นชื่อ, เริ่มวันใหม่ | ไม่ได้ | ได้ |

ผู้ดูแลคือบัญชีที่อยู่ในตาราง `public.admins` ตอนนี้มี 2 บัญชีคือ **thanawanv6@gmail.com** และ **naweevar@gmail.com** ถ้าล็อกอินด้วยบัญชีอื่น ระบบจะออกจากระบบให้อัตโนมัติ

## โครงสร้างไฟล์
```
├── index.html            หน้าเช็คชื่อ
├── login.html            หน้าเข้าสู่ระบบผู้ดูแล (Google)
├── config.js             URL และ publishable key ของ Supabase
├── supabase/schema.sql   โครงสร้างฐานข้อมูล ตาราง สิทธิ์ (RLS) และฟังก์ชัน
├── templates/roster-template.csv  ตัวอย่างไฟล์รายชื่อ
├── VERSION, CHANGELOG.md
```

## ฐานข้อมูล Supabase
โปรเจกต์ `claude-class-checkin` (ref `hxwsjksgfptlhbogdyux`, ภูมิภาค Singapore) ติดตั้งตาราง สิทธิ์ และรายชื่อ 22 คนไว้แล้ว
- `roster` รายชื่อผู้เข้าเรียน
- `checkins` การเช็คอิน คนละ 1 แถว เก็บเวลา สถานะ และลายเซ็น (PNG)
- `class_settings` ชื่อคลาส เวลาเริ่มเรียน เวลาผ่อนผัน บังคับเซ็นชื่อ
- `admins` อีเมลผู้ดูแล

`SUPABASE_KEY` ใน `config.js` เป็น publishable key ออกแบบมาให้ใส่ในเว็บสาธารณะได้ ข้อมูลถูกป้องกันด้วย Row Level Security

## ตั้งค่าล็อกอินด้วย Google (ทำครั้งเดียว)
1. **Google Cloud Console** → https://console.cloud.google.com/apis/credentials (ล็อกอินด้วย thanawanv6@gmail.com)
   - ถ้ายังไม่มีโปรเจกต์ ให้สร้างโปรเจกต์ใหม่
   - **OAuth consent screen**: เลือก External ใส่ชื่อแอป `เช็คชื่อ Claude AI` และอีเมลติดต่อ แล้วกด Publish app (หรือเพิ่ม thanawanv6@gmail.com เป็น Test user)
   - **Create credentials → OAuth client ID** → Application type: **Web application**
   - Authorized JavaScript origins: `https://naweevar-ui.github.io`
   - Authorized redirect URIs: `https://hxwsjksgfptlhbogdyux.supabase.co/auth/v1/callback`
   - กด Create แล้วคัดลอก **Client ID** และ **Client secret**
2. **Supabase Dashboard** → https://supabase.com/dashboard/project/hxwsjksgfptlhbogdyux/auth/providers
   - เปิด **Google** วาง Client ID และ Client secret แล้วกด Save
3. **Supabase → Authentication → URL Configuration** (https://supabase.com/dashboard/project/hxwsjksgfptlhbogdyux/auth/url-configuration)
   - Site URL: `https://naweevar-ui.github.io/Claude_check_in_wan/`
   - Redirect URLs: เพิ่ม `https://naweevar-ui.github.io/Claude_check_in_wan/**`
4. เปิด https://naweevar-ui.github.io/Claude_check_in_wan/login.html แล้วกด "เข้าสู่ระบบด้วย Google"

## งานประจำของผู้ดูแล
- **ก่อนเริ่มคลาส:** ล็อกอิน → นำเข้ารายชื่อ (ถ้ามีรายชื่อใหม่) → ตั้งค่าเวลาเริ่มเรียน
- **หลังจบคลาส:** ส่งออก CSV หรือคัดลอกไปวางใน Google Sheet
- **คลาสวันใหม่:** ตั้งค่า → เริ่มวันใหม่ (ล้างการเช็คอิน รายชื่อยังอยู่)
- **เพิ่มผู้ดูแล:** Supabase → SQL Editor → `insert into public.admins values ('อีเมล@gmail.com');`

## นำเข้ารายชื่อ
รองรับ `.csv`, `.xlsx`, `.xls` หรือวางจาก Excel / Google Sheet แถวแรกเป็นหัวคอลัมน์ เช่น `ชื่อ-นามสกุล`, `ชื่อ`, `นามสกุล`, `บริษัท`, `ตำแหน่ง`, `อีเมล`, `เบอร์โทร` และรองรับไฟล์จาก Google Form ที่ลงทะเบียนได้หลายคนต่อฟอร์ม (คอลัมน์ `ชื่อ-นามสกุล 2`, `3` …)

ไฟล์รายชื่อจริงอย่าอัปโหลดขึ้น GitHub `.gitignore` กันไฟล์ `.xlsx`, `.xls`, `roster*.csv` ไว้แล้ว
