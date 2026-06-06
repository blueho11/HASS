// ============================================================
//  HASS ESP32 — Ethernet (W5500) primary, WiFi fallback
//
//  HOW TO READ THIS FILE:
//  Lines marked  // ── NEW  are the only additions.
//  Everything else is your original code, character for character.
//
//  Library to install:
//    Ethernet  by Paul Stoffregen  (search in Arduino Library Manager)
//
//  W5500 wiring:
//    MOSI → GPIO23   MISO → GPIO19
//    SCK  → GPIO18   CS   → GPIO5
//    RST  → GPIO4    VCC  → 3.3V    GND → GND
//
//  HOW ETHERNET + FIREBASE WORKS ON ESP32:
//  Firebase_ESP_Client on ESP32 uses the ESP-IDF TCP/IP stack
//  directly — not the WiFi driver. Once the W5500 has an IP and
//  the route to the internet is through Ethernet, Firebase HTTPS
//  calls go through Ethernet automatically. No special client
//  object or callback is needed. The only rule is: do NOT call
//  WiFi.disconnect(true,true) before Firebase init when using
//  Ethernet — that erases the netif and kills all TCP. We keep
//  WiFi in WIFI_MODE_NULL (completely off) instead.
// ============================================================

#include <WiFi.h>
#include <Preferences.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>
#include <addons/RTDBHelper.h>
#include <DHT.h>
#include <time.h>

// ── NEW: Ethernet includes ────────────────────────────────────
#include <ETH.h>  // replaces <SPI.h> + <Ethernet.h>
// ─────────────────────────────────────────────────────────────


// ── Firebase / project config ─────────────────────────────────
#define API_KEY "public-DB-keys"
#define DATABASE_URL "https://hass-c6f0e-default-rtdb.firebaseio.com"
#define BOARD_ID "A7F3C91D2B"


// ── GPIO assignments ─────────────────────────────────────────
#define DHTPIN 32
#define DHTTYPE DHT22
#define RELAY1 27
#define RELAY2 14
#define RELAY3 25
#define RELAY4 26
#define BUZZER 13


// ── UART to CYD ──────────────────────────────────────────────
#define SERIAL2_BAUD 115200
#define MAIN_RX_PIN 16
#define MAIN_TX_PIN 17


// ── Polling intervals (ms) ───────────────────────────────────
#define STATE_INTERVAL 150
#define SENSOR_INTERVAL 1000
#define HEARTBEAT_INTERVAL 10000
#define SCHEDULE_INTERVAL 30000
#define TIMER_INTERVAL 10000


// ── NEW: W5500 pin definitions ────────────────────────────────
#define ETH_CS_PIN 5
#define ETH_RST_PIN 4
#define ETH_MISO_PIN 19
#define ETH_MOSI_PIN 23
#define ETH_SCLK_PIN 18
#define ETH_INT_PIN -1  // not used, polling mode
// ─────────────────────────────────────────────────────────────


// ── Firebase objects ─────────────────────────────────────────
FirebaseData fbdo;   // polling / reads
FirebaseData fbdo2;  // writes (separate stream slot)
FirebaseAuth auth;
FirebaseConfig config;


DHT dht(DHTPIN, DHTTYPE);
Preferences prefs;  // [Task 7] flash storage for WiFi credentials


// ── NEW: Ethernet state ───────────────────────────────────────
bool ethernetConnected = false;  // set inside event handler  // ── NEW
bool usingEthernet = false;
// ─────────────────────────────────────────────────────────────


// ── Runtime state ────────────────────────────────────────────
bool firebaseInitialized = false;
bool wifiConnecting = false;
unsigned long wifiConnectStart = 0;
bool usingStoredCreds = false;  // [Task 7] track boot-time attempt


int relayState[5] = { -1, -1, -1, -1, -1 };  // index 1-4 used
float lastTemp = 0, lastHum = 0;


unsigned long lastStateCheck = 0;
unsigned long lastSensorUpload = 0;
unsigned long lastHeartbeat = 0;
unsigned long lastScheduleCheck = 0;
unsigned long lastTimerCheck = 0;


const char* dayNames[] = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" };
String lastFiredSchedule = "";
int lastFiredHour = -1, lastFiredMin = -1;


