# 🤖 STEMBosque DSL

> **Un lenguaje de programación educativo para robótica**, diseñado para que niños y jóvenes aprendan lógica computacional controlando un robot virtual en español.

---

## 🌟 ¿Qué es STEMBosque DSL?

**STEMBosque DSL** es un *Domain-Specific Language* (Lenguaje de Dominio Específico) disponible como **app móvil Flutter** y como **versión web en el navegador**. Permite escribir programas en **español natural** para controlar un robot animado, haciendo que conceptos como variables, ciclos, condicionales y operaciones matemáticas sean tangibles y divertidos.

La versión web corre **100% en el navegador** — sin instalaciones, sin servidores, sin complicaciones.

---

## ✨ Características

| Característica | Descripción |
|---|---|
| 🧠 **Compilador completo** | Analizador léxico, sintáctico e intérprete. Web: **Ohm.js** · Mobile: **Dart** |
| 🎨 **IDE integrado** | Editor con resaltado de sintaxis (tema Dracula), números de línea y marcado de errores |
| 💡 **Autocompletado** | Sugerencias de palabras clave mientras escribes |
| 🤖 **Robot animado** | Visualización en tiempo real con Canvas 2D — el robot reacciona a cada instrucción |
| ⚙️ **Generador de código** | Transpila programas STEMBosque a código Dart ejecutable |
| 📐 **Layout redimensionable** | Paneles ajustables horizontal y verticalmente con drag-and-drop (versión web) |
| 📂 **Gestión de archivos** | Abre, guarda y comparte programas `.txt` / `.sb` |
| ⌨️ **Control manual** | Mueve el robot también con las teclas de dirección del teclado (versión web) |
| 🔵 **Bluetooth** | Envío de programas a dispositivos físicos por BLE / SPP (app móvil) |
| 🗂️ **Tabla de símbolos** | Manejo de scope léxico con herencia padre-hijo para variables |

---

## 📖 Sintaxis del Lenguaje

### Estructura básica

Todo programa debe comenzar con `PROGRAMA "nombre"` y terminar con `FIN PROGRAMA`. Las palabras clave son **case-insensitive** (`si`, `SI`, `Si` son equivalentes). El cuerpo debe contener **al menos una instrucción**.

```
PROGRAMA "Mi primer programa"

  // Esto es un comentario de línea

  /* Esto es un
     comentario de bloque */

  AVANZAR 10
  GIRAR 5

FIN PROGRAMA
```

---

### Variables y asignación

Los identificadores pueden contener letras, números y guiones bajos. Las palabras clave **no** pueden usarse como nombres de variable.

```
N = 100
Contador = 1
angulo_base = 45
resultado = N * 2 + angulo_base
```

> ⚠️ Las variables deben asignarse **antes** de usarse en expresiones.

---

### Comandos de movimiento

```
AVANZAR 5      /* Avanza hacia adelante */
AVANZAR -5     /* Retrocede */
GIRAR 5        /* Gira en sentido horario */
GIRAR -5       /* Gira en sentido antihorario */
AVANZAR N      /* Usa el valor de una variable */
AVANZAR N * 2  /* Usa una expresión aritmética */
```

---

### Expresiones aritméticas

Las expresiones aritméticas se pueden usar en **cualquier lugar que acepte un valor numérico**: asignaciones, `GIRAR`, `AVANZAR` y `REPETIR`.

#### Operadores (por precedencia, de menor a mayor)

| Nivel | Operador | Descripción | Asociatividad | Ejemplo |
|---|---|---|---|---|
| 1 | `+` `-` | Suma y resta | Izquierda | `N + 5` |
| 2 | `*` `/` `%` | Multiplicación, división, módulo | Izquierda | `N * 3`, `N % 2` |
| 3 | `^` | Potencia | **Derecha** | `2 ^ 3 ^ 2` → `2^(3^2)` = 512 |
| 4 | `-` (unario) | Negación unaria | — | `-N`, `-(N + 1)` |
| 4 | `SEN` `COS` `TANG` | Funciones trigonométricas (en grados) | — | `SEN 30`, `COS (N*2)` |
| 5 | `(` `)` | Agrupación | — | `(N + 5) * 2` |

