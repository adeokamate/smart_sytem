#include <WiFi.h>
#include <HTTPClient.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <time.h>

// Pins
#define TRIG_PIN 5
#define ECHO_PIN 18
#define ONE_WIRE_BUS 4
#define BULB_PIN 19  // Relay module
#define FAN_PIN 21   // Motor fan (GPIO 5V control)

// WiFi credentials
//const char* ssid = "CoCIS Wireless";
//const char* password = "Stud3ntp@55";

const char* ssid = "KAMATE6C";
const char* password = "DEO256ega";

// Firebase Realtime DB
const char* firebaseHost = "https://the-sess-default-rtdb.europe-west1.firebasedatabase.app";

// NTP Server
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 0;  // Adjust for your timezone (e.g., 3600 for UTC+1)
const int daylightOffset_sec = 0;

OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);

void setup() {
  Serial.begin(115200);
  WiFi.begin(ssid, password);
  sensors.begin();

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(BULB_PIN, OUTPUT);
  pinMode(FAN_PIN, OUTPUT);

  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n✅ WiFi Connected");

  // Initialize NTP
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  Serial.println("🕐 NTP initialized");
  
  // Wait for time to be set
  Serial.print("Waiting for NTP time sync");
  while (!time(nullptr)) {
    delay(1000);
    Serial.print(".");
  }
  Serial.println("\n✅ Time synchronized");
}

// Function to get current timestamp in milliseconds since epoch
unsigned long long getCurrentTimestamp() {
  time_t now;
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("⚠️ Failed to obtain time");
    return 0;
  }
  time(&now); // now is seconds since epoch
  unsigned long long ms = (unsigned long long)now * 1000ULL;
  Serial.printf("[DEBUG] getCurrentTimestamp: now=%ld, ms=%llu\n", now, ms);
  return ms;
}

void loop() {
  sensors.requestTemperatures();
  float temperature = sensors.getTempCByIndex(0);

  // Handle sensor error
  bool tempValid = (temperature > -100.0 && temperature < 100.0);  // valid range check
  if (!tempValid) {
    Serial.println("⚠️ Temperature sensor error: Invalid reading (-127°C). Skipping this cycle.");
    return;  // skip rest of the loop cycle
  }

  // Measure distance
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  long duration = pulseIn(ECHO_PIN, HIGH, 30000);  // timeout 30ms

  float distance = -1;
  bool distValid = true;
  if (duration == 0) {
    Serial.println("⚠️ Ultrasonic sensor timeout!");
    distValid = false;
  } else {
    distance = duration * 0.034 / 2.0;
  }

  bool presenceDetected = distValid && (distance < 15.0);
  unsigned long long timestamp = getCurrentTimestamp(); // Use real Unix timestamp in ms

  // Log data only if sensors valid
  if (tempValid && distValid) {
    sendToFirebase(temperature, distance, timestamp);
  } else {
    Serial.println("❌ Skipping Firebase log due to sensor error.");
  }

  // Apply device control only if sensors valid
  if (tempValid && distValid) {
    applyDeviceControl(presenceDetected, temperature);
  } else {
    Serial.println("❌ Skipping device control due to sensor error.");
    // Optionally turn devices off if sensor error:
    digitalWrite(BULB_PIN, LOW);
    digitalWrite(FAN_PIN, LOW);
  }

  // Serial status output
  Serial.println("=========================");
  Serial.printf("🕓 Timestamp: %llu ms (Unix)\n", timestamp);
  Serial.printf("🌡️  Temperature: %.2f °C%s\n", temperature, tempValid ? "" : " (Invalid)");
  Serial.printf("📏 Distance: %.2f cm%s\n", distance, distValid ? "" : " (Invalid)");
  Serial.printf("👤 Presence Detected: %s\n", presenceDetected ? "YES" : "NO");
  Serial.println("=========================\n");

  delay(5000); // Wait before next cycle
}