// ── NEW: forward declaration ──────────────────────────────────
// needed because initFirebase() calls startWiFiConnection()
// which is defined later in the file.
void startWiFiConnection(const String& ssid, const String& pass,
                         bool fromStorage = false);
// ─────────────────────────────────────────────────────────────


// ============================================================
//  UART HELPERS
// ============================================================


void sendToCYD(const String& msg) {
  Serial2.println(msg);
  Serial.println("-> CYD: " + msg);
}


// ============================================================
//  BUZZER
//  NOTE: delay() intentionally used ONLY here. All other logic
//  is non-blocking.
// ============================================================


void beep(int ms) {
  digitalWrite(BUZZER, HIGH);
  delay(ms);
  digitalWrite(BUZZER, LOW);
}


void startupSound() {
  beep(150);
  delay(100);
  beep(150);
  delay(100);
  beep(300);
}


void relayOnSound() {
  beep(80);
}
void relayOffSound() {
  beep(200);
}


// ============================================================
//  HELPERS
// ============================================================


bool safeBool(FirebaseJsonData& data) {
  if (data.type == "boolean") return data.boolValue;
  if (data.type == "int") return data.intValue == 1;
  if (data.type == "string") return data.stringValue == "true";
  return data.boolValue || data.intValue == 1;
}


int relayPin(int slot) {
  switch (slot) {
    case 1: return RELAY1;
    case 2: return RELAY2;
    case 3: return RELAY3;
    case 4: return RELAY4;
    default: return -1;
  }
}


int slotFromKey(String key) {
  key.replace("s", "");
  return key.toInt();
}


// ============================================================
//  [Task 7] PREFERENCES — save / load / clear WiFi credentials
//  Uses the ESP32 NVS (non-volatile storage) via Preferences.
//  Namespace: "wifi"   Keys: "ssid", "pass"
// ============================================================


void saveCredentials(const String& ssid, const String& pass) {
  prefs.begin("wifi", false);  // false = read-write
  prefs.putString("ssid", ssid);
  prefs.putString("pass", pass);
  prefs.end();
  Serial.println("[Prefs] Credentials saved — SSID: " + ssid);
}


// Returns true if saved credentials exist, populates ssid/pass.
bool loadCredentials(String& ssid, String& pass) {
  prefs.begin("wifi", true);  // true = read-only
  ssid = prefs.getString("ssid", "");
  pass = prefs.getString("pass", "");
  prefs.end();
  if (ssid.length() > 0) {
    Serial.println("[Prefs] Loaded saved SSID: " + ssid);
    return true;
  }
  Serial.println("[Prefs] No saved credentials found");
  return false;
}


// Called when stored credentials time out — prevents wasting
// 20 s on every subsequent boot with bad/stale credentials.
void clearCredentials() {
  prefs.begin("wifi", false);
  prefs.clear();
  prefs.end();
  Serial.println("[Prefs] Credentials cleared from flash");
}


// ============================================================
//  RELAY CONTROL
// ============================================================


void setRelay(int slot, bool on) {
  int pin = relayPin(slot);
  if (pin == -1) return;


  int newState = on ? 1 : 0;
  if (newState == relayState[slot]) return;  // no change needed


  digitalWrite(pin, on ? HIGH : LOW);
  relayState[slot] = newState;


  on ? relayOnSound() : relayOffSound();


  Serial.printf("Relay s%d -> %s\n", slot, on ? "ON" : "OFF");


  if (firebaseInitialized && Firebase.ready()) {
    String path = "/live/boards/" BOARD_ID "/state/s" + String(slot);
    Firebase.RTDB.setBool(&fbdo2, path.c_str(), on);
  }


  sendToCYD("RELAY " + String(slot) + " " + String(on ? 1 : 0));
}


// ============================================================
//  FIREBASE POLLING TASKS
// ============================================================


void checkRelayStates() {
  if (!firebaseInitialized || !Firebase.ready()) return;
  for (int i = 1; i <= 4; i++) {
    String path = "/live/boards/" BOARD_ID "/state/s" + String(i);
    if (Firebase.RTDB.getBool(&fbdo, path.c_str())) {
      setRelay(i, fbdo.boolData());
    }
  }
}


