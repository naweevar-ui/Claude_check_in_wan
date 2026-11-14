/**
 * Google Apps Script backend สำหรับเว็บเช็คชื่อคลาส Claude AI
 * วิธีใช้: เปิด Google Sheet > ส่วนขยาย > Apps Script > วางโค้ดนี้ทั้งหมด > บันทึก
 * แล้ว Deploy > New deployment > Web app (Execute as: Me, Who has access: Anyone)
 * นำ URL ที่ลงท้ายด้วย /exec ไปวางในหน้าตั้งค่าของเว็บ หรือในตัวแปร GAS_URL ของ index.html
 * แนะนำ: Project Settings > Time zone = (GMT+07:00) Bangkok
 *
 * วางรายชื่อในแท็บ Roster เองก็ได้: ใส่ชื่อในคอลัมน์ B แล้วเว้นคอลัมน์ id ว่างไว้ ระบบจะสร้าง id ให้เอง
 */
const VERSION = '1.1.1';

const HEAD = {
  Roster:   ['id', 'ชื่อ-นามสกุล', 'บริษัท', 'ตำแหน่ง', 'อีเมล', 'เบอร์โทร', 'ลงทะเบียนโดย'],
  Checkins: ['id', 'ชื่อ-นามสกุล', 'บริษัท', 'วันที่', 'เวลา', 'สถานะ', 'สาย (นาที)', 'ลายเซ็น (Google Drive)', 'at', 'sig'],
  Settings: ['key', 'value']
};
const SIG_FOLDER = 'Claude Class ลายเซ็น';

function sh_(name) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let s = ss.getSheetByName(name);
  if (!s) {
    s = ss.insertSheet(name);
    s.getRange('A:Z').setNumberFormat('@');
    s.getRange(1, 1, 1, HEAD[name].length).setValues([HEAD[name]]).setFontWeight('bold').setBackground('#f6ede2');
    s.setFrozenRows(1);
    if (name === 'Checkins') s.hideColumns(9, 2); // ซ่อนคอลัมน์ข้อมูลดิบ at / sig
  }
  return s;
}

function rows_(name) {
  const s = sh_(name);
  if (s.getLastRow() < 2) return [];
  return s.getRange(2, 1, s.getLastRow() - 1, HEAD[name].length).getValues().filter(r => r[0] !== '');
}

/** ใส่ id ให้แถวที่วางชื่อลงแท็บ Roster เองโดยไม่มี id */
function fillIds_() {
  const s = sh_('Roster');
  if (s.getLastRow() < 2) return;
  const r = s.getRange(2, 1, s.getLastRow() - 1, 2), v = r.getValues();
  let changed = false;
  v.forEach(row => { if (row[0] === '' && String(row[1]).trim() !== '') { row[0] = 'r' + Utilities.getUuid().slice(0, 8); changed = true; } });
  if (changed) r.setValues(v);
}

/** เรียกครั้งแรกจากเมนู Run เพื่อสร้างแท็บและขอสิทธิ์ */
function setup() {
  ['Roster', 'Checkins', 'Settings'].forEach(sh_);
  DriveApp.getRootFolder();
}

function state_() {
  fillIds_();
  const roster = rows_('Roster').map(r => ({
    id: String(r[0]), name: String(r[1]), org: String(r[2]), pos: String(r[3]),
    email: String(r[4]), phone: String(r[5]), by: String(r[6])
  }));
  const checks = {};
  rows_('Checkins').forEach(r => { checks[String(r[0])] = { at: String(r[8]), sig: String(r[9] || ''), name: String(r[1]) }; });
  const settings = {};
  rows_('Settings').forEach(r => { try { settings[r[0]] = JSON.parse(r[1]); } catch (e) { settings[r[0]] = r[1]; } });
  return { ok: true, version: VERSION, roster, checks, settings };
}

function out_(o) {
  return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON);
}

function doGet() { return out_(state_()); }

function doPost(e) {
  const lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    const b = JSON.parse(e.postData.contents);
    if (b.action === 'roster') {
      const s = sh_('Roster');
      if (s.getLastRow() > 1) s.getRange(2, 1, s.getLastRow() - 1, 7).clearContent();
      const v = (b.people || []).map(p => [p.id, p.name, p.org || '', p.pos || '', p.email || '', p.phone || '', p.by || '']);
      if (v.length) s.getRange(2, 1, v.length, 7).setValues(v);
    }
    if (b.action === 'settings') {
      const s = sh_('Settings');
      if (s.getLastRow() > 1) s.getRange(2, 1, s.getLastRow() - 1, 2).clearContent();
      const v = Object.keys(b.settings || {}).map(k => [k, JSON.stringify(b.settings[k])]);
      if (v.length) s.getRange(2, 1, v.length, 2).setValues(v);
    }
    if (b.action === 'checkin') {
      remove_(b.id);
      const c = b.data, d = new Date(c.at), tz = Session.getScriptTimeZone();
      const link = c.sig ? saveSig_(b.id, c) : '';
      sh_('Checkins').appendRow([
        b.id, c.name || '', c.org || '',
        Utilities.formatDate(d, tz, 'yyyy-MM-dd'), Utilities.formatDate(d, tz, 'HH:mm'),
        c.status || '', c.late == null ? '' : c.late, link, c.at, c.sig || ''
      ]);
    }
    if (b.action === 'uncheck') remove_(b.id);
    if (b.action === 'clear') {
      const s = sh_('Checkins');
      if (s.getLastRow() > 1) s.deleteRows(2, s.getLastRow() - 1);
    }
    return out_(state_());
  } catch (err) {
    return out_({ ok: false, error: String(err) });
  } finally {
    lock.releaseLock();
  }
}

function remove_(id) {
  const s = sh_('Checkins');
  if (s.getLastRow() < 2) return;
  const v = s.getRange(2, 1, s.getLastRow() - 1, 1).getValues();
  for (let i = v.length - 1; i >= 0; i--) if (String(v[i][0]) === String(id)) s.deleteRow(i + 2);
}

function saveSig_(id, c) {
  try {
    const it = DriveApp.getFoldersByName(SIG_FOLDER);
    const folder = it.hasNext() ? it.next() : DriveApp.createFolder(SIG_FOLDER);
    const blob = Utilities.newBlob(Utilities.base64Decode(c.sig.split(',')[1]), 'image/png',
      (c.name || id) + '_' + String(c.at).slice(0, 16).replace(/[:T]/g, '-') + '.png');
    return folder.createFile(blob).getUrl();
  } catch (e) {
    return '';
  }
}
