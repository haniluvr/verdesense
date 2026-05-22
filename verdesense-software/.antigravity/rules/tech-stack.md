# Technical Architecture & Technology Stack

*Project Name:* CrowdSense: Intelligent Crowd Monitoring and Emergency Alert System
*Architecture Pattern:* IoT & Mobile Client (Serverless Cloud Architecture)
*Version:* 1.0 (Prototyping Phase)
*Deployment Status:* Development 

## 1. High-Level Architecture

The system follows a modernized, serverless IoT architecture divided into three primary layers:

1. *Hardware Layer (Edge/IoT):* ESP32 WROOM32D gathering physical sensor data (ToF, Flame, Gas, Temperature) and processing local logic.
2. *Cloud Layer (Backend):* Firebase acting as the serverless backend, handling data ingestion, persistent storage, and real-time state management via REST.
3. *Presentation Layer (Frontend):* Flutter mobile application providing real-time dashboards and emergency alerts to building administrators.

```mermaid
graph LR
    A[Sensors: ToF, Flame, Gas, Temp] --> B[ESP32 WROOM32D]
    B -- Wi-Fi / HTTP POST --> C[Firebase REST API]
    C -- Data Storage --> D[(Firebase Realtime DB / Firestore)]
    C -- HTTP GET / SDK --> E[Flutter Mobile App]