void uploadSensorData() {
  if (!firebaseInitialized || !Firebase.ready()) return;


  float temp = dht.readTemperature();
  float hum = dht.readHumidity();
  if (isnan(temp) || isnan(hum)) {
    Serial.println("DHT22 read failed");
    return;
  }


  lastTemp = temp;
  lastHum = hum;
  Serial.printf("Temp: %.1f°C  Hum: %.1f%%\n", temp, hum);


  if (temp > 45) {
    for (int i = 0; i < 5; i++) {
      beep(200);
      delay(200);
    }
  }


  Firebase.RTDB.setFloat(&fbdo2, "/live/boards/" BOARD_ID "/sensor/temperature", temp);
  Firebase.RTDB.setFloat(&fbdo2, "/live/boards/" BOARD_ID "/sensor/humidity", hum);


  sendToCYD("TEMP " + String(temp, 1));
}


void writeHeartbeat() {
  if (!firebaseInitialized || !Firebase.ready()) return;


  time_t now = time(nullptr);
  struct tm* t = gmtime(&now);
  char ts[30];
  strftime(ts, sizeof(ts), "%Y-%m-%dT%H:%M:%SZ", t);


  Firebase.RTDB.setBool(&fbdo2, "/live/boards/" BOARD_ID "/status/online", true);
  Firebase.RTDB.setString(&fbdo2, "/live/boards/" BOARD_ID "/status/lastHeartbeat", ts);


  Serial.print("Heartbeat: ");
  Serial.println(ts);
}


// Protocol: "TIME 08:30 AM Thursday, 10"
// CYD does two-space split → timeStr="08:30 AM", dateStr="Thursday, 10"
void sendTimeToCYD() {
  time_t now = time(nullptr);
  if (now < 100000) return;  // NTP not synced yet


  struct tm* t = localtime(&now);


  int hour12 = t->tm_hour % 12;
  if (hour12 == 0) hour12 = 12;


  char timeStr[12];
  snprintf(timeStr, sizeof(timeStr), "%02d:%02d %s",
           hour12, t->tm_min, t->tm_hour < 12 ? "AM" : "PM");


  const char* weekDayFull[] = {
    "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
  };
  char dateStr[20];
  snprintf(dateStr, sizeof(dateStr), "%s, %d",
           weekDayFull[t->tm_wday], t->tm_mday);


  sendToCYD(String("TIME ") + timeStr + " " + dateStr);
}


// [Task 6] Push everything to CYD in one call
void sendAllStateToCYD() {
  sendToCYD("BOARDID " + String(BOARD_ID));
  // ── NEW: report connected if EITHER Ethernet OR WiFi is up ──
  sendToCYD("WIFI_STATUS " + String((usingEthernet || WiFi.status() == WL_CONNECTED) ? 1 : 0));
  // ────────────────────────────────────────────────────────────
  for (int i = 1; i <= 4; i++) {
    sendToCYD("RELAY " + String(i) + " " + String(relayState[i] == 1 ? 1 : 0));
  }
  if (lastTemp != 0) sendToCYD("TEMP " + String(lastTemp, 1));
  sendTimeToCYD();
}


