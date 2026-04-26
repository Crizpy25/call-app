import 'package:flutter/material.dart';
import 'package:peerdart/peerdart.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

// ─────────────────────────────────────────────
//  CONFIGURATION
//  The admin panel HTML uses the ID below.
//  If you change it here, change it in admin.html too.
// ─────────────────────────────────────────────
const String kAdminPeerId = 'admin-dashboard-xyz';

void main() => runApp(const MaterialApp(home: MessengerCallScreen()));

class MessengerCallScreen extends StatefulWidget {
  const MessengerCallScreen({super.key});

  @override
  State<MessengerCallScreen> createState() => _MessengerCallScreenState();
}

class _MessengerCallScreenState extends State<MessengerCallScreen> {
  late Peer _peer;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  MediaConnection? _activeCall;

  bool _isCalling = false;
  bool _peerReady = false;
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initRenderer();
    _initPeer();
  }

  Future<void> _initRenderer() async {
    await _remoteRenderer.initialize();
  }

  void _initPeer() {
    // Creates a random peer ID each time the app starts.
    // If you want a fixed ID for your user, pass a string: Peer(id: 'my-user-id')
    _peer = Peer();

    _peer.on('open').listen((_) {
      setState(() {
        _peerReady = true;
        _statusMessage = 'Ready to call';
      });
    });

    _peer.on('error').listen((error) {
      setState(() => _statusMessage = 'Connection error: $error');
    });

    _peer.on('disconnected').listen((_) {
      setState(() {
        _peerReady = false;
        _statusMessage = 'Disconnected – retrying...';
      });
      Future.delayed(const Duration(seconds: 3), () => _peer.reconnect());
    });
  }

  Future<void> _startCall() async {
    // 1. Request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() => _statusMessage = 'Microphone permission denied');
      return;
    }

    try {
      // 2. Capture local audio
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      // 3. Call the admin panel
      final call = _peer.call(kAdminPeerId, _localStream!);
      _activeCall = call;

      setState(() {
        _isCalling = true;
        _statusMessage = 'Calling admin...';
      });

      // 4. When admin answers, play their audio
      call.on<MediaStream>('stream').listen((remoteStream) {
        setState(() => _statusMessage = 'Connected');
        _remoteRenderer.srcObject = remoteStream;
      });

      // 5. Handle call closed by admin
      call.on('close').listen((_) => _hangUp());

      call.on('error').listen((_) => _hangUp());
    } catch (e) {
      debugPrint('Error starting call: $e');
      setState(() => _statusMessage = 'Failed to start call');
      _hangUp();
    }
  }

  void _hangUp() {
    _activeCall?.close();
    _activeCall = null;

    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;

    _remoteRenderer.srcObject = null;

    if (mounted) {
      setState(() {
        _isCalling = false;
        _statusMessage = _peerReady ? 'Ready to call' : 'Reconnecting...';
      });
    }
  }

  void _toggleCall() {
    if (_isCalling) {
      _hangUp();
    } else {
      _startCall();
    }
  }

  @override
  void dispose() {
    _hangUp();
    _remoteRenderer.dispose();
    _peer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Avatar ──────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: _isCalling
                      ? [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 8,
                    )
                  ]
                      : [],
                ),
                child: const CircleAvatar(
                  radius: 54,
                  backgroundColor: Color(0xFF2A2A2A),
                  child: Icon(Icons.support_agent, size: 54, color: Colors.white54),
                ),
              ),

              const SizedBox(height: 20),

              // ── Name ────────────────────────────────
              const Text(
                'Admin Support',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              // ── Status ──────────────────────────────
              Text(
                _statusMessage,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),

              const SizedBox(height: 64),

              // ── Call Button ─────────────────────────
              GestureDetector(
                onTap: _peerReady ? _toggleCall : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: !_peerReady
                        ? Colors.grey.shade800
                        : _isCalling
                        ? Colors.red
                        : Colors.blueAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (!_peerReady
                            ? Colors.transparent
                            : _isCalling
                            ? Colors.red
                            : Colors.blueAccent)
                            .withOpacity(0.4),
                        blurRadius: 24,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isCalling ? Icons.call_end : Icons.phone,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Text(
                !_peerReady
                    ? 'Connecting...'
                    : _isCalling
                    ? 'Tap to hang up'
                    : 'Start Wi-Fi Call',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}