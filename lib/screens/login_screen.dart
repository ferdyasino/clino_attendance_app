import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/api_helper.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  bool obscurePassword = true;

  final String apiUrl = dotenv.get("API_URL");

  final String authorizedEmail = dotenv.get("AUTHORIZED_EMAILS");

  @override
  void initState() {
    super.initState();
  }

  Future<void> login() async {
    FocusScope.of(context).unfocus();

    final email = emailController.text.trim().toLowerCase();

    final password = passwordController.text.trim();

    // EMPTY VALIDATION
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email and password are required")),
      );

      return;
    }

    final result = await ApiHelper.getWithRedirect(url: authorizedEmail);

    Map<String, dynamic>? user;

    try {
      user = result.firstWhere((item) => item["email"] == email);
    } catch (e) {
      user = null;
    }

    if (user != null) {
      if (user["sheeturl"] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("User does not have access to the system"),
          ),
        );

        return;
      }
    }

    setState(() {
      isLoading = true;
    });

    try {
      final data = await ApiHelper.postWithRedirect(
        url: apiUrl,
        body: {"action": "init_system", "email": email, "password": password},
      );

      final sheeturl = data["sheeturl"];
      debugPrint("SHEET URL: $sheeturl");

      if (data["success"] == true) {
        final List users = data["data"];

        if (users.length <= 1) {
          throw Exception("No users found");
        }

        dynamic matchedUser;

        // SKIP HEADER ROW
        for (int i = 1; i < users.length; i++) {
          final row = users[i];

          final userEmail = row[0].toString().trim().toLowerCase();

          final userPassword = row[1].toString().trim();

          final fullName = row[2].toString().trim();

          final role = row[3].toString().trim();

          if (userEmail == email) {
            matchedUser = {
              "email": userEmail,
              "password": userPassword,
              "fullName": fullName,
              "role": role,
            };

            break;
          }
        }

        debugPrint("MATCHED USER: $matchedUser");

        // USER NOT FOUND
        if (matchedUser == null) {
          throw Exception("User not found");
        }

        // PASSWORD CHECK
        if (matchedUser["password"] != password) {
          throw Exception("Invalid password");
        }

        final prefs = await SharedPreferences.getInstance();

        await prefs.setString("userEmail", matchedUser["email"]);

        await prefs.setString("fullName", matchedUser["fullName"]);

        await prefs.setString("role", matchedUser["role"]);

        debugPrint("LOGIN SUCCESS");

        debugPrint("EMAIL: ${matchedUser["email"]}");

        debugPrint("ROLE: ${matchedUser["role"]}");

        debugPrint("FULL NAME: ${matchedUser["fullName"]}");

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Welcome ${matchedUser["fullName"]}")),
        );

        // ROLE-BASED NAVIGATION
        if (matchedUser["role"] == "ADMIN") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DashboardScreen(
                userEmail: matchedUser!["email"],
                userRole: prefs.getString("role") ?? "ADMIN",
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DashboardScreen(
                userEmail: matchedUser!["email"],
                userRole: prefs.getString("role") ?? "USER",
              ),
            ),
          );
        }
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

                  // EMAIL
                  TextField(
                    controller: emailController,

                    keyboardType: TextInputType.emailAddress,

                    textInputAction: TextInputAction.next,

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

                  // PASSWORD
                  TextField(
                    controller: passwordController,

                    obscureText: obscurePassword,

                    enableSuggestions: false,

                    autocorrect: false,

                    keyboardType: TextInputType.visiblePassword,

                    textInputAction: TextInputAction.done,

                    onSubmitted: (_) => login(),

                    decoration: InputDecoration(
                      labelText: "Password",

                      prefixIcon: const Icon(Icons.lock),

                      suffixIcon: IconButton(
                        splashRadius: 20,

                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),

                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),

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
