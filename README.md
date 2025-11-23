# slider_app

A Flutter application with Supabase integration for player score tracking.

## 🔧 Configuración de Variables de Entorno

Esta aplicación utiliza variables de entorno para gestionar configuraciones sensibles.

### Configuración Inicial

1. Copia el archivo de ejemplo `.env.example` a `.env`:
   ```bash
   cp .env.example .env
   ```

2. Edita el archivo `.env` con tus credenciales reales:
   ```env
   # Supabase Configuration
   SUPABASE_URL=https://tu-proyecto.supabase.co
   SUPABASE_ANON_KEY=tu_anon_key_aqui
   
   # Authentication
   AUTH_EMAIL=tu_email@example.com
   AUTH_PASSWORD=tu_password_aqui
   ```

3. El archivo `.env` está en `.gitignore` y **NO debe** ser commiteado.

### Variables Disponibles

| Variable | Descripción |
|----------|-------------|
| `SUPABASE_URL` | URL de tu proyecto Supabase |
| `SUPABASE_ANON_KEY` | Clave anónima pública de Supabase |
| `AUTH_EMAIL` | Email para autenticación |
| `AUTH_PASSWORD` | Contraseña para autenticación |

## 🚀 Instalación y Ejecución

1. Instala las dependencias:
   ```bash
   flutter pub get
   ```

2. Configura tu archivo `.env` (ver arriba)

3. Ejecuta la aplicación:
   ```bash
   flutter run
   ```

## 🏗️ Arquitectura

El proyecto sigue una arquitectura de servicios:

```
lib/
├── main.dart                    # Punto de entrada, carga .env
└── services/
    └── supabase_service.dart   # Lógica de Supabase centralizada
```

### SupabaseService

Todas las operaciones de Supabase están encapsuladas en `SupabaseService`:

- `signIn()` - Autenticación
- `insertPlayer()` - Insertar jugador
- `updatePlayer()` - Actualizar puntos
- `checkAndUpsertPlayer()` - Upsert inteligente
- `retrievePoints()` - Obtener puntos

## 🔒 Seguridad

- **Nunca** compartas tu archivo `.env`
- El archivo `.env` está en `.gitignore`
- Usa `.env.example` como plantilla

## 📦 Dependencias

- `supabase_flutter: ^2.10.3` - Cliente de Supabase
- `flutter_dotenv: ^5.1.0` - Gestión de variables de entorno

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:
    
- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## 🪪 Créditos

- [Flutter](https://flutter.dev) - Framework para construir aplicaciones nativas
- [Supabase](https://supabase.io) - Backend como servicio
- [flutter_dotenv](https://pub.dev/packages/flutter_dotenv) - Gestión de variables de entorno
- [freepngimg](https://freepngimg.com/png/148675-car-top-vector-view-free-hd-image) - Iconos de autos utilizados en la aplicación