```
A = 2 ^ 10           /* 1024  (potencia) */
B = 10 % 3           /* 1     (módulo) */
C = -N + 50          /* negación unaria */
D = (A + B) * 3      /* agrupación con paréntesis */
E = SEN 30           /* sin(30°) ≈ 0.5 */
F = COS (N * 2)      /* cos de una expresión */
G = 2 ^ 3 ^ 2        /* 2^(3^2) = 2^9 = 512  (asociativa derecha) */
```

> ⚠️ Las funciones trigonométricas reciben el ángulo **en grados**. `TANG 90` lanza un error de ejecución porque la tangente no está definida en ese punto.

---

### Ciclos

```
REPETIR [N] VECES:
  GIRAR 1
FIN REPETIR

/* Con literal numérico */
REPETIR [4] VECES:
  AVANZAR 100
  GIRAR 90
FIN REPETIR

/* Con expresión aritmética */
REPETIR [N * 2 + 1] VECES:
  AVANZAR 10
FIN REPETIR
```

> ⚠️ La expresión del `REPETIR` debe evaluar a un entero entre **1 y 10 000**.

---

### Condicionales

```
SI N < 200 ENTONCES:
  AVANZAR 10
FIN SI

SI angulo == 90 ENTONCES:
  GIRAR 180
FIN SI

/* Anidamiento: REPETIR dentro de SI */
SI N > 50 ENTONCES:
  REPETIR [N] VECES:
    GIRAR 1
  FIN REPETIR
FIN SI
```

---

### Operadores de comparación

Los operadores disponibles son `==`, `>` y `<`.

---

### Expresiones booleanas

Usadas exclusivamente dentro de `SI`. Soportan comparación, negación y conectivos lógicos.

#### Operadores lógicos (por precedencia, de menor a mayor)

| Nivel | Operador | Descripción |
|---|---|---|
| 1 | `OR` | Disyunción — verdadero si al menos uno es verdadero |
| 2 | `AND` | Conjunción — verdadero si ambos son verdaderos |
| 3 | `NOT` | Negación — invierte el valor booleano |

```
SI N > 10 AND N < 100 ENTONCES:
  AVANZAR N
FIN SI

SI N < 0 OR N > 360 ENTONCES:
  N = 90
FIN SI

SI NOT N < 5 ENTONCES:
  GIRAR N
FIN SI

/* Paréntesis para agrupar condiciones compuestas */
SI (N > 10 AND N < 50) OR angulo == 90 ENTONCES:
  AVANZAR 100
FIN SI
```

---

### Comentarios

```
// Comentario de una sola línea

/* Comentario
   de múltiples
   líneas */
```

---

## 🏗️ Gramática Formal (BNF)

```
programa       →  PROGRAMA TEXTO instrucciones FIN PROGRAMA

instrucciones  →  instruccion+

instruccion    →  asignacion
               |  girar
               |  avanzar
               |  condicional
               |  ciclo

asignacion     →  IDENTIFICADOR = expArit
girar          →  GIRAR expArit
avanzar        →  AVANZAR expArit
condicional    →  SI expBool ENTONCES : instrucciones FIN SI
ciclo          →  REPETIR [ expArit ] VECES : instrucciones FIN REPETIR

/* ── Expresiones booleanas ── */
expBool        →  expAnd ( OR expAnd )*
expAnd         →  expNot ( AND expNot )*
expNot         →  NOT expNot  |  atomoBool
atomoBool      →  ( expBool )
               |  expArit comparador expArit
comparador     →  ==  |  >  |  <

/* ── Expresiones aritméticas ── */
expArit        →  expMult  ( ( + | - ) expMult )*
expMult        →  expPot   ( ( * | / | % ) expPot  )*
expPot         →  expUnaria ( ^ expPot )?           // asociativa derecha
expUnaria      →  - expUnaria
               |  ( SEN | COS | TANG ) atomoArit
               |  atomoArit
atomoArit      →  NUMERO
               |  IDENTIFICADOR
               |  ( expArit )

/* ── Tokens terminales ── */
TEXTO          →  " [cualquier carácter]* "
NUMERO         →  [0-9]+ ( . [0-9]+ )?
IDENTIFICADOR  →  [a-zA-Z_][a-zA-Z0-9_]*   // no puede ser palabra clave
```

---

## 💡 Ejemplos

### Básico