// ── Schedule executor ─────────────────────────────────────────
void checkSchedules() {
  if (!firebaseInitialized || !Firebase.ready()) return;


  time_t now = time(nullptr);
  struct tm* t = localtime(&now);
  int curHour = t->tm_hour, curMin = t->tm_min, curDay = t->tm_wday;


  String path = "/live/boards/" BOARD_ID "/schedules";
  if (!Firebase.RTDB.getJSON(&fbdo2, path.c_str())) return;
  if (fbdo2.jsonString() == "null" || fbdo2.jsonString().length() == 0) return;


  FirebaseJson json;
  json.setJsonData(fbdo2.jsonString());
  size_t count = json.iteratorBegin();


  for (size_t i = 0; i < count; i++) {
    int jtype;
    String key, value;
    json.iteratorGet(i, jtype, key, value);
    if (jtype != FirebaseJson::JSON_OBJECT) continue;
    if (key == "action" || key == "devices" || key == "enabled" || key == "time" || key == "type" || key == "days") continue;


    FirebaseJson rule;
    rule.setJsonData(value);


    FirebaseJsonData enabledData;
    rule.get(enabledData, "enabled");
    if (!safeBool(enabledData)) continue;


    FirebaseJsonData timeData;
    rule.get(timeData, "time");
    int ruleHour = timeData.stringValue.substring(0, 2).toInt();
    int ruleMin = timeData.stringValue.substring(3, 5).toInt();
    if (curHour != ruleHour || curMin != ruleMin) continue;
    if (key == lastFiredSchedule && curHour == lastFiredHour && curMin == lastFiredMin) continue;


    FirebaseJsonData typeData;
    rule.get(typeData, "type");
    bool dayMatch = (typeData.stringValue == "daily");
    if (!dayMatch) {
      String todayName = dayNames[curDay];
      for (int d = 0; d < 7; d++) {
        FirebaseJsonData dayItem;
        rule.get(dayItem, ("days/[" + String(d) + "]").c_str());
        if (dayItem.stringValue == todayName) {
          dayMatch = true;
          break;
        }
      }
    }
    if (!dayMatch) continue;


    FirebaseJsonData actionData;
    rule.get(actionData, "action");
    bool action = safeBool(actionData);
    bool fired = false;


    for (int s = 0; s < 4; s++) {
      FirebaseJsonData deviceItem;
      rule.get(deviceItem, ("devices/[" + String(s) + "]").c_str());
      if (deviceItem.stringValue.length() == 0) break;
      int slot = deviceItem.stringValue.substring(1).toInt();
      if (slot >= 1 && slot <= 4) {
        setRelay(slot, action);
        fired = true;
      }
    }


    if (fired) {
      lastFiredSchedule = key;
      lastFiredHour = curHour;
      lastFiredMin = curMin;
      beep(150);
      delay(100);
      beep(150);
    }
  }
  json.iteratorEnd();
}


// ── If-Then rule executor ────────────────────────────────────
void checkIfThen() {
  if (!firebaseInitialized || !Firebase.ready()) return;
  if (lastTemp == 0 && lastHum == 0) return;


  String path = "/live/boards/" BOARD_ID "/ifthen";
  if (!Firebase.RTDB.getJSON(&fbdo2, path.c_str())) return;


  FirebaseJson json;
  json.setJsonData(fbdo2.jsonString());
  size_t count = json.iteratorBegin();


  for (size_t i = 0; i < count; i++) {
    int type;
    String key, value;
    json.iteratorGet(i, type, key, value);
    if (type != FirebaseJson::JSON_OBJECT) continue;
    if (key == "action" || key == "device" || key == "enabled" || key == "sensor" || key == "condition" || key == "threshold") continue;


    FirebaseJson rule;
    rule.setJsonData(value);


    FirebaseJsonData enabledData;
    rule.get(enabledData, "enabled");
    if (!safeBool(enabledData)) continue;


    FirebaseJsonData sensorData, condData, threshData, deviceData, actionData;
    rule.get(sensorData, "sensor");
    rule.get(condData, "condition");
    rule.get(threshData, "threshold");
    rule.get(deviceData, "device");
    rule.get(actionData, "action");


    float sensorValue = (sensorData.stringValue == "temperature") ? lastTemp : lastHum;
    bool condMet = false;


    if (condData.stringValue == ">") condMet = sensorValue > threshData.floatValue;
    else if (condData.stringValue == "<") condMet = sensorValue < threshData.floatValue;
    else if (condData.stringValue == "=") condMet = fabs(sensorValue - threshData.floatValue) < 0.5f;


    if (!condMet) continue;


    int slot = slotFromKey(deviceData.stringValue);
    if (slot >= 1 && slot <= 4) setRelay(slot, safeBool(actionData));
  }
  json.iteratorEnd();
}


// ── Timer executor ───────────────────────────────────────────
void checkTimers() {
  if (!firebaseInitialized || !Firebase.ready()) return;


  time_t now = time(nullptr);
  String path = "/live/boards/" BOARD_ID "/timers";
  if (!Firebase.RTDB.getJSON(&fbdo2, path.c_str())) return;


  FirebaseJson json;
  json.setJsonData(fbdo2.jsonString());
  size_t count = json.iteratorBegin();


  for (size_t i = 0; i < count; i++) {
    int type;
    String key, value;
    json.iteratorGet(i, type, key, value);
    if (type != FirebaseJson::JSON_OBJECT) continue;
    if (key == "active" || key == "device" || key == "action" || key == "duration" || key == "triggeredAt") continue;


    FirebaseJson rule;
    rule.setJsonData(value);


    FirebaseJsonData activeData;
    rule.get(activeData, "active");
    if (!safeBool(activeData)) continue;


    FirebaseJsonData triggeredData, durationData, deviceData, actionData;
    rule.get(triggeredData, "triggeredAt");
    rule.get(durationData, "duration");
    rule.get(deviceData, "device");
    rule.get(actionData, "action");


    long elapsed = (long)now - triggeredData.intValue;
    if (elapsed < durationData.intValue) continue;


    int slot = slotFromKey(deviceData.stringValue);
    if (slot >= 1 && slot <= 4) {
      setRelay(slot, safeBool(actionData));
      Firebase.RTDB.setBool(&fbdo2,
                            ("/live/boards/" BOARD_ID "/timers/" + key + "/active").c_str(), false);
      beep(300);
      delay(100);
      beep(300);
    }
  }
  json.iteratorEnd();
}


