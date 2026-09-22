import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jarvis/controller/speech_controller.dart';
import 'package:jarvis/services/jarvis_gateway.dart';
import 'package:provider/provider.dart';

class Jarvis extends StatefulWidget {
  const Jarvis({super.key});

  @override
  State<Jarvis> createState() => _JarvisState();
}

class _JarvisState extends State<Jarvis> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  final _commandController = TextEditingController();
  String _gatewayUrl = 'http://127.0.0.1:5000';
  String _gatewayToken = '';
  String _gatewayStatus = 'NOT CHECKED';
  String _response = 'Ready. Connect to your local JARVIS gateway.';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SpeechController>().onFinalCommand = _sendCommand;
    });
  }

  @override
  void dispose() {
    context.read<SpeechController>().onFinalCommand = null;
    _pulse.dispose();
    _commandController.dispose();
    super.dispose();
  }

  JarvisGateway get _gateway => JarvisGateway(baseUrl: _gatewayUrl, token: _gatewayToken);

  Future<void> _checkGateway() async {
    setState(() => _gatewayStatus = 'CHECKING');
    final result = await _gateway.health();
    if (!mounted) return;
    setState(() => _gatewayStatus = result.ok ? 'ONLINE' : 'OFFLINE');
    _showResponse(result.message);
  }

  Future<void> _sendCommand([String? value]) async {
    final command = (value ?? _commandController.text).trim();
    if (command.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _response = 'Processing: $command';
    });
    _commandController.clear();
    var result = await _gateway.command(command);
    final plan = result.payload?['plan'];
    if (result.ok && plan is Map<String, dynamic> &&
        plan['confirmation_required'] == true && plan['allowed'] != true) {
      if (mounted) setState(() => _busy = false);
      final approved = await _confirmSkill(plan, command);
      if (!approved || !mounted) {
        if (mounted) _showResponse('Canceled: confirmation not granted.');
        return;
      }
      setState(() => _busy = true);
      result = await _gateway.command(command, confirmation: true);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok) {
      _showResponse(result.message);
      return;
    }
    final finalPlan = result.payload?['plan'];
    final selectedSkill = finalPlan is Map<String, dynamic>
        ? finalPlan['selected_skill']?.toString()
        : null;
    _showResponse(selectedSkill == null
        ? 'Gateway accepted: $command'
        : 'Skill $selectedSkill approved: command planned.');
  }

  Future<bool> _confirmSkill(Map<String, dynamic> plan, String command) async {
    if (!mounted) return false;
    final skill = plan['selected_skill']?.toString() ?? 'unknown skill';
    final risk = plan['risk']?.toString().toUpperCase() ?? 'UNKNOWN';
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF071322),
        title: const Text('Confirmation required', style: TextStyle(color: Color(0xFFFFB36B))),
        content: Text(
          'JARVIS matched $skill ($risk).\n\n$command\n\nAllow this skill to proceed?',
          style: const TextStyle(color: Colors.white, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ALLOW ONCE'),
          ),
        ],
      ),
    );
    return approved == true;
  }

  void _showResponse(String text) {
    if (mounted) setState(() => _response = text);
  }

  Future<void> _editConnection() async {
    final url = TextEditingController(text: _gatewayUrl);
    final token = TextEditingController(text: _gatewayToken);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF071322),
        title: const Text('Gateway connection', style: TextStyle(color: Color(0xFFB8FCFF))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: url, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Laptop URL', labelStyle: TextStyle(color: Color(0xFF72F4FF)))),
          TextField(controller: token, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Bearer token', labelStyle: TextStyle(color: Color(0xFF72F4FF)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('SAVE')),
        ],
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        _gatewayUrl = url.text.trim();
        _gatewayToken = token.text;
        _gatewayStatus = 'NOT CHECKED';
      });
    }
    url.dispose();
    token.dispose();
  }

  void _toggleListening(SpeechController speech) {
    if (speech.isListening) {
      speech.stopListening();
    } else if (speech.speechEnabled) {
      speech.startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    final speech = context.watch<SpeechController>();
    final isListening = speech.isListening;

    return Scaffold(
      backgroundColor: const Color(0xFF030814),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(isListening: isListening, onSettings: _editConnection, onCheck: _checkGateway),
              const SizedBox(height: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, child) => CustomPaint(
                        painter: _ReactorPainter(
                          progress: _pulse.value,
                          listening: isListening,
                        ),
                        child: SizedBox(
                          width: 282,
                          height: 282,
                          child: Center(
                            child: GestureDetector(
                              onTap: () => _toggleListening(speech),
                              child: Container(
                                width: 112,
                                height: 112,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF071B2D),
                                  border: Border.all(
                                    color: isListening
                                        ? const Color(0xFF73F7FF)
                                        : const Color(0xFF1AB9D0),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00D9FF)
                                          .withOpacity(isListening ? .55 : .25),
                                      blurRadius: isListening ? 34 : 20,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isListening ? Icons.stop : Icons.mic_none,
                                  color: const Color(0xFFB8FCFF),
                                  size: 42,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isListening ? 'LISTENING' : 'JARVIS STANDBY',
                      style: GoogleFonts.shareTech(
                        color: const Color(0xFF72F4FF),
                        letterSpacing: 3,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 72),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF071322),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF123D55)),
                      ),
                      child: Text(
                        speech.lastWords.isEmpty
                            ? _response
                            : speech.lastWords,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.rajdhani(
                          color: Colors.white.withOpacity(.9),
                          fontSize: 18,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    enabled: !_busy,
                    onSubmitted: _sendCommand,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ask JARVIS...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(.35)),
                      filled: true,
                      fillColor: const Color(0xFF071322),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Color(0xFF123D55)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _busy ? null : _sendCommand,
                  icon: const Icon(Icons.send, color: Color(0xFF72F4FF)),
                ),
              ]),
              const SizedBox(height: 10),
              Row(
                children: const [
                  _StatusCard(label: 'CORE', value: 'ONLINE'),
                  SizedBox(width: 10),
                  _StatusCard(label: 'VOICE', value: 'READY'),
                  SizedBox(width: 10),
                  _StatusCard(label: 'MODE', value: 'LOCAL'),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'GATEWAY $_gatewayStatus • $_gatewayUrl',
                  style: const TextStyle(color: Color(0xFF498DA1), fontSize: 9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isListening, required this.onSettings, required this.onCheck});

  final bool isListening;
  final VoidCallback onSettings;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'J.A.R.V.I.S',
              style: GoogleFonts.orbitron(
                color: const Color(0xFFB8FCFF),
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            Text(
              isListening ? 'VOICE LINK ACTIVE' : 'PERSONAL OPERATING SYSTEM',
              style: GoogleFonts.shareTech(
                color: const Color(0xFF498DA1),
                fontSize: 10,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        Row(children: [
          IconButton(
            onPressed: onCheck,
            icon: const Icon(Icons.sync, color: Color(0xFF72F4FF)),
            tooltip: 'Check gateway',
          ),
          IconButton(
            onPressed: onSettings,
            icon: const Icon(Icons.tune, color: Color(0xFF72F4FF)),
            tooltip: 'Gateway settings',
          ),
        ]),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF071322),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF123D55)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.shareTech(
                color: const Color(0xFF498DA1),
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.orbitron(
                color: const Color(0xFFB8FCFF),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactorPainter extends CustomPainter {
  const _ReactorPainter({required this.progress, required this.listening});

  final double progress;
  final bool listening;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.shortestSide / 2;
    final glow = Paint()
      ..color = const Color(0xFF00D9FF).withOpacity(listening ? .16 : .08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawCircle(center, base * .65, glow);

    for (var i = 0; i < 3; i++) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == 1 ? 2.5 : 1
        ..color = Color.lerp(
          const Color(0xFF0C6A84),
          const Color(0xFF6CF7FF),
          listening ? progress : .35,
        )!.withOpacity(i == 1 ? .9 : .55);
      final radius = base * (.49 + i * .12);
      canvas.drawCircle(center, radius, ring);
    }

    final sweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFB8FCFF).withOpacity(.85);
    final rect = Rect.fromCircle(center: center, radius: base * .61);
    canvas.drawArc(rect, progress * 6.28, 1.1, false, sweep);
    canvas.drawArc(rect, progress * 6.28 + 3.14, .55, false, sweep);
  }

  @override
  bool shouldRepaint(covariant _ReactorPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.listening != listening;
}
