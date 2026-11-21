/**
 * ตั้งค่าเว็บเช็คชื่อ (Supabase)
 * SUPABASE_URL / SUPABASE_KEY: ค่าจาก Supabase > Project Settings > API
 *   SUPABASE_KEY เป็น publishable key ใส่ในเว็บสาธารณะได้ ข้อมูลถูกป้องกันด้วย Row Level Security
 * ADMIN_EMAIL: แสดงเป็นคำแนะนำในหน้าเข้าสู่ระบบเท่านั้น
 *   สิทธิ์ผู้ดูแลจริงอยู่ในตาราง public.admins ใน Supabase
 */
window.CHECKIN_CONFIG = {
  SUPABASE_URL: 'https://hxwsjksgfptlhbogdyux.supabase.co',
  SUPABASE_KEY: 'sb_publishable_nVgjDV5fm8flsP0mJ0tyNQ_MAyCJzEg',
  ADMIN_EMAIL: 'thanawanv6@gmail.com',
  DEFAULTS: { title: 'Claude AI', start: '09:00', grace: 10, requireSig: true }
};