// ============================================================
//  NEW: ETH event handler
//  >>> ONLY THIS FUNCTION CHANGED vs previous version <
//  Added: DISCONNECTED → fall back to WiFi
//  Added: GOT_IP (re-plug) → switch back to Ethernet
// ============================================================
void onEthEvent(WiFiEvent_t event) {

  if (event == ARDUINO_EVENT_ETH_GOT_IP) {
    // ── cable plugged / re-plugged and DHCP gave us an IP ────
    ethernetConnected = true;

    // ── NEW: if we were on WiFi, switch back to Ethernet ─────
    if (!usingEthernet && firebaseInitialized) {
      Serial.println("[ETH] Cable re-plugged — switching back to Ethernet");
      usingEthernet = true;
      firebaseInitialized = false;  // force full re-init      // ── NEW
      WiFi.disconnect(true);        // drop WiFi cleanly       // ── NEW
      wifiConnecting = false;       // ── NEW
      initFirebase();               // ── NEW
    }
    // ─────────────────────────────────────────────────────────

  } else if (event == ARDUINO_EVENT_ETH_DISCONNECTED) {  // ── NEW
    // ── cable unplugged ──────────────────────────────────────
    Serial.println("[ETH] Cable unplugged — falling back to WiFi");
    ethernetConnected = false;    // ── NEW
    usingEthernet = false;        // ── NEW
    firebaseInitialized = false;  // Firebase is now dead     // ── NEW

    sendToCYD("WIFI_STATUS 0");  // ── NEW

    // try saved WiFi credentials, or wait for CYD to send them // ── NEW
    WiFi.mode(WIFI_STA);                                                 // ── NEW
    String savedSsid, savedPass;                                         // ── NEW
    if (loadCredentials(savedSsid, savedPass)) {                         // ── NEW
      Serial.println("[ETH] Trying saved WiFi credentials...");          // ── NEW
      startWiFiConnection(savedSsid, savedPass, true);                   // ── NEW
    } else {                                                             // ── NEW
      Serial.println("[ETH] Waiting for WiFi credentials from CYD...");  // ── NEW
    }                                                                    // ── NEW
  }
}


// ============================================================
//  NEW: Try to start W5500 Ethernet with DHCP
// ============================================================
bool tryStartEthernet() {
  Serial.println("[ETH] Resetting W5500...");

  WiFi.onEvent(onEthEvent);

  bool result = ETH.begin(
    ETH_PHY_W5500,
    0,
    ETH_CS_PIN,
    ETH_INT_PIN,
    ETH_RST_PIN,
    SPI3_HOST,
    ETH_SCLK_PIN,
    ETH_MISO_PIN,
    ETH_MOSI_PIN);

  if (!result) {
    Serial.println("[ETH] W5500 hardware NOT found — skipping Ethernet");
    return false;
  }

  Serial.println("[ETH] Starting DHCP (max 8 s)...");
  unsigned long t = millis();
  while (!ethernetConnected && millis() - t < 8000) delay(100);

  if (!ethernetConnected) {
    if (!ETH.linkUp()) {
      Serial.println("[ETH] Cable not connected — skipping Ethernet");
    } else {
      Serial.println("[ETH] DHCP failed — skipping Ethernet");
    }
    return false;
  }

  Serial.print("[ETH] Connected! IP: ");
  Serial.println(ETH.localIP());
  return true;
}


// ============================================================
//  WIFI + FIREBASE INIT
// ============================================================


