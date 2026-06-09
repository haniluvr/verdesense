# VerdeSense: Real-Time IoT Hazard Detection & Occupancy Monitoring for Smart Greenhouses

**VerdeSense** is an integrated Internet of Things (IoT) and cloud-based ecosystem designed to monitor safety and occupancy in controlled agricultural greenhouses. The system actively detects environmental hazards such as smoke, gas, and fire in real-time, while simultaneously tracking the number of personnel inside the greenhouse to ensure safety and operational efficiency. 

By combining an ESP32-based hardware node with a cross-platform Flutter application and Firebase cloud infrastructure, VerdeSense provides automated local sirens, real-time dashboards, and robust historical data logging.

---

## 🚀 Features

- **Real-Time Hazard Detection:** Utilizes MQ gas sensors and flame sensors to detect smoke, harmful gases, and fire within the greenhouse environment.
- **Occupancy Monitoring:** Employs advanced VL53L7CX / VL53L8CX Time-of-Flight (ToF) multi-zone sensors to accurately count people entering and exiting the premises using multi-lane tracking algorithms.
- **Environmental Monitoring:** Tracks real-time ambient temperature using Dallas DS18B20 sensors.
- **Automated Emergency Systems:** Auto-triggers local evacuation sirens and visual alerts when hazards are detected. Automatically transitions to a "Safety / Clear" mode once hazards subside and personnel are evacuated.
- **Cross-Platform Dashboard:** A unified Flutter application (Mobile, Web, Desktop) providing a real-time overview of temperature, gas levels, flame status, and occupancy counts.
- **Power & Connectivity Resilience:** Built-in UPS/battery voltage monitoring for the IoT devices to ensure continuous operation, along with auto-reconnection logic for WiFi and Firebase.

---

## 🛠️ Technologies Used

### Software (Frontend & Cloud)
* **Flutter & Dart**: Cross-platform application framework.
* **Provider**: State management.
* **Fl_chart**: Real-time data visualization and graphing.
* **Firebase Realtime Database (RTDB)**: Low-latency cloud synchronization between IoT nodes and the frontend.
* **Firebase Authentication & Firestore**: User management and application data storage.
* **Cloud Functions**: Serverless backend execution.

### Hardware (IoT)
* **Microcontroller**: ESP32 (programmed via Arduino C++).
* **Sensors**: 
  * VL53L7CX / VL53L8CX (ToF Occupancy Sensors)
  * DS18B20 (Temperature)
  * MQ Series (Gas/Smoke)
  * Digital/Analog Flame Sensors
* **Libraries**: `Firebase_ESP_Client`, `WiFiManager`, `NTPClient`, `OneWire`, `DallasTemperature`.

---

## 💻 Installation Instructions (Software)

To run the Flutter application locally:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-repo/verde-sense.git
   cd verde-sense/verdesense-software
   ```

2. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

3. **Environment Setup:**
   * Duplicate the `.env.example` file and rename it to `.env`.
   * Fill in your Firebase and other necessary environment variables.

4. **Run the Application:**
   ```bash
   flutter run
   ```
   *(Supports Android, iOS, Web, Windows, macOS, and Linux)*

---

## 🔌 Hardware Setup (IoT Devices)

1. **Prepare the IDE:**
   * Install the Arduino IDE.
   * Add the ESP32 board manager URL to your IDE preferences and install the ESP32 boards.

2. **Install Required Libraries:**
   * Install the following via the Arduino Library Manager: `Firebase ESP Client`, `WiFiManager`, `NTPClient`, `OneWire`, `DallasTemperature`.
   * For the ToF sensors, install the STMicroelectronics `VL53L7CX` or `VL53L8CX` library depending on your hardware revision.

3. **Flash the Firmware:**
   * Navigate to `verdesense-hardware/crowdsense_7CX` (or `8CX`).
   * Open the `.ino` file in Arduino IDE.
   * Connect your ESP32 via USB and select the appropriate COM port.
   * Click **Upload**.

4. **Network Provisioning (WiFiManager):**
   * On first boot, the ESP32 will fail to find a known WiFi network and fall back to Access Point (AP) mode.
   * Connect your smartphone/laptop to the WiFi network named **CrowdSense_Main_Ent** (or **CrowdSense_Parking**).
   * A captive portal will appear (or navigate to `192.168.4.1`). Enter your local WiFi credentials to connect the device to the internet.
   
5. **Cloud Synchronization:**
   * Once connected to WiFi, the device will sync time via NTP and automatically begin streaming sensor data to the configured Firebase Realtime Database.
