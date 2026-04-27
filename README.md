# 🤖 STEMBosque DSL

> **Un lenguaje de programación educativo para robótica**, diseñado para que niños y jóvenes aprendan lógica computacional controlando un robot virtual en español.

🚀 **¡Pruébalo ahora!**  
| Web | Android |
| :---: | :---: |
| [🌐 Abrir en el Navegador](https://sebastian542.github.io/Stem_Bosque/) | [🤖 Descargar APK (Actualizado)](https://github.com/Sebastian542/Stem_Bosque/releases/download/latest/app-release.apk) |

---

## 🌟 ¿Qué es STEMBosque DSL?

**STEMBosque DSL** es un *Domain-Specific Language* (Lenguaje de Dominio Específico) desarrollado con **Flutter**. Permite escribir programas en **español natural** para controlar un robot animado, facilitando el aprendizaje de variables, ciclos, condicionales y matemáticas de forma visual.

La versión web se actualiza automáticamente desde la rama `aleja` y corre **100% en el navegador** — sin instalaciones ni configuraciones complejas.

---

## ✨ Características

| Característica              | Descripción                                                                                   |
|-----------------------------|-----------------------------------------------------------------------------------------------|
| 🧠 **Compilador integrado** | Analizador léxico, sintáctico e intérprete desarrollado íntegramente en Dart                  |
| 🎨 **IDE moderno**          | Editor con resaltado de sintaxis, números de línea y detección de errores en tiempo real      |
| 🤖 **Robot animado**        | Visualización 2D donde el robot reacciona instantáneamente a tus instrucciones                |
| ⚙️ **CI/CD Automatizado**   | Despliegue continuo: los cambios en `aleja` se sincronizan con `main` y se publican en la web |
| 🔵 **Bluetooth Dual**       | Soporte para Bluetooth Clásico (SPP) y BLE para conexión con robots físicos (App móvil)       |
| 📂 **Gestión de archivos**  | Guarda y carga tus programas en formato `.txt` o `.sb`                                        |
| 💻 **Multiplataforma**      | Disponible para Web (GitHub Pages) y Android                                                  |

---

## 🚀 Cómo usar

### 🌐 Versión Web (Recomendado)
No necesitas instalar nada. Simplemente entra a:  
**[sebastian542.github.io/Stem_Bosque/](https://sebastian542.github.io/Stem_Bosque/)**

1. **Escribe** tu código en el editor.
2. Presiona el botón **Ejecutar** para ver al robot en acción.
3. Puedes **descargar** tus programas para usarlos más tarde.

### 📱 App Móvil (Android)
**[📥 Descargar APK para Android](https://github.com/Sebastian542/Stem_Bosque/releases/download/latest/app-release.apk)**

1. Escribe tu programa y valida la sintaxis en la barra de estado.
2. Usa el panel de **Bluetooth** para conectar con un robot físico.
3. Envía el código directamente al dispositivo mediante BLE o Serial.

---

## 🛠️ Flujo de Desarrollo (CI/CD)

Este proyecto utiliza **GitHub Actions** para garantizar que la versión web esté siempre al día:
1. Los desarrollos se realizan en la rama `aleja`.
2. Al hacer `push` a `aleja`, un workflow automatizado:
   - Sincroniza (merge) los cambios con la rama `main`.
   - Compila la versión **Flutter Web**.
   - Despliega el resultado en la rama `gh-pages` para actualizar el sitio público.

---

## 📖 Sintaxis del Lenguaje (Resumen)

```
PROGRAMA "Mi Cuadrado"
  LADO = 100
  REPETIR [4] VECES:
    AVANZAR LADO
    GIRAR 90
  FIN REPETIR
FIN PROGRAMA
```

*Para ver la documentación completa de la sintaxis y operadores, consulta las secciones inferiores de este documento.*

---

## 🏗️ Arquitectura (Flutter)

```
lib/
├── compiler/       — El corazón del lenguaje (Lexer, Parser, Intérprete)
├── ui/             — Interfaz de usuario (Editor, Consola, Botones)
└── widgets/        — Componentes visuales y manejo de Bluetooth
```

---

## 🔧 Notas de Instalación (Desarrolladores)

Si clonas el repositorio, recuerda que este proyecto utiliza:
- **Flutter SDK** (Canal estable)
- Dependencias para Bluetooth y manejo de archivos (ver `pubspec.yaml`)
- El parche de `namespace` para `flutter_bluetooth_serial` (ver sección de Errores Comunes).

---

© 2024 STEMBosque - Desarrollado con ❤️ para la educación tecnológica.
