# 🤖 STEMBosque DSL (v1.1.0)

### ✍️ Autores
- **Sebastian** ([@Sebastian542](https://github.com/Sebastian542))
- **Alejandra** ([@Aleja2](https://github.com/aleja2))
- **Julio** ([@Julio123422](https://github.com/ProgramadorMermelada)
  
> **Un entorno de desarrollo integrado (IDE) para robótica educativa**, diseñado para que niños y jóvenes aprendan lógica computacional mediante un lenguaje natural (DSL) en español y una simulación interactiva.

🚀 **¡Pruébalo ahora!**

| Web (Wasm) | Android (APK) | iPhone (IPA) |
| :---: | :---: | :---: |
| [🌐 Abrir IDE Web](https://sebastian542.github.io/Stem_Bosque/) | [🤖 Descargar APK](https://github.com/Sebastian542/Stem_Bosque/releases/download/latest/app-release.apk) | [🍎 Descargar IPA](https://github.com/Sebastian542/Stem_Bosque/releases/download/latest/app.ipa) |

---

## 📑 Tabla de Contenidos

- [¿Qué es STEMBosque?](#-qué-es-stembosque)
- [Características Principales](#-características-principales)
- [El Lenguaje DSL](#-el-lenguaje-dsl)
- [Arquitectura del Compilador](#-arquitectura-del-compilador)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Módulos y Servicios](#-módulos-y-servicios)
- [Pantallas de la Aplicación](#-pantallas-de-la-aplicación)
- [Modelo de Datos (Firestore)](#-modelo-de-datos-firestore)
- [Conectividad Bluetooth](#-conectividad-bluetooth)
- [Tecnologías](#-tecnologías)
- [Dependencias](#-dependencias)
- [Configuración de Desarrollo](#-configuración-de-desarrollo)
- [Compilación por Plataforma](#-compilación-por-plataforma)
- [CI/CD (GitHub Actions)](#-cicd-github-actions)

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

### Palabras Clave del Lenguaje
| Categoría | Palabras reservadas |
|-----------|---------------------|
| Estructura | `PROGRAMA`, `FIN` |
| Movimiento | `AVANZAR`, `GIRAR` |
| Condicionales | `SI`, `ENTONCES` |
| Bucles | `REPETIR`, `VECES` |
| Trigonometría | `SEN`, `COS`, `TANG` |
| Operadores lógicos | `AND`, `OR`, `NOT` |

### Comentarios
El lenguaje admite comentarios de línea (`// ...`) y de bloque (`/* ... */`), que son ignorados por el analizador léxico.

### Comandos Personalizados
Además de las palabras reservadas, los usuarios autenticados pueden **crear comandos personalizados** (por ejemplo `SALTAR`) que se expanden internamente a una secuencia de comandos básicos. Estos comandos se almacenan en Firestore y se inyectan en el compilador en tiempo de ejecución.

---

## 🏗️ Arquitectura del Compilador

El DSL se procesa mediante un pipeline de compilación clásico. El orquestador es la clase `Compilador` (`lib/compiler/compiler.dart`), que produce un objeto `ResultadoCompilacion` con tokens, AST, salida de ejecución y código generado (o un error).

```
Código fuente (String)
        │
        ▼
┌───────────────────┐
│  AnalizadorLexico │  lib/compiler/lexer/lexer.dart
│     (Lexer)       │  → Convierte el texto en una lista de Tokens
└───────────────────┘
        │  List<Token>
        ▼
┌───────────────────┐
│      Parser       │  lib/compiler/parser/parser.dart
│                   │  → Construye el AST (Árbol de Sintaxis Abstracta)
└───────────────────┘
        │  Nodos AST (lib/compiler/ast/nodes.dart)
        ├───────────────────────────┐
        ▼                           ▼
┌───────────────────┐     ┌───────────────────┐
│    Interprete     │     │  GeneradorCodigo  │
│  (ejecución)      │     │   (codegen)       │
│ → salida/simulación│     │ → código generado │
└───────────────────┘     └───────────────────┘
```

Adicionalmente, el `SyntaxValidator` (`lib/compiler/syntax_validator.dart`) alimenta la validación en tiempo real del editor, mostrando errores mientras el usuario escribe.

| Etapa | Archivo | Responsabilidad |
|-------|---------|-----------------|
| Léxico | `compiler/lexer/lexer.dart` | Tokeniza la fuente; reconoce palabras clave, números, símbolos y comentarios. |
| Tokens | `compiler/models/token.dart` | Define `Token` y `TipoToken`. |
| Sintáctico | `compiler/parser/parser.dart` | Construye el AST a partir de los tokens. |
| AST | `compiler/ast/nodes.dart` | Nodos del árbol de sintaxis. |
| Ejecución | `compiler/interpreter/interpreter.dart` | Evalúa el AST y produce la salida/simulación. |
| Generación | `compiler/codegen/code_generator.dart` | Traduce el AST a código de salida. |
| Validación | `compiler/syntax_validator.dart` | Validación en vivo para el editor. |

---

## 📂 Estructura del Proyecto

```
Stem_Bosque/
├── lib/
│   ├── main.dart                    # Punto de entrada; inicializa Firebase y la app
│   ├── firebase_options.dart        # Configuración generada de Firebase
│   │
│   ├── compiler/                    # Núcleo del lenguaje DSL
│   │   ├── compiler.dart            # Orquestador del pipeline de compilación
│   │   ├── syntax_validator.dart    # Validación de sintaxis en tiempo real
│   │   ├── lexer/lexer.dart         # Analizador léxico
│   │   ├── parser/parser.dart       # Analizador sintáctico (AST)
│   │   ├── ast/nodes.dart           # Definición de nodos del AST
│   │   ├── interpreter/interpreter.dart  # Intérprete/evaluador
│   │   ├── codegen/code_generator.dart   # Generador de código
│   │   └── models/token.dart        # Tokens y tipos de token
│   │
│   ├── bluetooth/                   # Conectividad con hardware
│   │   ├── bluetooth_manager.dart   # Gestión de conexiones (Clásico + BLE)
│   │   └── bluetooth_device.dart    # Modelo de dispositivo
│   │
│   ├── services/                    # Servicios de negocio e infraestructura
│   │   ├── auth_service.dart        # Autenticación (Firebase Auth)
│   │   ├── database_service.dart    # Persistencia (Cloud Firestore)
│   │   ├── file_manager.dart        # Gestión de archivos (nativo)
│   │   ├── file_manager_stub.dart   # Stub para plataformas sin FS nativo
│   │   └── web_downloader.dart      # Descarga de archivos en Web
│   │
│   ├── models/                      # Modelos de datos
│   │   ├── user_model.dart          # Usuario y roles
│   │   ├── project_model.dart       # Proyecto (código + obstáculos)
│   │   └── command_model.dart       # Comando personalizado
│   │
│   ├── utils/
│   │   └── file_utils.dart          # Utilidades de archivos
│   │
│   └── ui/                          # Capa de presentación
│       ├── screens/                 # Pantallas de la app
│       ├── widgets/                 # Componentes reutilizables
│       ├── theme/app_theme.dart     # Tema visual (modo oscuro)
│       └── utils/                   # Escalado y responsividad
│
├── assets/images/                   # Recursos (mascota "Tita", etc.)
├── android/ · ios/ · web/           # Proyectos nativos por plataforma
├── .github/workflows/               # Pipelines de CI/CD
└── pubspec.yaml                     # Dependencias y configuración Flutter
```

---

## 🧩 Módulos y Servicios

### Servicios (`lib/services/`)
- **`AuthService`**: Registro (`signUp`), inicio de sesión (`signIn`) y cierre de sesión con Firebase Auth. Al registrarse crea el perfil del usuario en Firestore con rol inicial `nuevo usuario`; al iniciar sesión actualiza `lastLogin`. Incluye manejo tolerante a fallos de red/permisos para no bloquear el acceso.
- **`DatabaseService`**: Persistencia en Firestore. Guarda proyectos por usuario (`saveProject`), los lee en tiempo real (`getMyProjects`), y gestiona comandos personalizados globales (`getCustomCommands`, `saveCustomCommand`).
- **`FileManager` / `FileManagerStub` / `WebDownloader`**: Importación/exportación de programas. La implementación se selecciona según la plataforma (nativo vs. web).

### Compilador (`lib/compiler/`)
Núcleo del lenguaje descrito en [Arquitectura del Compilador](#-arquitectura-del-compilador).

### Bluetooth (`lib/bluetooth/`)
Gestión unificada de conexiones para enviar comandos a robots físicos.

---

## 🖥️ Pantallas de la Aplicación

Ubicadas en `lib/ui/screens/`:

| Pantalla | Archivo | Función |
|----------|---------|---------|
| IDE principal | `ide_screen.dart` | Editor de código, punto de entrada de la app. |
| Simulación | `simulation_screen.dart` | Visualización del robot ejecutando el programa. |
| Modo Bloque | `block_mode_screen.dart` | Colocación visual de obstáculos en la escena. |
| Control Remoto | `remote_control_screen.dart` | Mando directo del robot. |
| Login | `login_screen.dart` | Autenticación de usuarios. |
| Creador de Comandos | `command_creator_screen.dart` | Definición de comandos personalizados. |
| Explorador Cloud | `cloud_explorer_screen.dart` | Navegación y carga de proyectos guardados. |
| Panel de Admin | `admin_panel_screen.dart` | Administración (gestión de usuarios/roles). |

Componentes destacados (`lib/ui/widgets/`): editor con validación (`code_editor_validated.dart`), barra de herramientas (`toolbar.dart`), panel Bluetooth (`bluetooth_panel.dart`), consola de ejecución (`execution_console.dart`), asistente visual **Tita** (`tita.dart`), diálogos de ayuda y pantalla de permisos.

---

## 🗄️ Modelo de Datos (Firestore)

```
users/{uid}
  ├── uid, name, email, role, createdAt, lastLogin
  └── projects/{nombreProyecto}
        └── name, code, obstacles[], updatedAt

custom_commands/{autoId}
  └── keyword, description, script, createdBy, createdAt
```

### Modelos
- **`UserModel`**: `uid`, `email`, `name`, `role`, `createdAt`, `lastLogin`.
- **`ProjectModel`**: `id`, `name`, `code` (DSL), `obstacles` (posiciones del Modo Bloque), `createdAt`, `updatedAt`.
- **`CustomCommand`**: `keyword` (en mayúsculas), `description`, `script` (comandos básicos que ejecuta), `createdBy`.

### Roles de Usuario
El campo `role` admite: `nuevo usuario` (por defecto), `student`, `teacher`, `admin`. El rol determina el acceso a funcionalidades como el Panel de Administración.

---

## 🔵 Conectividad Bluetooth

STEMBosque soporta **dos tecnologías** para conectar con robots reales, seleccionadas según la plataforma:

- **Bluetooth Clásico** (`flutter_bluetooth_serial`): principalmente en Android.
- **Bluetooth Low Energy / BLE** (`flutter_blue_plus`): para Web y móvil.

El módulo requiere permisos de ubicación/Bluetooth en móvil, gestionados mediante `permission_handler` y la pantalla `permission_request_screen.dart`.

---

## 🛠️ Tecnologías

- **Lenguaje**: Dart / Flutter
- **Backend**: Firebase (Auth & Firestore)
- **Compilación**: Web (Wasm/CanvasKit), Android, iOS.
- **Librerías Clave**: `flutter_blue_plus`, `share_plus` (v10+), `google_fonts`, `flutter_animate`.

---

## 📦 Dependencias

Definidas en `pubspec.yaml` (Dart SDK `>=3.0.0 <4.0.0`).

### Principales
| Paquete | Uso |
|---------|-----|
| `firebase_core`, `firebase_auth`, `cloud_firestore` | Backend, autenticación y base de datos en la nube. |
| `flutter_bluetooth_serial`, `flutter_blue_plus` | Conectividad Bluetooth Clásico y BLE. |
| `permission_handler` | Gestión de permisos en tiempo de ejecución. |
| `file_picker`, `path_provider` | Selección y rutas de archivos. |
| `share_plus`, `url_launcher`, `android_intent_plus` | Compartir contenido e integraciones del sistema. |
| `local_auth` | Autenticación biométrica local. |
| `google_fonts`, `flutter_animate` | Tipografías y animaciones de la UI. |
| `cupertino_icons` | Iconografía. |

### Desarrollo
- `flutter_test` — pruebas.
- `flutter_lints` — análisis estático / linting.

### Nota de compatibilidad
Se fija `permission_handler_html: 0.1.3+5` mediante `dependency_overrides` porque la versión `0.1.4+0` usa `isA()` sobre `Object` (disponible solo en Dart 3.12+), lo que rompe la compilación en Web con Dart 3.11.

---

## 🔧 Configuración de Desarrollo

1. **Clonar**: `git clone https://github.com/Sebastian542/Stem_Bosque.git`
2. **Dependencias**: `flutter pub get`
3. **Ejecutar**: `flutter run` (Compatible con Windows, Web, Android e iOS).

> **Firebase**: la app inicializa Firebase al arrancar (`main.dart`) usando `firebase_options.dart`. Si vas a usar tu propio proyecto Firebase, regenera este archivo con `flutterfire configure`.

---

## 🏗️ Compilación por Plataforma

```bash
# Web (Wasm)
flutter build web --wasm

# Android (APK)
flutter build apk --release

# iOS (sin firma, empaquetado manual)
flutter build ios --release --no-codesign
```

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