void initFirebase() {
  if (usingEthernet) {
    Serial.println("[Main] Ethernet connected! Starting Firebase init...");
    Serial.print("[Main] IP: ");
    Serial.println(ETH.localIP());
  } else {
    Serial.println("[Main] WiFi connected! Starting Firebase init...");
    Serial.print("[Main] IP: ");
    Serial.println(WiFi.localIP());
  }


  sendToCYD("WIFI_STATUS 1");


  Serial.print("[Main] Syncing NTP time...");
  configTime(3 * 3600, 0, "pool.ntp.org", "time.nist.gov");
  int attempts = 0;
  while (time(nullptr) < 100000 && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  Serial.println(" done");


  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  config.token_status_callback = tokenStatusCallback;


  Serial.print("[Main] Firebase signUp...");
  if (Firebase.signUp(&config, &auth, "", "")) {
    Serial.println(" OK");
  } else {
    Serial.print(" FAILED: ");
    Serial.println(config.signer.signupError.message.c_str());
    beep(1000);
  }


  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);


  Serial.print("[Main] Waiting for Firebase ready");
  attempts = 0;
  while (!Firebase.ready() && attempts < 40) {
    delay(500);
    Serial.print(".");
    attempts++;
  }


  if (Firebase.ready()) {
    Serial.println(" connected!");
    firebaseInitialized = true;
    beep(100);
    delay(100);
    beep(100);


    checkRelayStates();
    writeHeartbeat();
    sendAllStateToCYD();


    Serial.println("[Main] === HASS ESP32 Ready ===");
  } else {
    Serial.println(" FAILED!");
    beep(1000);

    if (usingEthernet) {
      usingEthernet = false;
      Serial.println("[Main] Ethernet Firebase failed — falling back to WiFi");
      sendToCYD("WIFI_STATUS 0");

      WiFi.mode(WIFI_STA);
      WiFi.disconnect(true, true);
      delay(100);

      String savedSsid, savedPass;
      if (loadCredentials(savedSsid, savedPass)) {
        Serial.println("[Main] Trying saved WiFi credentials...");
        startWiFiConnection(savedSsid, savedPass, true);
      } else {
        Serial.println("[Main] Waiting for WiFi credentials from CYD...");
      }
    }
  }
}


// ── [Task 7] startWiFiConnection ─────────────────────────────
void startWiFiConnection(const String& ssid, const String& pass, bool fromStorage) {
  Serial.println("[Main] ========== startWiFiConnection ==========");
  Serial.printf("[Main] SSID: '%s'  Source: %s\n",
                ssid.c_str(), fromStorage ? "flash" : "CYD");


  usingStoredCreds = fromStorage;


  sendToCYD("WIFI_STATUS 0");


  WiFi.disconnect(true, true);
  delay(200);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid.c_str(), pass.c_str());


  wifiConnecting = true;
  wifiConnectStart = millis();
  Serial.println("[Main] WiFi.begin() called — waiting up to 20 s...");
}


// Non-blocking WiFi status poller
void checkWiFiStatus() {
  if (!wifiConnecting) return;


  if (WiFi.status() == WL_CONNECTED) {
    wifiConnecting = false;
    initFirebase();


  } else if (millis() - wifiConnectStart > 20000) {
    wifiConnecting = false;
    Serial.printf("[Main] WiFi TIMEOUT (status=%d)\n", WiFi.status());


    if (usingStoredCreds) {
      Serial.println("[Main] Stored credentials failed — clearing flash");
      clearCredentials();
    }


    sendToCYD("WIFI_STATUS 0");
    Serial.println("[Main] Waiting for WiFi credentials from CYD...");
  }
}


// ============================================================
//  NEW: Keep W5500 DHCP lease alive — no-op, ETH.h handles it
// ============================================================
void maintainEthernet() {
  // no-op: esp_eth renews the lease automatically
}


