#include <WiFi.h>
#include <FirebaseESP32.h>
#include <OneWire.h>
#include <DallasTemperature.h>

// Wi-Fi credentials
#define WIFI_SSID "WAVE6C"
#define WIFI_PASSWORD "DEO256ega"

// Firebase settings
#define FIREBASE_HOST "https://the-sess-default-rtdb.europe-west1.firebasedatabase.app/"
#define FIREBASE_AUTH "ZL22Ro5sGkh0DypKY2vhkagnKj9PZrvxQkSNaMqL"

// Pins
#define BULB_RELAY_PIN 4
#define FAN_CONTROL_PIN 5
#define TRIG_PIN 14
#define ECHO_PIN 27
#define TEMP_SENSOR_PIN 18

// Firebase objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Temperature sensor
OneWire oneWire(TEMP_SENSOR_PIN);
DallasTemperature sensors(&oneWire);

void setup() {
  Serial.begin(9600);

  // Pin Modes
  pinMode(BULB_RELAY_PIN, OUTPUT);
  pinMode(FAN_CONTROL_PIN, OUTPUT);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  digitalWrite(BULB_RELAY_PIN, LOW);
  digitalWrite(FAN_CONTROL_PIN, LOW);

  // WiFi Connect
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  unsigned long startAttemptTime = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startAttemptTime < 15000) {
    Serial.print(".");
    delay(500);
  }
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\n❌ WiFi connection failed.");
  } else {
    Serial.println("\n✅ WiFi connected");
  }

  // Firebase Config
  config.database_url = FIREBASE_HOST;
  config.api_key = FIREBASE_AUTH;

  // Begin Firebase
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // Start DS18B20
  sensors.begin();
  Serial.println("✅ Firebase and sensors initialized");
}

void loop() {
  // Status Checks
  Serial.println(WiFi.status() == WL_CONNECTED ? "✅ WiFi OK" : "❌ WiFi FAIL");
  Serial.println(Firebase.ready() ? "✅ Firebase OK" : "❌ Firebase FAIL");

  // Read Temperature
  sensors.requestTemperatures();
  float tempC = sensors.getTempCByIndex(0);
  Serial.print("Temperature: ");
  Serial.print(tempC);
  Serial.println(" °C");

  // Read Distance
  long duration, distanceCM;
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  duration = pulseIn(ECHO_PIN, HIGH);
  distanceCM = duration * 0.034 / 2;
  Serial.print("Distance: ");
  Serial.print(distanceCM);
  Serial.println(" cm");

  // Read Firebase Commands
  String bulbOverride = "OFF";
  String fanOverride = "OFF";

  if (Firebase.getString(fbdo, "/devices/bulb")) {
    bulbOverride = fbdo.stringData();
  } else {
    Serial.println("Failed to get bulb override");
  }

  if (Firebase.getString(fbdo, "/devices/fan")) {
    fanOverride = fbdo.stringData();
  } else {
    Serial.println("Failed to get fan override");
  }

  // Control Bulb
  bool bulbIsOn = false;
  if (bulbOverride == "ON" || (bulbOverride == "AUTO" && distanceCM <= 15)) {
    digitalWrite(BULB_RELAY_PIN, HIGH);
    bulbIsOn = true;
  } else {
    digitalWrite(BULB_RELAY_PIN, LOW);
  }

  // Control Fan
  bool fanIsOn = false;
  if (fanOverride == "ON" || (fanOverride == "AUTO" && tempC >= 25 && distanceCM <= 15)) {
    digitalWrite(FAN_CONTROL_PIN, HIGH);
    fanIsOn = true;
  } else {
    digitalWrite(FAN_CONTROL_PIN, LOW);
  }

  // Update Firebase Status
  Firebase.setString(fbdo, "/status/bulb", bulbIsOn ? "ON" : "OFF");
  Firebase.setString(fbdo, "/status/fan", fanIsOn ? "ON" : "OFF");

  // Update Sensor Metrics
  Firebase.setFloat(fbdo, "/metrics/temperature", tempC);
  Firebase.setInt(fbdo, "/metrics/distance", distanceCM);

  delay(2000);
}
