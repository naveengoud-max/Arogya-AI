/* ==========================================================================
   ArogyaAI Firestore Production Database Seeding Script
   ========================================================================== */

const fs = require('fs');
const path = require('path');

console.log("[SEED] Initializing ArogyaAI Firestore Seed script...");

const dbDir = path.join(__dirname, 'database');

// Read local database files
const hospitals = JSON.parse(fs.readFileSync(path.join(dbDir, 'db_hospitals.json'), 'utf8'));
const doctors = JSON.parse(fs.readFileSync(path.join(dbDir, 'db_doctors.json'), 'utf8'));
const appointments = JSON.parse(fs.readFileSync(path.join(dbDir, 'db_appointments.json'), 'utf8'));
const users = JSON.parse(fs.readFileSync(path.join(dbDir, 'db_users.json'), 'utf8'));
const reports = JSON.parse(fs.readFileSync(path.join(dbDir, 'db_reports.json'), 'utf8'));

console.log(`[SEED] Found Local Data:`);
console.log(` - Hospitals: ${Object.keys(hospitals).length}`);
console.log(` - Doctors: ${Object.keys(doctors).length}`);
console.log(` - Appointments: ${Array.isArray(appointments) ? appointments.length : Object.keys(appointments).length}`);
console.log(` - Users: ${Object.keys(users).length}`);
console.log(` - Reports: ${Array.isArray(reports) ? reports.length : Object.keys(reports).length}`);

console.log("[SEED] All collections ready for live Firestore seeding!");
