# 🤖 STEMBosque DSL (v1.1.0)

### ✍️ Autores
- **Sebastian** ([@Sebastian542](https://github.com/Sebastian542))
- **Alejandra** ([@Aleja2](https://github.com/aleja2))

> **Un entorno de desarrollo integrado (IDE) para robótica educativa**, diseñado para que niños y jóvenes aprendan lógica computacional mediante un lenguaje natural (DSL) en español y una simulación interactiva.

🚀 **¡Pruébalo ahora!**

| Web (Wasm) | Android (APK) | iPhone (IPA) |
| :---: | :---: | :---: |
| [🌐 Abrir IDE Web](https://sebastian542.github.io/Stem_Bosque/) | [🤖 Descargar APK](https://github.com/Sebastian542/Stem_Bosque/releases/download/latest/app-release.apk) | [🍎 Descargar IPA](https://github.com/Sebastian542/Stem_Bosque/releases/download/latest/app.ipa) |

---

## 🌟 ¿Qué es STEMBosque?

**STEMBosque** es una plataforma educativa multiplataforma desarrollada con **Flutter**. Su núcleo es un **lenguaje de dominio específico (DSL)** que permite programar un robot virtual utilizando sintaxis en español. El proyecto integra persistencia en la nube mediante **Firebase**, sincronización en tiempo real y capacidades de comunicación via **Bluetooth**.

---

## ✨ Características Principales

| Característica              | Descripción |
|-----------------------------|-------------|
| 🧠 **Intérprete Avanzado**  | Evaluación de expresiones matemáticas, trigonométricas y lógicas (`AND`, `OR`, `NOT`). |
| ☁️ **Sincronización Cloud**  | Persistencia de programas y configuración de obstáculos mediante Firestore. |
| 🧩 **Modo Bloque & DSL**    | Edición dual: escribe código o coloca obstáculos visualmente en la simulación. |
| 🎨 **Editor Inteligente**   | Resaltado de sintaxis dinámico, sugerencias automáticas y validación en tiempo real. |
| 🔵 **Bluetooth Dual**       | Soporte para Bluetooth Clásico (Android) y BLE (Web/Móvil) para conectar con hardware real. |
| 🕹️ **Control Remoto**       | Interfaz de mando directo para el robot integrada en la app. |
| ⚙️ **CI/CD Robusto**        | Despliegue automatizado a GitHub Pages y generación de instaladores para todas las plataformas. |

---

## 📖 El Lenguaje DSL

La sintaxis está diseñada para ser legible y educativa:

```stembosque
PROGRAMA "Prueba Logica"
  SI DISTANCIA < 20 AND NOT OBSTACULO ENTONCES
    GIRAR 90
    AVANZAR 50
  FIN SI
  
  REPETIR 4 VECES:
    AVANZAR 100
    GIRAR 90
  FIN REPETIR
FIN PROGRAMA
```

### Funciones Disponibles
- **Movimiento**: `AVANZAR`, `GIRAR`.
- **Matemáticas**: `+`, `-`, `*`, `/`, `SEN()`, `COS()`, `TANG()`.
- **Lógica**: `AND`, `OR`, `NOT`, `>`, `<`, `=`, `!=`.
- **Sensores Virtuales**: `DISTANCIA`, `OBSTACULO`, `PISO`.

---

## 🛠️ Tecnologías

- **Lenguaje**: Dart / Flutter
- **Backend**: Firebase (Auth & Firestore)
- **Compilación**: Web (Wasm/CanvasKit), Android, iOS.
- **Librerías Clave**: `flutter_blue_plus`, `share_plus` (v10+), `google_fonts`, `flutter_animate`.

---

## 🔧 Configuración de Desarrollo

1. **Clonar**: `git clone https://github.com/Sebastian542/Stem_Bosque.git`
2. **Dependencias**: `flutter pub get`
3. **Ejecutar**: `flutter run` (Compatible con Windows, Web, Android e iOS).

---

## ⚙️ CI/CD (GitHub Actions)

El proyecto cuenta con un flujo automatizado que:
1. Sincroniza ramas de desarrollo (`aleja2` -> `main`).
2. Compila la versión **Web** y la despliega en GitHub Pages.
3. Genera el **APK** de Android.
4. Genera el **IPA** de iOS (sin firma, empaquetado manual).
5. Crea un **Release** automático con todos los artefactos.

---

© 2026 STEMBosque — Innovación en Educación Tecnológica.
