// lib/main.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Complaint + Local OTP Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginPage(),
    );
  }
}

/// Endpoints helper (only predict uses network)
class Endpoints {
  static String hostForPlatform() {
    try {
      if (kIsWeb) return 'http://127.0.0.1:8000';
      // For Android emulator use 10.0.2.2, for physical device use LAN IP
      if (Platform.isAndroid) return 'http://127.0.0.1:8000';
      return 'http://127.0.0.1:8000';
    } catch (_) {
      return 'http://127.0.0.1:8000';
    }
  }

  static String predict() => '${hostForPlatform()}/api/predict/';
}

/// Login page with local OTP logic
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _aadharController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isSendingOtp = false;
  bool _isLoggingIn = false;
  String _status = '';

  String? _generatedOtp;
  DateTime? _otpCreatedAt;

  @override
  void dispose() {
    _aadharController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String _makeOtp() {
    final rnd = Random.secure();
    final code = rnd.nextInt(900000) + 100000;
    return code.toString();
  }

  Future<void> _sendOtpLocal() async {
    final aadhar = _aadharController.text.trim();
    if (aadhar.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter Aadhaar ID')));
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _status = 'Generating OTP...';
    });

    await Future.delayed(const Duration(milliseconds: 400));

    final otp = _makeOtp();
    _generatedOtp = otp;
    _otpCreatedAt = DateTime.now();

    setState(() {
      _isSendingOtp = false;
      _status = 'OTP generated locally';
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('OTP (local): $otp')));
  }

  Future<void> _loginLocal() async {
    final aadhar = _aadharController.text.trim();
    final otp = _otpController.text.trim();

    if (aadhar.isEmpty || otp.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter Aadhaar and OTP')));
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _status = 'Verifying OTP...';
    });

    await Future.delayed(const Duration(milliseconds: 300));

    final expired =
        _otpCreatedAt == null ||
        DateTime.now().difference(_otpCreatedAt!).inMinutes >= 5;

    if (_generatedOtp == null || expired) {
      setState(() {
        _isLoggingIn = false;
        _status = 'OTP expired or not generated. Request a new OTP.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP expired or not generated')),
      );
      return;
    }

    if (otp != _generatedOtp) {
      setState(() {
        _isLoggingIn = false;
        _status = 'Incorrect OTP';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Incorrect OTP')));
      return;
    }

    final token = base64Url.encode(
      utf8.encode('$aadhar:${DateTime.now().toIso8601String()}'),
    );
    setState(() {
      _isLoggingIn = false;
      _status = 'Login successful';
    });

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ComplaintPage(authToken: token)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login (Local OTP)')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _aadharController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Aadhaar ID',
                  hintText: '123412341234',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'OTP',
                        hintText: 'Enter OTP',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSendingOtp ? null : _sendOtpLocal,
                    child: _isSendingOtp
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send OTP'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _isLoggingIn ? null : _loginLocal,
                child: _isLoggingIn
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Login'),
              ),
              const SizedBox(height: 12),
              Text(_status),
              const SizedBox(height: 8),
              const Text(
                'Note: OTP is generated locally and shown in a SnackBar for testing.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Complaint page (after login)
class ComplaintPage extends StatefulWidget {
  final String? authToken;
  const ComplaintPage({super.key, required this.authToken});
  @override
  State<ComplaintPage> createState() => _ComplaintPageState();
}

class _ComplaintPageState extends State<ComplaintPage> {
  final TextEditingController _complaintController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  bool _reportsSamePlace = false;
  bool _isSending = false;
  String _status = 'Ready';
  String _responseBody = '';

  @override
  void dispose() {
    _complaintController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _sendClassificationRequest() async {
    final text = _complaintController.text.trim();
    final location = _locationController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint text cannot be empty')),
      );
      return;
    }

    final url = Uri.parse(Endpoints.predict());

    setState(() {
      _isSending = true;
      _status = 'Sending...';
      _responseBody = '';
    });

    final payload = {
      'text': text,
      'reports_same_place': _reportsSamePlace ? 1 : 0,
      'location': location,
    };

    final headers = {'Content-Type': 'application/json'};
    if (widget.authToken != null && widget.authToken!.isNotEmpty) {
      headers['Authorization'] = 'Token ${widget.authToken}';
    }

    try {
      final resp = await http.post(
        url,
        headers: headers,
        body: jsonEncode(payload),
      );
      setState(() {
        _status = 'HTTP ${resp.statusCode}';
        _responseBody = resp.body;
      });
    } catch (e) {
      setState(() {
        _status = 'Network error: $e';
        _responseBody = e.toString();
      });
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _logout() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  /// Format response JSON into user-friendly view (no categories)
  Widget _buildFormattedResponse(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;

      final severity = data['severity']?.toString();
      final priority = data['priority']?.toString();
      final subcategories =
          (data['subcategory'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final subConfs =
          (data['subcategory_conf'] as List<dynamic>?)?.map((e) {
            if (e is num) return e.toDouble();
            try {
              return double.parse(e.toString());
            } catch (_) {
              return 0.0;
            }
          }).toList() ??
          [];

      final entries = <MapEntry<String, double>>[];
      for (var i = 0; i < subcategories.length; i++) {
        final label = subcategories[i];
        final conf = i < subConfs.length ? subConfs[i] : 0.0;
        entries.add(MapEntry(label, conf));
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (severity != null)
            Text(
              "Severity: $severity",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          if (priority != null)
            Text(
              "Priority: $priority",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          const SizedBox(height: 12),
          if (entries.isNotEmpty)
            const Text(
              "Subcategories:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ...entries.map((e) {
            final confPct = (e.value * 100).toStringAsFixed(1);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "• ${e.key}",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(
                    "$confPct%",
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    } catch (_) {
      return Text(body);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Complaint'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Complaint',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _complaintController,
                maxLines: 6,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Describe the issue...',
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Location (optional)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Street, building, city',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Reports same place'),
                  const Spacer(),
                  Switch(
                    value: _reportsSamePlace,
                    onChanged: (v) => setState(() => _reportsSamePlace = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isSending ? null : _sendClassificationRequest,
                child: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send'),
              ),
              const SizedBox(height: 12),
              Text(
                'Status: $_status',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'AI Response:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: _responseBody.isEmpty
                        ? const Text('(no response yet)')
                        : _buildFormattedResponse(_responseBody),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