```
PROGRAMA "Hola Robot"
  GIRAR 90
  AVANZAR 100
FIN PROGRAMA
```

### Variables y operaciones aritméticas

```
PROGRAMA "Aritmética"
  A = 10
  B = 3
  GIRAR A * B
  AVANZAR A + B * 2
  GIRAR A ^ 2
  AVANZAR A % B
FIN PROGRAMA
```

### Dibujar un círculo aproximado

```
PROGRAMA "Círculo"
  N = 100
  Contador = 1
  REPETIR [N] VECES:
    GIRAR 1
  FIN REPETIR
FIN PROGRAMA
```

### Cuadrado con ciclo

```
PROGRAMA "Cuadrado"
  LADO = 100
  REPETIR [4] VECES:
    AVANZAR LADO
    GIRAR 90
  FIN REPETIR
FIN PROGRAMA
```

### Estrella de 5 puntas

```
PROGRAMA "Estrella"
  REPETIR [5] VECES:
    AVANZAR 120
    GIRAR 144
  FIN REPETIR
FIN PROGRAMA
```

### Condicional con lógica booleana

```
PROGRAMA "Booleanos"
  X = 20
  Y = 5
  SI X > 10 AND Y < 10 ENTONCES:
    AVANZAR 80
  FIN SI
  SI X > 50 OR Y < 10 ENTONCES:
    GIRAR 45
  FIN SI
  SI NOT X < 5 ENTONCES:
    AVANZAR 30
  FIN SI
FIN PROGRAMA
```

### Trigonometría

```
PROGRAMA "Trigonometría"
  ANGULO = 30
  S = SEN ANGULO
  C = COS ANGULO
  GIRAR S * 100
  AVANZAR C * 100
FIN PROGRAMA
```

### Espiral creciente

```
PROGRAMA "Espiral"
  PASO = 10
  N = 8
  REPETIR [N] VECES:
    AVANZAR PASO
    GIRAR 45
    PASO = PASO + 10
  FIN REPETIR
FIN PROGRAMA
```

### Demo completo

```
PROGRAMA "Demo completo"

  /* Configuración inicial */
  N = 100
  Contador = 1

  /* Movimientos básicos */
  AVANZAR 5
  AVANZAR -5
  GIRAR 5
  GIRAR -5

  /* Dibujar un círculo aproximado */
  REPETIR [N] VECES:
    GIRAR 1
  FIN REPETIR

  /* Condicional: si N es pequeño, girar al revés */
  SI N < 200 ENTONCES:
    REPETIR [N] VECES:
      GIRAR -1
    FIN REPETIR
  FIN SI

FIN PROGRAMA
```

### Robot Explorador (programa avanzado)

```
PROGRAMA "Robot Explorador"
  // Configuración inicial
  VELOCIDAD = 50
  GIRO_BASE = 30

  /* Primer movimiento */
  AVANZAR VELOCIDAD * 2
  GIRAR GIRO_BASE

  // Cuadrado interior
  REPETIR [4] VECES:
    AVANZAR VELOCIDAD
    GIRAR 90
  FIN REPETIR

  // Ajuste condicional
  SI VELOCIDAD > 40 AND GIRO_BASE < 45 ENTONCES:
    GIRO_BASE = GIRO_BASE * 2
    AVANZAR VELOCIDAD + GIRO_BASE
    GIRAR GIRO_BASE
  FIN SI

  // Espiral final
  PASO = 10
  REPETIR [6] VECES:
    AVANZAR PASO
    GIRAR 60
    PASO = PASO + 15
  FIN REPETIR

FIN PROGRAMA
```

---

## 🚀 Cómo usar

### Versión web

1. **Abre** el archivo `STEMBosqueDSL_v5.html` en cualquier navegador moderno (Chrome, Firefox, Edge).
2. **Escribe** tu programa en el editor de la izquierda o carga un archivo con el botón **Abrir**.
3. **Ejecuta** con el botón verde **Ejecutar** y observa cómo el robot cobra vida en el panel derecho.
4. **Limpia** el editor con el botón rojo **Limpiar** para empezar de nuevo.

> También puedes controlar el robot manualmente usando las **teclas de flecha** del teclado mientras el programa no está en ejecución.

### App móvil

