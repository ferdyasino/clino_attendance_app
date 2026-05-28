import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  final String apiUrl = dotenv.get("API_URL");

  Future<void> login() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email and password are required")),
      );

      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "action": "init_system",
              "email": emailController.text.trim(),
              "password": passwordController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint("STATUS: ${response.statusCode}");
      debugPrint("HEADERS: ${response.headers}");
      debugPrint("BODY: ${response.body}");

      final contentType = response.headers['content-type'] ?? "";

      if (response.statusCode != 200) {
        throw Exception("Server returned ${response.statusCode}");
      }

      if (!contentType.contains("application/json")) {
        throw Exception("Server did not return JSON");
      }

      if (!response.body.trim().startsWith("{")) {
        throw Exception("Invalid JSON response");
      }

      final data = jsonDecode(response.body);

      if (data["success"] == true) {
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString("spreadsheetId", data["data"]["spreadsheetId"]);

        await prefs.setString("spreadsheetUrl", data["data"]["url"]);

        await prefs.setString("userEmail", emailController.text.trim());

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("System initialized successfully")),
        );

        debugPrint("Spreadsheet ID: ${data["data"]["spreadsheetId"]}");

        debugPrint("Spreadsheet URL: ${data["data"]["url"]}");

        // TODO:
        // Navigate to dashboard screen
      } else {
        throw Exception(data["message"] ?? "Login failed");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ LOGIN ERROR: $e");
      debugPrint("STACK TRACE:\n$stackTrace");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        color: colorScheme.surface,

        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [
                  Icon(
                    Icons.access_time_filled,
                    size: 80,
                    color: colorScheme.primary,
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "Clino Attendance",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "Login to continue",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),

                  const SizedBox(height: 30),

                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,

                    decoration: InputDecoration(
                      labelText: "Email",
                      prefixIcon: const Icon(Icons.email),

                      border: const OutlineInputBorder(),

                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: passwordController,
                    obscureText: true,

                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: const Icon(Icons.lock),

                      border: const OutlineInputBorder(),

                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 50,

                    child: ElevatedButton(
                      onPressed: isLoading ? null : login,

                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("Login"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
