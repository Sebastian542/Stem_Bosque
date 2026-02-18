# 🤖 STEMBosque DSL

> **Un lenguaje de programación educativo para robótica**, diseñado para que niños y jóvenes aprendan lógica computacional controlando un robot virtual en español.

---

## 🌟 ¿Qué es STEMBosque DSL?

**STEMBosque DSL** es un *Domain-Specific Language* (Lenguaje de Dominio Específico) construido enteramente en el navegador. Permite escribir programas en **español natural** para controlar un robot animado en un canvas 2D, haciendo que conceptos como variables, ciclos y condicionales sean tangibles y divertidos.

Todo corre 100% en el navegador — sin instalaciones, sin servidores, sin complicaciones.

---

## ✨ Características

| Característica | Descripción |
|---|---|
| 🧠 **Compilador completo** | Analizador léxico, sintáctico y semántico usando la librería **Ohm.js** |
| 🎨 **IDE integrado** | Editor con resaltado de sintaxis propio (tema Dracula) vía **CodeMirror 5** |
| 🤖 **Robot animado** | Visualización en tiempo real con Canvas 2D — el robot reacciona a cada instrucción |
| 📐 **Layout redimensionable** | Paneles ajustables horizontal y verticalmente con drag-and-drop |
| 📂 **Carga de archivos** | Abre archivos `.txt` con código fuente directamente en el editor |
| ⌨️ **Control manual** | Mueve el robot también con las teclas de dirección del teclado |
| 🗂️ **Tabla de símbolos** | Manejo de scope léxico con herencia padre-hijo para variables |

---


Readme · MD
Copiar

# StemBosque — Documentación Técnica

## Solución: Error de Namespace en `flutter_bluetooth_serial`

### Descripción del problema

Al compilar el proyecto con versiones modernas del Android Gradle Plugin (AGP 7+), el build falla con el siguiente error:

```
A problem occurred configuring project ':flutter_bluetooth_serial'.
> Could not create an instance of type com.android.build.api.variant.impl.LibraryVariantBuilderImpl.
   > Namespace not specified. Specify a namespace in the module's build file:
     C:\Users\<usuario>\AppData\Local\Pub\Cache\hosted\pub.dev\flutter_bluetooth_serial-0.4.0\android\build.gradle.
```

**Causa:** El paquete `flutter_bluetooth_serial 0.4.0` fue publicado antes de que AGP hiciera obligatorio declarar el campo `namespace` en el `build.gradle` de cada módulo. El paquete está desactualizado y no incluye esta declaración.

---

### Solución aplicada

Se editó manualmente el `build.gradle` del paquete en la caché local de pub para agregar la declaración de `namespace`.

#### Pasos para reproducir la solución

**1. Localizar el archivo a editar**

Navegar a la siguiente ruta (reemplazar `<usuario>` con el nombre de usuario de Windows):

```
C:\Users\<usuario>\AppData\Local\Pub\Cache\hosted\pub.dev\flutter_bluetooth_serial-0.4.0\android\build.gradle
```

**2. Reemplazar el contenido completo del archivo**

Abrir el archivo con cualquier editor de texto (VS Code, Notepad++, etc.) y reemplazar todo el contenido con lo siguiente:

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

El único cambio respecto al archivo original es la línea:
```groovy
namespace 'io.github.edufolly.flutterbluetoothserial'
```

**3. Limpiar y recompilar**

Ejecutar en la terminal, desde la raíz del proyecto Flutter:

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

### Permisos requeridos en AndroidManifest.xml

Para que Bluetooth funcione correctamente en Android, el archivo `android/app/src/main/AndroidManifest.xml` debe incluir los siguientes permisos antes del bloque `<application>`:

```xml











```

---

### Dependencias del proyecto relacionadas

```yaml
# pubspec.yaml
dependencies:
  flutter_bluetooth_serial: ^0.4.0   # Bluetooth Clásico (SPP)
  permission_handler: ^11.3.1        # Solicitud de permisos en runtime
```

---

*Documentado por el equipo StemBosque — Universidad del Bosque*
---

## 📖 Sintaxis del Lenguaje

### Estructura básica

```
PROGRAMA "Mi primer programa"

  /* Esto es un comentario */
  AVANZAR 10
  GIRAR 5

FIN PROGRAMA
```

### Variables

```
N = 100
Contador = 1
```

### Comandos de movimiento

```
AVANZAR 5     /* Avanza hacia adelante */
AVANZAR -5    /* Retrocede */
GIRAR 5       /* Gira en sentido horario */
GIRAR -5      /* Gira en sentido antihorario */
```

### Ciclos

```
REPETIR [N] VECES:
  GIRAR 1
FIN REPETIR
```

### Condicionales

```
SI N < 200 ENTONCES:
  AVANZAR 10
FIN SI
```

### Operadores de comparación

Los operadores disponibles son `==`, `>` y `<`.

---

## 🚀 Cómo usar

1. **Abre** el archivo `STEMBosqueDSL_v5.html` en cualquier navegador moderno (Chrome, Firefox, Edge).
2. **Escribe** tu programa en el editor de la izquierda o carga un archivo con el botón **Abrir**.
3. **Ejecuta** con el botón verde **Ejecutar** y observa cómo el robot cobra vida en el panel derecho.
4. **Limpia** el editor con el botón rojo **Limpiar** para empezar de nuevo.

> También puedes controlar el robot manualmente usando las **teclas de flecha** del teclado mientras el programa no está en ejecución.

---

## 🏗️ Arquitectura del Proyecto

El proyecto es un único archivo HTML autocontenido con tres capas bien definidas:

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

---

## 🛠️ Tecnologías utilizadas

- **[Ohm.js v16](https://ohmjs.org/)** — Motor para definir gramáticas y semántica
- **[CodeMirror 5](https://codemirror.net/5/)** — Editor de código con modo personalizado
- **HTML5 Canvas API** — Renderizado del robot en tiempo real
- **JavaScript vanilla** — Sin frameworks, ligero y portable

---

## 💡 Ejemplo completo

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

---

## 🗺️ Roadmap

- [ ] Soporte para funciones/procedimientos definidos por el usuario
- [ ] Más operadores de comparación (`!=`, `>=`, `<=`)
- [ ] Operaciones aritméticas en expresiones (`N + 1`, `N * 2`)
- [ ] Exportar el programa a código Arduino
- [ ] Guardado de archivos desde el IDE
- [ ] Modo oscuro/claro configurable

---

## 📄 Licencia

Este proyecto es de carácter **educativo**, desarrollado en el marco de la iniciativa **STEMBosque**. para uso, estudio y adaptación con fines pedagógicos.

---

<div align="center">
  <b>Hecho con ❤️ para enseñar  habilidades STEM  🌱</b>
</div>