1. **Escribe** tu programa en el editor — el resaltado de sintaxis te ayuda a identificar cada elemento.
2. **Observa** la barra de estado: muestra si el código tiene errores en tiempo real.
3. **Ejecuta** con el botón **Ejecutar** de la barra de herramientas.
4. **Lee** la salida en la consola de ejecución: variables, GIRAR y AVANZAR se listan en orden.
5. **Envía** el programa al robot físico con el botón **Bluetooth** si tienes un dispositivo conectado.
6. **Guarda / Abre** tus programas desde el menú lateral (ícono ☰).

---

## 🏗️ Arquitectura del proyecto

### Versión web

```
STEMBosqueDSL_v5.html
├── 🎨 Capa de Presentación
│   ├── IDE (CodeMirror 5 + tema Dracula)
│   └── Canvas del robot (HTML5 Canvas 2D)
│
├── ⚙️ Capa del Compilador (Ohm.js)
│   ├── Gramática formal (BNF extendida)
│   ├── Semántica de evaluación
│   └── Tabla de Símbolos (TablaSimbolos)
│
└── 🤖 Capa de Ejecución
    ├── Clase Robot (movimiento, dibujo, bordes)
    └── Motor de animación (requestAnimationFrame)
```

### App móvil (Flutter)

```
lib/
├── compiler/
│   ├── models/
│   │   └── token.dart              — Definición de TipoToken y Token
│   ├── lexer/
│   │   └── lexer.dart              — Analizador léxico (tokenizador)
│   ├── ast/
│   │   └── nodes.dart              — Nodos del AST
│   ├── parser/
│   │   └── parser.dart             — Parser recursivo descendente
│   ├── interpreter/
│   │   └── interpreter.dart        — Intérprete del AST
│   ├── codegen/
│   │   └── code_generator.dart     — Generador de código Dart
│   ├── syntax_validator.dart       — Validación en tiempo real
│   └── compiler.dart               — Fachada: léxico → parser → intérprete → codegen
└── ui/
    ├── screens/
    │   └── ide_screen.dart
    ├── theme/
    │   └── app_theme.dart          — Tema Dracula + colores de sintaxis
    └── widgets/
        ├── code_editor_validated.dart  — Editor con syntax highlighting
        ├── code_editor.dart
        ├── execution_console.dart
        ├── console_output.dart
        ├── bluetooth_panel.dart
        ├── ide_drawer.dart
        ├── toolbar.dart
        └── permission_request_screen.dart
```

---

## 🛠️ Tecnologías utilizadas

