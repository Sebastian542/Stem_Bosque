# 🤖 STEMBosque DSL (v1.0.0+1)

> **Un lenguaje de programación educativo para robótica**, diseñado para que niños y jóvenes aprendan lógica computacional controlando un robot virtual en español.

🚀 **¡Pruébalo ahora!**  
| Web | Android |
| :---: | :---: |
| [🌐 Abrir en el Navegador](https://sebastian542.github.io/Stem_Bosque/) | [🤖 Descargar APK (Actualizado)](https://github.com/Sebastian542/Stem_Bosque/releases/download/latest/app-release.apk) |

---

## 🌟 ¿Qué es STEMBosque DSL?

**STEMBosque DSL** es un *Domain-Specific Language* (Lenguaje de Dominio Específico) desarrollado con **Flutter**. Permite escribir programas en **español natural** para controlar un robot animado, facilitando el aprendizaje de variables, ciclos, condicionales y matemáticas de forma visual.

La versión web está optimizada para ejecutarse **100% en el navegador**, con un intérprete capaz de evaluar expresiones matemáticas complejas en tiempo real.

---

## ✨ Características Actualizadas

| Característica              | Descripción                                                                                   |
|-----------------------------|-----------------------------------------------------------------------------------------------|
| 🧠 **Compilador Potente**   | Ahora soporta expresiones aritméticas recursivas y funciones trigonométricas.                 |
| 📐 **Matemáticas Avanzadas**| Evaluación interna basada en `double`. Soporte para `+`, `-`, `*`, `/`, `SEN`, `COS` y `TANG`. |
| 🧩 **Modo Bloque**          | Nueva interfaz para configurar obstáculos y desafíos en la simulación (En desarrollo).        |
| 🎨 **Tema Dracula**         | Interfaz visual refinada basada en la paleta Dracula para reducir la fatiga visual.           |
| 🛡️ **Estabilidad**          | Protección contra ciclos infinitos (>400 repeticiones) y división por cero.                    |
| 🔵 **Bluetooth Dual**       | Gestión optimizada mediante Singletons para Bluetooth Clásico (SPP) y BLE.                    |
| ⚙️ **CI/CD Automatizado**   | Despliegue continuo via GitHub Actions con compatibilidad Web/Android asegurada.              |

---

## 📖 Sintaxis del Lenguaje (Novedades)

El lenguaje ha evolucionado para permitir lógica más compleja:

### Ejemplo de Expresiones y Trigonometría
```
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
- **Estructura**: `PROGRAMA "nombre" ... FIN PROGRAMA`
- **Movimiento**: `AVANZAR [expresión]`, `GIRAR [expresión]`
- **Control**: `SI [condición] ENTONCES ... FIN SI`, `REPETIR [veces] VECES: ... FIN REPETIR`
- **Variables**: `MI_VAR = 10 + (5 * SEN(45))`

---

## 🚀 Cómo usar

### 🌐 Versión Web
Simplemente entra a: **[sebastian542.github.io/Stem_Bosque/](https://sebastian542.github.io/Stem_Bosque/)**
- Soporta todas las funciones de programación y simulación.
- **Nota**: El soporte Bluetooth en Web es experimental (requiere navegador compatible con Web Bluetooth).

### 📱 App Móvil (Android)
**[📥 Descargar APK](https://github.com/Sebastian542/Stem_Bosque/releases/download/latest/app-release.apk)**
- Control total de robots físicos vía Bluetooth.
- Gestión de archivos locales para guardar tus proyectos.

---

## 🏗️ Arquitectura Técnica

- **Patrón Singleton**: Acceso unificado a recursos mediante `BluetoothManager.instance` y `FileManager.instance`.
- **AST Refactorizado**: Los nodos del árbol sintáctico ahora son dinámicos, permitiendo que cualquier comando acepte una expresión matemática en lugar de solo valores fijos.
- **Compatibilidad**: Manejo de parámetros `onUnsupported` para evitar crashes en plataformas sin APIs específicas (como Bluetooth en Web).

---

## 🔧 Contribución y Desarrollo

1. Clona el repo: `git clone https://github.com/Sebastian542/Stem_Bosque.git`
2. Instala dependencias: `flutter pub get`
3. Ejecuta en modo debug: `flutter run`

*Nota para builds Web: Usar `flutter build web --release --no-wasm-dry-run` para evitar advertencias de incompatibilidad de librerías nativas con WebAssembly.*

---

© 2024 STEMBosque - Desarrollado con ❤️ para la educación tecnológica.
