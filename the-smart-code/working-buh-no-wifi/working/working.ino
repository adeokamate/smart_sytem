#include <OneWire.h>
#include <DallasTemperature.h>

// Pin definitions
#define BULB_RELAY_PIN 4         // Relay for bulb 
#define FAN_CONTROL_PIN 5        // Fan via transistor
#define TRIG_PIN 14              // Ultrasonic TRIG
#define ECHO_PIN 27              // Ultrasonic ECHO
#define TEMP_SENSOR_PIN 18       // DS18B20 data pin

// Setup DS18B20
OneWire oneWire(TEMP_SENSOR_PIN);
DallasTemperature sensors(&oneWire);

void setup() {
  Serial.begin(9600);

  pinMode(BULB_RELAY_PIN, OUTPUT);
  pinMode(FAN_CONTROL_PIN, OUTPUT);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);

  digitalWrite(BULB_RELAY_PIN, LOW);
  digitalWrite(FAN_CONTROL_PIN, LOW);

  sensors.begin();

  Serial.println("✅ Sensors initialized. Automatic control started...");
}

void loop() {
  // === Read temperature ===
  sensors.requestTemperatures();
  float tempC = sensors.getTempCByIndex(0);
  Serial.print("Temperature: ");
  Serial.print(tempC);
  Serial.println(" °C");

  // === Read distance from ultrasonic ===
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

  // === Bulb control ===
  if (distanceCM <= 15) {
    digitalWrite(BULB_RELAY_PIN, HIGH);
    Serial.println("💡 Bulb: ON (Presence Detected)");
  } else {
    digitalWrite(BULB_RELAY_PIN, LOW);
    Serial.println("💡 Bulb: OFF (No Presence)");
  }

  // === Fan control (needs both presence AND high temperature) ===
  if (tempC >= 24.1 && distanceCM <= 15) {
    digitalWrite(FAN_CONTROL_PIN, HIGH);
    Serial.println("🌀 Fan: ON (Hot + Presence)");
  } else {
    digitalWrite(FAN_CONTROL_PIN, LOW);
    Serial.println("🌀 Fan: OFF (Cool or No Presence)");
  }

  Serial.println("--------------------------------------");

  delay(2000); // every 2 seconds
}