void sendToFirebase(float temp, float dist, unsigned long long ts) {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(firebaseHost) + "/logs.json";

  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  String jsonData = "{\"temperature\":" + String(temp, 2) +
                    ",\"distance\":" + String(dist, 2) +
                    ",\"timestamp\":" + String(ts) + "}";

  int responseCode = http.POST(jsonData);
  if (responseCode > 0) {
    Serial.println("✅ Data sent: " + jsonData);
    Serial.println("Firebase response: " + http.getString());
  } else {
    Serial.println("❌ Send failed: " + http.errorToString(responseCode));
  }
  http.end();
}

void applyDeviceControl(bool presenceDetected, float temperature) {
  if (WiFi.status() != WL_CONNECTED) return;

  // Separate HTTPClient instance for GET request
  HTTPClient httpGet;
  String deviceUrl = String(firebaseHost) + "/devices.json";
  httpGet.begin(deviceUrl);
  int responseCode = httpGet.GET();

  String bulbStatus = "OFF";
  String fanStatus = "OFF";
  String bulbMode = "AUTO"; // default fallback
  String fanMode = "AUTO";  // default fallback

  if (responseCode == 200) {
    String payload = httpGet.getString();
    Serial.println("🔁 Device control response: " + payload);

    bulbMode = getValueFromJson(payload, "bulb");
    if (bulbMode != "ON" && bulbMode != "OFF" && bulbMode != "AUTO") {
      bulbMode = "AUTO";  // Default fallback is AUTO
    }
    fanMode = getValueFromJson(payload, "fan");
    if (fanMode != "ON" && fanMode != "OFF" && fanMode != "AUTO") {
      fanMode = "AUTO";  // Default fallback is AUTO
    }

    // Bulb control
    if (bulbMode == "AUTO") {
      if (presenceDetected) {
        digitalWrite(BULB_PIN, HIGH);
        bulbStatus = "ON";
      } else {
        digitalWrite(BULB_PIN, LOW);
        bulbStatus = "OFF";
      }
    } else if (bulbMode == "ON") {
      digitalWrite(BULB_PIN, HIGH);
      bulbStatus = "ON";
    } else {
      digitalWrite(BULB_PIN, LOW);
      bulbStatus = "OFF";
    }

    // Fan control
    if (fanMode == "AUTO") {
      if (presenceDetected && temperature > 25.0 && temperature < 100.0) {
        digitalWrite(FAN_PIN, HIGH);
        fanStatus = "ON";
      } else {
        digitalWrite(FAN_PIN, LOW);
        fanStatus = "OFF";
      }
    } else if (fanMode == "ON") {
      digitalWrite(FAN_PIN, HIGH);
      fanStatus = "ON";
    } else {
      digitalWrite(FAN_PIN, LOW);
      fanStatus = "OFF";
    }

  } else {
    Serial.println("❌ Failed to read device state: " + httpGet.errorToString(responseCode));
  }
  httpGet.end();

  // Separate HTTPClient instance for PUT request
  HTTPClient httpPut;
  String statusUrl = String(firebaseHost) + "/status.json";
  httpPut.begin(statusUrl);
  httpPut.addHeader("Content-Type", "application/json");

  String statusPayload = "{\"bulb\":\"" + bulbStatus + "\",\"fan\":\"" + fanStatus + "\"}";
  int statusCode = httpPut.PUT(statusPayload);

  if (statusCode > 0) {
    Serial.println("📤 Status updated: " + statusPayload);
  } else {
    Serial.println("❌ Status update failed: " + httpPut.errorToString(statusCode));
  }

  httpPut.end();

  // Serial friendly print of current mode and state
  Serial.printf("💡 Bulb: %s (Mode: %s)\n", bulbStatus.c_str(), bulbMode.c_str());
  Serial.printf("🌀 Fan:  %s (Mode: %s)\n", fanStatus.c_str(), fanMode.c_str());
}

// Extract string values from raw JSON (basic method for "bulb" or "fan")
String getValueFromJson(String json, String key) {
  int keyIndex = json.indexOf(key);
  if (keyIndex == -1) return "AUTO"; // default fallback

  int colonIndex = json.indexOf(':', keyIndex);
  int quoteStart = json.indexOf('"', colonIndex + 1);
  int quoteEnd = json.indexOf('"', quoteStart + 1);
  if (quoteStart == -1 || quoteEnd == -1) return "AUTO";

  return json.substring(quoteStart + 1, quoteEnd);
}
