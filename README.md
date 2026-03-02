# 🤖 StemBosque IDE

> **App móvil educativa para programar robots con un DSL en español**, diseñada para que niños y jóvenes aprendan lógica computacional controlando hardware real a través de Bluetooth.

---

## 🌟 ¿Qué es StemBosque IDE?

**StemBosque IDE** es una aplicación móvil desarrollada en **Flutter** que actúa como entorno de desarrollo integrado (IDE) para el lenguaje DSL de robótica educativa de STEMBosque. Permite escribir programas en **español natural**, compilarlos en el dispositivo y enviarlos a un robot físico mediante **Bluetooth Clásico o BLE**, haciendo que conceptos como variables, ciclos y condicionales sean tangibles y divertidos.

---

## ✨ Características

| Característica | Descripción |
|---|---|
| 🧠 **Compilador integrado** | Compilador/transpiler DSL → Python directamente en el dispositivo |
| 🎨 **IDE móvil** | Editor con resaltado de sintaxis y tema oscuro |
| 📡 **Bluetooth Clásico** | Conexión con robots vía `flutter_bluetooth_serial` |
| 🔵 **Bluetooth BLE** | Soporte para dispositivos BLE con `flutter_blue_plus` |
| 📂 **Gestión de archivos** | Abrir y guardar archivos de código fuente con `file_picker` |
| 🔐 **Manejo de permisos** | Solicitud inteligente de permisos de Bluetooth, ubicación y almacenamiento |
| 📤 **Compartir programas** | Exportar y compartir archivos de código con `share_plus` |

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

1. **Instala** la app en un dispositivo Android.
2. **Concede los permisos** de Bluetooth y ubicación cuando se soliciten al iniciar.
3. **Escribe** tu programa en el editor o carga un archivo existente.
4. **Conecta** el robot mediante Bluetooth (Clásico o BLE) desde el menú de conexión.
5. **Ejecuta** el programa y observa al robot en acción.
6. **Comparte** tu código usando el botón de exportar.

---

## 🏗️ Arquitectura del Proyecto
```
lib/
├── main.dart                              # Punto de entrada de la app
│
├── compiler/                              # Compilador DSL → Python/GPIO
│
├── bluetooth/                             # Capa de comunicación Bluetooth
│   ├── Bluetooth Clásico (HC-05, HC-06)
│   └── Bluetooth BLE
│
├── services/                              # Servicios (archivos, compartir)
│
├── ui/                                    # Interfaz de usuario
│   ├── screens/ide_screen.dart           # Pantalla principal del IDE
│   ├── theme/app_theme.dart              # Tema oscuro
│   └── widgets/permission_request_screen.dart
│
└── utils/                                 # Utilidades generales
```

---

## 🛠️ Tecnologías y Dependencias

| Paquete | Versión | Uso |
|---|---|---|
| `flutter_bluetooth_serial` | ^0.4.0 | Bluetooth Clásico (HC-05, HC-06) |
| `flutter_blue_plus` | 1.32.12 | Bluetooth BLE |
| `permission_handler` | ^11.3.1 | Gestión de permisos Android/iOS |
| `file_picker` | ^8.0.0+1 | Abrir archivos de código fuente |
| `path_provider` | ^2.1.2 | Rutas del sistema de archivos |
| `share_plus` | ^7.2.2 | Compartir archivos de programas |
| `android_intent_plus` | ^4.0.0 | Intents nativos Android |

**Plataforma:** Flutter SDK `>=3.0.0 <4.0.0`

---

## 📋 Requisitos

- **Android** 6.0+ (API 23+)
- **Flutter** 3.x
- Dispositivo con Bluetooth habilitado
- Robot compatible con comunicación serial Bluetooth (ej. Raspberry Pi con HC-05/HC-06 o BLE)

---

## ⚙️ Instalación
```bash
git clone https://github.com/stembosque/stembosque-ide.git
cd stembosque-ide
flutter pub get
flutter run

# APK de release
flutter build apk --release
```

### Permisos Android (`AndroidManifest.xml`)

Incluir antes del bloque `<application>`:
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<!-- Para Android 12+ (API 31+) -->
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
```

---

## 💡 Ejemplo completo
```
PROGRAMA "Demo completo"

  N = 100
  Contador = 1

  AVANZAR 5
  GIRAR 5

  REPETIR [N] VECES:
    GIRAR 1
  FIN REPETIR

  SI N < 200 ENTONCES:
    REPETIR [N] VECES:
      GIRAR -1
    FIN REPETIR
  FIN SI

FIN PROGRAMA
```

---

## 🗺️ Roadmap

- [x] Compilador DSL → Python/GPIO
- [x] Conexión Bluetooth Clásico y BLE
- [x] IDE móvil con editor de código
- [x] Manejo de permisos en Android
- [x] Compartir archivos de programas
- [ ] Transferencia de archivos Bluetooth entre dispositivos (Nearby Connections API)
- [ ] Soporte para funciones/procedimientos definidos por el usuario
- [ ] Más operadores de comparación (`!=`, `>=`, `<=`)
- [ ] Operaciones aritméticas en expresiones (`N + 1`, `N * 2`)
- [ ] Exportar programa a código Arduino
- [ ] Soporte iOS

---

## 🔧 Troubleshooting

### Error: Namespace not specified en `flutter_bluetooth_serial`

**Síntoma:** El build falla con AGP 7+ mostrando:
```
> Namespace not specified. Specify a namespace in the module's build file:
  ...flutter_bluetooth_serial-0.4.0\android\build.gradle
```

**Causa:** El paquete `flutter_bluetooth_serial 0.4.0` fue publicado antes de que AGP hiciera obligatoria la declaración del campo `namespace`.

**Solución:** Editar manualmente el archivo de caché del paquete:

1. Abrir el archivo en la siguiente ruta (reemplazar `<usuario>`):
```
C:\Users\<usuario>\AppData\Local\Pub\Cache\hosted\pub.dev\flutter_bluetooth_serial-0.4.0\android\build.gradle
```

2. Agregar la línea `namespace` dentro del bloque `android {}`:
```groovy
android {
    namespace 'io.github.edufolly.flutterbluetoothserial'  // ← añadir esta línea
    compileSdkVersion 30
    ...
}
```

3. Limpiar y recompilar:
```bash
flutter clean
flutter pub get
flutter run
```

> ⚠️ **Importante:** Esta modificación se aplica sobre la caché global de pub. Si se ejecuta `dart pub cache repair` o se borra la caché, el parche se perderá y deberá aplicarse nuevamente en cada máquina del equipo. Se recomienda evaluar la migración a `flutter_blue_plus` a futuro, ya que es el sucesor activo y no presenta este problema.

---

## 👥 Autores

Este proyecto fue desarrollado por el equipo **STEMBosque**:

- **Juan Sebastian Muñoz**
- **Julio Salazar**
- **Alejandra Urdaneta**

---

## 📄 Licencia

Proyecto educativo desarrollado en el marco de la iniciativa **STEMBosque**, para uso, estudio y adaptación con fines pedagógicos.

---

<div align="center">
  <b>Hecho con ❤️ para enseñar habilidades STEM 🌱</b>
</div>