# 🤖 STEMBosque DSL (v1.0.0)

### ✍️ Autores
- **Sebastian** ([@Sebastian542](https://github.com/Sebastian542))
- **Alejandra** ([@Aleja2](https://github.com/aleja2))
- **Julio** ([@JulioSalazar](https://github.com/ProgramadorMermelada))
  
> **Un entorno de desarrollo integrado (IDE) para robótica educativa**, diseñado para que niños y jóvenes aprendan lógica computacional mediante un lenguaje natural (DSL) en español y una simulación interactiva.

🚀 **¡Pruébalo ahora!**

| Web | Android (APK) | iPhone (IPA) |
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
- [Interfaz adaptativa](#-interfaz-adaptativa)
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
| 🎨 **Editor Inteligente**   | Resaltado de sintaxis (incluye comentarios `/* */` de varias líneas), sugerencias con texto fantasma y validación en tiempo real. |
| 🦦 **Tita, la guía**        | La mascota cuenta los errores en una insignia, los lista al tocarla y lleva el cursor a la línea del error. |
| 💬 **Errores amables**      | Mensajes en lenguaje sencillo, con sugerencias ("¿Quisiste escribir...?") y un ejemplo de la sintaxis correcta. |
| 🔵 **Bluetooth Dual**       | Soporte para Bluetooth Clásico (Android) y BLE (Web/Móvil) para conectar con hardware real. |
| 🕹️ **Control Remoto**       | Interfaz de mando directo para el robot integrada en la app. |
| 📱 **UI adaptativa**        | Layouts compact / medium / expanded / large según el ancho de ventana (móvil, tablet, escritorio y web). |
| ⚙️ **CI/CD Robusto**        | Despliegue automatizado a GitHub Pages y generación de instaladores para todas las plataformas. |

---

## 📖 El Lenguaje DSL

La sintaxis está diseñada para ser legible y educativa:

```stembosque
PROGRAMA "Prueba Logica"
  N = 10
  SI N < 20 AND NOT N == 5 ENTONCES:
    GIRAR 90
    AVANZAR 50
  FIN SI
  
  REPETIR [4] VECES:
    AVANZAR 100
    GIRAR 90
  FIN REPETIR
FIN PROGRAMA
```

### Funciones Disponibles
- **Movimiento**: `AVANZAR`, `GIRAR`.
- **Matemáticas**: `+`, `-`, `*`, `/`, `SEN()`, `COS()`, `TANG()`.
- **Variables**: asignación con `=` (por ejemplo `N = 100`), usables en expresiones y en `REPETIR [N] VECES`.
- **Lógica**: `AND`, `OR`, `NOT` y comparaciones `>`, `<`, `==`.

> Todavía no están implementados los operadores `!=`, `>=` y `<=`, ni sensores virtuales como `DISTANCIA`, `OBSTACULO` o `PISO`.

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

Adicionalmente, el `SyntaxValidator` (`lib/compiler/syntax_validator.dart`) alimenta la validación en tiempo real del editor, mostrando errores mientras el usuario escribe. Analiza el programa hasta 8 veces: tras cada error repara el texto y vuelve a analizar, así detecta varios errores a la vez. Cada error lleva un mensaje amable y, cuando aplica, un ejemplo de la sintaxis correcta (`lib/compiler/syntax_help.dart`).

| Etapa | Archivo | Responsabilidad |
|-------|---------|-----------------|
| Léxico | `compiler/lexer/lexer.dart` | Tokeniza la fuente; reconoce palabras clave, números, símbolos y comentarios. |
| Tokens | `compiler/models/token.dart` | Define `Token` y `TipoToken`. |
| Sintáctico | `compiler/parser/parser.dart` | Construye el AST a partir de los tokens. |
| AST | `compiler/ast/nodes.dart` | Nodos del árbol de sintaxis. |
| Ejecución | `compiler/interpreter/interpreter.dart` | Evalúa el AST y produce la salida/simulación. |
| Generación | `compiler/codegen/code_generator.dart` | Traduce el AST a código de salida. |
| Validación | `compiler/syntax_validator.dart` | Validación en vivo para el editor (varios errores a la vez). |
| Ayuda de sintaxis | `compiler/syntax_help.dart` | Explicaciones y ejemplos para cada tipo de error. |

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
│   │   ├── syntax_help.dart         # Ayuda y ejemplos para los errores
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
│       ├── theme/app_theme.dart     # Tema visual (fondo azul-verdoso, bordes de 2 px, Material 3)
│       └── utils/
│           ├── responsive.dart      # Breakpoints por ancho de ventana
│           └── app_scaler.dart      # Escala de texto en viewports pequeños
│
├── assets/images/                   # Mascota "Tita" (WebP, 600 px de ancho)
├── assets/fonts/                    # Nunito y JetBrains Mono (con su licencia OFL)
├── test/                            # Pruebas (resaltado del editor)
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

Componentes destacados (`lib/ui/widgets/`): editor con validación y resaltado (`code_editor_validated.dart`), barra de herramientas (`toolbar.dart`), panel Bluetooth (`bluetooth_panel.dart`), menú lateral (`ide_drawer.dart`), consola de ejecución (`execution_console.dart`), botones con relieve (`duo_button.dart`), modo inmersivo en móvil (`immersive_mode.dart`), asistente visual **Tita / Vampirito** (`tita.dart`), documentación DSL (`help_dialog.dart`) y pantalla de permisos BLE.

---

## 📱 Interfaz adaptativa

La UI se adapta al **ancho real de la ventana**, no al tipo de dispositivo. Así funciona igual en celular, tablet, escritorio o una pestaña web redimensionada.

Definido en `lib/ui/utils/responsive.dart` (clases de ventana de Material 3):

| Clase | Ancho | Uso típico |
|-------|-------|------------|
| Compact | &lt; 600 dp | Teléfono en vertical, ventana estrecha |
| Medium | 600–839 dp | Tablet, teléfono en horizontal |
| Expanded | 840–1199 dp | Portátil, tablet ancha |
| Large | ≥ 1200 dp | Monitor de escritorio |

Comportamiento:
- **IDE**: barra compacta y panel Bluetooth apilado en pantallas angostas; panel lateral cuando el ancho es ≥ 960 dp.
- **Login / permisos / creador de comandos**: formulario centrado con ancho máximo.
- **Nube / admin**: listas a todo el ancho en móvil y en rejilla o con tope de ancho en escritorio.
- **Simulación y control remoto**: canvas y pad de mandos se ajustan al espacio disponible (`FittedBox` / `LayoutBuilder`).
- **Modo Bloque**: paleta más baja en horizontal; la zona de drop usa coordenadas locales (sin offsets fijos de AppBar).
- **Diálogos y drawer**: `insetPadding` y ancho del menú según el viewport.

`AppScaler` (`lib/ui/utils/app_scaler.dart`) solo reduce un poco la escala de texto en pantallas muy estrechas (&lt; 380 dp). No usa `FittedBox` global para no distorsionar el layout. El scroll funciona con táctil, mouse y trackpad (`AppScrollBehavior` en `main.dart`).

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
- **Compilación**: Web (CanvasKit), Android, iOS, Windows, macOS y Linux.
- **Librerías Clave**: `flutter_blue_plus`, `share_plus` (v10+), `flutter_animate`.
- **Tipografías**: Nunito y JetBrains Mono, incluidas en `assets/fonts` (no se descargan al abrir la app).

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
| `share_plus`, `url_launcher` | Compartir contenido e integraciones del sistema. |
| `flutter_animate` | Animaciones de la UI. |

### Desarrollo
- `flutter_test` — pruebas.
- `flutter_lints` — análisis estático / linting.

### Notas de compatibilidad
- Se fija `permission_handler: 12.0.3` porque la serie 13.x usa `permission_handler_android` 14.x, cuyo `build.gradle.kts` no compila con AGP 8.11 / Kotlin 2.3 y rompe `flutter build apk`.
- Se fija `permission_handler_html: 0.1.3+5` mediante `dependency_overrides` porque la versión `0.1.4+0` usa `isA()` sobre `Object` (disponible solo en Dart 3.12+), lo que rompe la compilación en Web con Dart 3.11.
- `google_fonts` ya no se usa (las fuentes van incluidas). `web` y `cupertino_icons` no suben a su última versión porque exigen Dart 3.12 o superior; la app usa Flutter 3.41.5 (Dart 3.11).

---

## 🔧 Configuración de Desarrollo

1. **Clonar**: `git clone https://github.com/Sebastian542/Stem_Bosque.git`
2. **Dependencias**: `flutter pub get`
3. **Ejecutar**: `flutter run` (Compatible con Windows, Web, Android e iOS).
4. **Análisis y pruebas**: `flutter analyze` y `flutter test`.

> En Windows, `flutter pub get` y las compilaciones con plugins piden activar el **Modo de desarrollador** (`start ms-settings:developers`).

> **Firebase**: la app inicializa Firebase al arrancar (`main.dart`) usando `firebase_options.dart`. Si vas a usar tu propio proyecto Firebase, regenera este archivo con `flutterfire configure`.

---

## 🏗️ Compilación por Plataforma

```bash
# Web
flutter build web --release

# Android (APK)
flutter build apk --release --android-skip-build-dependency-validation

# iOS (sin firma, empaquetado manual)
flutter build ios --release --no-codesign
```

---

## ⚙️ CI/CD (GitHub Actions)

Definido en `.github/workflows/deploy.yml`. Usa Flutter 3.41.5 y `flutter pub get --enforce-lockfile`, así que `pubspec.lock` siempre debe estar actualizado. Se dispara en push a `main` o `aleja2` y:
1. Si el push es a `aleja2`, sincroniza esa rama hacia `main`.
2. Compila la versión **Web** (`flutter build web --release`) y la despliega en GitHub Pages.
3. Genera el **APK** de Android en modo release (`--android-skip-build-dependency-validation`).
4. Genera el **IPA** de iOS (sin firma, empaquetado manual).
5. Publica un **Release** `latest` con APK e IPA.

---

© 2026 STEMBosque — Innovación en Educación Tecnológica.

<!-- Documentación actualizada: 2026-11 (rev. 3) -->