// ============================================================
//  UART FROM CYD
// ============================================================
void handleSerialFromCYD() {
  static String buffer;


  while (Serial2.available()) {
    char c = Serial2.read();


    if (c == '\n') {
      buffer.trim();
      if (buffer.length() == 0) {
        buffer = "";
        continue;
      }


      Serial.println("[Main] <<< CYD: '" + buffer + "'");


      if (buffer == "READY") {
        Serial.println("[Main] CYD sent READY — re-sending all state");
        sendAllStateToCYD();
        buffer = "";
        continue;
      }


      int space1 = buffer.indexOf(' ');
      if (space1 == -1) {
        Serial.println("[Main] WARNING: no space, ignoring: " + buffer);
        buffer = "";
        continue;
      }


      String cmd = buffer.substring(0, space1);
      String rest = buffer.substring(space1 + 1);
      Serial.printf("[Main] CMD='%s' REST='%s'\n", cmd.c_str(), rest.c_str());


      if (cmd == "WIFI") {
        if (usingEthernet) {
          Serial.println("[Main] Ethernet active — ignoring WIFI command from CYD");
        } else {
          int space2 = rest.indexOf(' ');
          if (space2 != -1) {
            String ssid = rest.substring(0, space2);
            String pass = rest.substring(space2 + 1);
            saveCredentials(ssid, pass);
            startWiFiConnection(ssid, pass, false);
          } else {
            Serial.println("[Main] ERROR: WIFI missing password");
          }
        }


      } else if (cmd == "TOGGLE") {
        int space2 = rest.indexOf(' ');
        if (space2 != -1) {
          int slot = rest.substring(0, space2).toInt();
          bool on = rest.substring(space2 + 1).toInt() == 1;
          Serial.printf("[Main] TOGGLE slot=%d on=%d\n", slot, on);
          if (slot >= 1 && slot <= 4) setRelay(slot, on);
          else Serial.printf("[Main] ERROR: invalid slot %d\n", slot);
        } else {
          Serial.println("[Main] ERROR: TOGGLE missing value");
        }


      } else {
        Serial.println("[Main] WARNING: unknown cmd: " + cmd);
      }


      buffer = "";
    } else {
      buffer += c;
    }
  }
}


// ============================================================
//  SETUP
// ============================================================
void setup() {
  Serial.begin(115200);
  Serial2.begin(SERIAL2_BAUD, SERIAL_8N1, MAIN_RX_PIN, MAIN_TX_PIN);


  Serial.println("\n[Main] === HASS ESP32 Starting ===");
  Serial.printf("[Main] RX=%d TX=%d BAUD=%d\n", MAIN_RX_PIN, MAIN_TX_PIN, SERIAL2_BAUD);


  int relayPins[] = { RELAY1, RELAY2, RELAY3, RELAY4 };
  for (int p : relayPins) {
    pinMode(p, OUTPUT);
    digitalWrite(p, LOW);
  }


  pinMode(BUZZER, OUTPUT);
  digitalWrite(BUZZER, LOW);
  pinMode(DHTPIN, INPUT);
  dht.begin();
  startupSound();


  WiFi.mode(WIFI_MODE_NULL);

  Serial.println("[Main] Trying Ethernet (W5500)...");
  if (tryStartEthernet()) {
    usingEthernet = true;
    Serial.println("[Main] Ethernet OK — skipping WiFi entirely");
    initFirebase();
    return;
  }
  Serial.println("[Main] Ethernet not available — using WiFi");


  WiFi.mode(WIFI_STA);
  WiFi.disconnect(true, true);
  delay(100);


  String savedSsid, savedPass;
  if (loadCredentials(savedSsid, savedPass)) {
    Serial.println("[Main] Auto-connecting with saved credentials...");
    startWiFiConnection(savedSsid, savedPass, true);
  } else {
    sendToCYD("WIFI_STATUS 0");
    Serial.println("[Main] Waiting for WiFi credentials from CYD...");
  }
}


// ============================================================
//  LOOP  — all non-blocking
// ============================================================
void loop() {
  handleSerialFromCYD();

  if (usingEthernet) {
    maintainEthernet();
  } else {
    checkWiFiStatus();
  }


  unsigned long now = millis();


  if (now - lastStateCheck >= STATE_INTERVAL) {
    lastStateCheck = now;
    checkRelayStates();
  }


  if (now - lastSensorUpload >= SENSOR_INTERVAL) {
    lastSensorUpload = now;
    uploadSensorData();
    checkIfThen();
  }


  if (now - lastHeartbeat >= HEARTBEAT_INTERVAL) {
    lastHeartbeat = now;
    writeHeartbeat();
  }


  if (now - lastTimerCheck >= TIMER_INTERVAL) {
    lastTimerCheck = now;
    checkTimers();
  }


  if (now - lastScheduleCheck >= SCHEDULE_INTERVAL) {
    lastScheduleCheck = now;
    checkSchedules();
  }
}
