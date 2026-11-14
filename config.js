/**
 * ตั้งค่าเว็บเช็คชื่อ
 * GAS_URL: URL ของ Google Apps Script Web App (ลงท้ายด้วย /exec)
 *          ถ้าเว้นว่าง เว็บจะเก็บข้อมูลไว้เฉพาะในเบราว์เซอร์ของเครื่องที่เปิด
 * DEFAULTS: ค่าเริ่มต้นของคลาส (แก้ทีหลังได้ในหน้าตั้งค่าของเว็บ ซึ่งจะบันทึกลง Google Sheet)
 */
window.CHECKIN_CONFIG = {
  GAS_URL: '',
  DEFAULTS: {
    title: 'Claude AI',
    start: '09:00',   // เวลาเริ่มเรียน
    grace: 10,        // ผ่อนผันได้กี่นาทีก่อนนับว่าสาย
    requireSig: true  // บังคับเซ็นชื่อ
  }
};
