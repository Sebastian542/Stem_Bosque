# 🤖 STEMBosque DSL (v1.0.0+1)

> **Un lenguaje de programación educativo para robótica**, diseñado para que niños y jóvenes aprendan lógica computacional controlando un robot virtual en español.

🚀 **¡Pruébalo ahora!**

| Web | Android | iPhone |
| :---: | :---: | :---: |
| [🌐 Abrir en el Navegador](https://sebastian542.github.io/Stem_Bosque/) | [🤖 Descargar APK](https://github.com/Sebastian542/Stem_Bosque/releases/download/latest/app-release.apk) | [🍎 Descargar IPA](https://github.com/Sebastian542/Stem_Bosque/releases/download/latest/app.ipa) |

---

## 🌟 ¿Qué es STEMBosque DSL?

**STEMBosque DSL** es un *Domain-Specific Language* (Lenguaje de Dominio Específico) desarrollado con **Flutter**. Permite escribir programas en **español natural** para controlar un robot animado, facilitando el aprendizaje de variables, ciclos, condicionales y matemáticas de forma visual.

La versión web está optimizada para ejecutarse **100% en el navegador**, con un intérprete capaz de evaluar expresiones matemáticas complejas en tiempo real.

---

## ✨ Características Actualizadas

| Característica              | Descripción |
|-----------------------------|-------------|
| 🧠 **Compilador Potente**   | Soporta expresiones aritméticas recursivas y funciones trigonométricas. |
| 📐 **Matemáticas Avanzadas**| Soporte para `+`, `-`, `*`, `/`, `SEN`, `COS` y `TANG`. |
| 🧩 **Modo Bloque**          | Configuración visual de obstáculos y desafíos (En desarrollo). |
| 🎨 **Tema Dracula**         | Interfaz visual refinada y cómoda para largas sesiones. |
| 🛡️ **Estabilidad**          | Protección contra ciclos infinitos y división por cero. |
| 🔵 **Bluetooth Dual**       | Compatibilidad BLE y Bluetooth clásico optimizada. |
| ⚙️ **CI/CD Automatizado**   | Builds automáticos para Web, Android e iOS mediante GitHub Actions. |

---

## 📖 Sintaxis del Lenguaje

### Ejemplo

```stembosque
PROGRAMA "Círculo Matemático"
  RADIO = 50
  ANGULO = 0

  REPETIR [36] VECES:
    PASO = 2 * 3.1416 * RADIO / 36
    AVANZAR PASO
    GIRAR 10
  FIN REPETIR

FIN PROGRAMA
```

### Comandos Soportados

- **Estructura**:
  - `PROGRAMA`
  - `FIN PROGRAMA`

- **Movimiento**:
  - `AVANZAR [expresión]`
  - `GIRAR [expresión]`

- **Control**:
  - `SI [condición] ENTONCES`
  - `FIN SI`
  - `REPETIR [veces] VECES`

- **Variables**:
  - `MI_VAR = 10 + (5 * SEN(45))`

---

## 🚀 Cómo usar

### 🌐 Versión Web

👉 https://sebastian542.github.io/Stem_Bosque/

- Simulación completa en navegador.
- Compatible con escritorio y móviles.
- Bluetooth Web experimental.

---

### 📱 Android

👉 Descarga el APK:

https://github.com/Sebastian542/Stem_Bosque/releases/download/latest/app-release.apk

- Compatible con Bluetooth clásico.
- Instalación directa mediante APK.

---

### 🍎 iPhone / iOS

👉 Descarga el IPA:

https://github.com/Sebastian542/Stem_Bosque/releases/download/latest/app.ipa

> Requiere instalación mediante TestFlight, AltStore o firma manual en iOS.

---

## 🏗️ Arquitectura Técnica

- **Singleton Pattern**
  - `BluetoothManager.instance`
  - `FileManager.instance`

- **AST Dinámico**
  - Expresiones matemáticas en cualquier nodo sintáctico.

- **Compatibilidad Multiplataforma**
  - Manejo de APIs no soportadas sin crashes.

---

## 🔧 Desarrollo

### Clonar proyecto

```bash
git clone https://github.com/Sebastian542/Stem_Bosque.git
```

### Instalar dependencias

```bash
flutter pub get
```

### Ejecutar

```bash
flutter run
```

### Build Web

```bash
flutter build web --release
```

### Build Android

```bash
flutter build apk --release
```

### Build iOS

```bash
flutter build ipa
```

---

## ⚙️ CI/CD

El proyecto utiliza:

- GitHub Actions
- GitHub Pages
- Releases automáticos
- Build multiplataforma Flutter

---

© 2026 STEMBosque — Desarrollado con ❤️ para la educación tecnológica.
