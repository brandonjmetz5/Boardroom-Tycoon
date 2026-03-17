const {onRequest} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

// Optional sample HTTP function
exports.helloWorld = onRequest((request, response) => {
  logger.info("Hello logs!", {structuredData: true});
  response.send("Hello from Firebase!");
});

// World tick: runs every 1 minute (60 seconds).
exports.worldTick = onSchedule("every 1 minutes", (event) => {
  const now = new Date().toISOString();
  logger.info("worldTick fired", {at: now});

  // Later: add CPU market + production cleanup here.

  return null;
});
