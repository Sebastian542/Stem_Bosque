import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isRegistering = false;

  Future<void> _handleAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Por favor llena todos los campos");
      return;
    }

    if (_isRegistering && _nameController.text.isEmpty) {
      _showError("Por favor ingresa tu nombre");
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isRegistering) {
        await _auth.signUp(
          _emailController.text.trim(), 
          _passwordController.text.trim(),
          _nameController.text.trim(),
        );
      } else {
        await _auth.signIn(
          _emailController.text.trim(), 
          _passwordController.text.trim()
        );
      }
      // Al tener éxito, regresamos al IDE (el stream de Auth se encarga del resto)
      if (mounted) {
        final profile = await _auth.getCurrentUserProfile();
        final name = profile?['name'] ?? 'Usuario';
        
        // Mensaje de bienvenida personalizado
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.currentLine,
            title: const Text("¡Bienvenido!", style: TextStyle(color: AppTheme.purple)),
            content: Text("Hola $name, es un gusto tenerte de vuelta en StemBosque.", 
              style: const TextStyle(color: AppTheme.foreground)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Cierra el diálogo
                  Navigator.pop(context); // Vuelve al IDE
                },
                child: const Text("Comenzar", style: TextStyle(color: AppTheme.cyan)),
              )
            ],
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.currentLine,
        title: const Text("Error de Conexión", style: TextStyle(color: AppTheme.red)),
        content: Text(message, style: const TextStyle(color: AppTheme.foreground)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Entendido", style: TextStyle(color: AppTheme.cyan)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.comment),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/images/logo.png',
                  height: 100,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.code, size: 80, color: AppTheme.cyan),
                ).animate().fadeIn(duration: 600.ms).scale(),
                
                const SizedBox(height: 20),
                Text(
                  'StemBosque IDE',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.purple,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Text(
                  'Portal de Robótica Educativa',
                  style: TextStyle(color: AppTheme.comment),
                ),
                const SizedBox(height: 40),
                
                // Formulario dinámico
                if (_isRegistering) ...[
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: AppTheme.foreground),
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.person, color: AppTheme.comment),
                    ),
                  ).animate().fadeIn().slideX(),
                  const SizedBox(height: 16),
                ],
                
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: AppTheme.foreground),
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email, color: AppTheme.comment),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: AppTheme.foreground),
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock, color: AppTheme.comment),
                  ),
                ),
                const SizedBox(height: 32),
                
                if (_isLoading)
                  const CircularProgressIndicator(color: AppTheme.purple)
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: _handleAuth,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppTheme.purple,
                        ),
                        child: Text(
                          _isRegistering ? 'Crear mi cuenta' : 'Entrar',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => setState(() => _isRegistering = !_isRegistering),
                        child: Text(
                          _isRegistering 
                            ? '¿Ya tienes cuenta? Inicia sesión' 
                            : '¿Eres nuevo? Crea una cuenta aquí',
                          style: const TextStyle(color: AppTheme.cyan),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