### Versión web
- **[Ohm.js v16](https://ohmjs.org/)** — Motor para definir gramáticas y semántica
- **[CodeMirror 5](https://codemirror.net/5/)** — Editor de código con modo personalizado
- **HTML5 Canvas API** — Renderizado del robot en tiempo real
- **JavaScript vanilla** — Sin frameworks, ligero y portable

### App móvil
- **Flutter / Dart** — Framework multiplataforma (Android / iOS)
- **flutter_bluetooth_serial** — Conexión Bluetooth SPP clásico
- **permission_handler** — Gestión de permisos en runtime
- **path_provider** — Acceso al sistema de archivos del dispositivo
- **share_plus** — Compartir archivos entre apps

---

## ⚠️ Errores comunes y cómo resolverlos

| Error | Causa probable | Solución |
|---|---|---|
| `Variable "X" no tiene valor` | Se usó una variable antes de asignarla | Agrega `X = 10` antes de la primera vez que la uses |
| `División entre cero` | El divisor de `/` o `%` evaluó a 0 | Revisa el valor del divisor |
| `TANG de 90° no definida` | Tangente indefinida en ±90°, ±270°... | Usa un ángulo diferente |
| `REPETIR dio 0` o negativo | La expresión del ciclo evaluó a ≤ 0 | Usa un valor mayor a 0 |
| `REPETIR dio > 10000` | El ciclo es demasiado grande | Reduce el número de iteraciones |
| `Bloque vacío` | Un `SI` o `REPETIR` sin instrucciones dentro | Agrega al menos una instrucción |
| `Falta FIN` | Se abrió un `SI` o `REPETIR` sin cerrarlo | Agrega el `FIN SI` o `FIN REPETIR` correspondiente |
| `Símbolo no reconocido` | Carácter especial no soportado | Revisa que no haya caracteres raros en el editor |

---

## 🔧 Solución: Error de Namespace en `flutter_bluetooth_serial`

### Descripción del problema

Al compilar con versiones modernas del Android Gradle Plugin (AGP 7+), el build falla con el siguiente error:

```
A problem occurred configuring project ':flutter_bluetooth_serial'.
> Could not create an instance of type com.android.build.api.variant.impl.LibraryVariantBuilderImpl.
   > Namespace not specified. Specify a namespace in the module's build file:
     C:\Users\<usuario>\AppData\Local\Pub\Cache\hosted\pub.dev\flutter_bluetooth_serial-0.4.0\android\build.gradle.
```

**Causa:** El paquete `flutter_bluetooth_serial 0.4.0` fue publicado antes de que AGP hiciera obligatorio declarar el campo `namespace` en el `build.gradle` de cada módulo.

---

### Solución aplicada

Se editó manualmente el `build.gradle` del paquete en la caché local de pub para agregar la declaración de `namespace`.

#### Paso 1 — Localizar el archivo a editar

Navegar a la siguiente ruta (reemplazar `<usuario>` con el nombre de usuario de Windows):

```
C:\Users\<usuario>\AppData\Local\Pub\Cache\hosted\pub.dev\flutter_bluetooth_serial-0.4.0\android\build.gradle
```

#### Paso 2 — Reemplazar el contenido completo del archivo

Abrir el archivo con cualquier editor de texto y reemplazar todo el contenido con lo siguiente:

```groovy
group 'io.github.edufolly.flutterbluetoothserial'
version '1.0-SNAPSHOT'

buildscript {
    repositories {
        google()
        jcenter()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:4.1.0'
    }
}

rootProject.allprojects {
    repositories {
        google()
        jcenter()
    }
}

apply plugin: 'com.android.library'

android {
    namespace 'io.github.edufolly.flutterbluetoothserial'   // ← línea añadida
    compileSdkVersion 30

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    defaultConfig {
        minSdkVersion 19
        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
    }

    lintOptions {
        disable 'InvalidPackage'
    }

    dependencies {
        implementation 'androidx.appcompat:appcompat:1.3.0'
    }

    buildToolsVersion '30.0.3'
}

dependencies {
}
```

#### Paso 3 — Limpiar y recompilar

```bash
flutter clean
flutter pub get
flutter run
```

---

### ⚠️ Advertencia importante

Esta modificación se realiza sobre la **caché global de pub**, no sobre el proyecto. Esto significa que:

- El cambio afecta a todos los proyectos Flutter del equipo que usen este paquete.
- Si se ejecuta `dart pub cache repair` o se borra la caché manualmente, el parche se perderá y habrá que aplicarlo de nuevo.
- Si otro desarrollador clona el proyecto en una máquina nueva, deberá aplicar este mismo parche.

**Recomendación a futuro:** Evaluar migrar a `flutter_blue_plus`, que es el sucesor activo de `flutter_bluetooth_serial`, tiene soporte para Android e iOS, y no presenta este problema de compatibilidad.

---

### Permisos requeridos en `AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Permisos de Bluetooth -->
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

    <!-- Para Android 12+ (API 31+) -->
    <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />

    <application
        android:label="stem_bosque"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
```

### Dependencias del proyecto en `pubspec.yaml`

```yaml
dependencies:
  flutter_bluetooth_serial: ^0.4.0   # Bluetooth Clásico (SPP)
  permission_handler: ^11.3.1        # Solicitud de permisos en runtime
```

---

## 🗺️ Roadmap

- [ ] Más operadores de comparación (`!=`, `>=`, `<=`)
- [ ] Soporte para funciones / procedimientos definidos por el usuario
- [ ] Exportar programa a código Arduino directamente
- [ ] Guardado de archivos desde el IDE web
- [ ] Modo oscuro / claro configurable
- [ ] Historial de ejecuciones
- [ ] Simulador visual del robot en pantalla (app móvil)

---

## 📄 Licencia

Este proyecto es de carácter **educativo**, desarrollado en el marco de la iniciativa **STEMBosque** — Universidad del Bosque. Para uso, estudio y adaptación con fines pedagógicos.

---

<div align="center">
  <b>Hecho con ❤️ para enseñar habilidades STEM 🌱</b>
</div>