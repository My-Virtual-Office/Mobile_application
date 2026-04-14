import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'home_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _httpCtrl;
  late TextEditingController _wsCtrl;
  late TextEditingController _userIdCtrl;
  String _selectedRole = 'USER';

  @override
  void initState() {
    super.initState();
    final p = context.read<ConnectionProvider>();
    _httpCtrl = TextEditingController(text: p.httpUrl);
    _wsCtrl = TextEditingController(text: p.wsUrl);
    _userIdCtrl = TextEditingController(text: '${p.userId}');
    _selectedRole = p.userRole;
  }

  @override
  void dispose() {
    _httpCtrl.dispose();
    _wsCtrl.dispose();
    _userIdCtrl.dispose();
    super.dispose();
  }

  // ─── Connect ──────────────────────────────────────────────
  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    await context.read<ConnectionProvider>().connect(
      httpUrl: _httpCtrl.text,
      wsUrl: _wsCtrl.text,
      userId: int.parse(_userIdCtrl.text.trim()),
      userRole: _selectedRole,
    );

    // ✅ بعد ما connect يخلص، لو نجح ادخل على HomeScreen
    if (!mounted) return;
    final provider = context.read<ConnectionProvider>();
    if (provider.isConnected) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  void _fillAndroid() {
    setState(() {
      _httpCtrl.text = 'http://10.0.2.2:8084';
      _wsCtrl.text = 'ws://10.0.2.2:8084';
    });
  }

  void _fillLocalhost() {
    setState(() {
      _httpCtrl.text = 'http://localhost:8084';
      _wsCtrl.text = 'ws://localhost:8084';
    });
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSecondary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildCard(),
                  const SizedBox(height: 16),
                  _buildAuthNote(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.hub_rounded,
            color: AppTheme.primary,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Virtual Office',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Connect to your local chat service',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Consumer<ConnectionProvider>(
      builder: (context, provider, _) {
        final isConnecting = provider.isConnecting;

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
          ),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Server ─────────────────────────────
                _sectionTitle('Server'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Quick fill:',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _QuickFillChip(
                      label: 'Android emulator',
                      onTap: _fillAndroid,
                    ),
                    const SizedBox(width: 6),
                    _QuickFillChip(label: 'Localhost', onTap: _fillLocalhost),
                  ],
                ),
                const SizedBox(height: 14),

                _label('HTTP URL'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _httpCtrl,
                  enabled: !isConnecting,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'http://10.0.2.2:8084',
                    prefixIcon: Icon(Icons.link_rounded, size: 18),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'HTTP URL is required';
                    if (!v.startsWith('http://') && !v.startsWith('https://'))
                      return 'Must start with http:// or https://';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                _label('WebSocket URL'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _wsCtrl,
                  enabled: !isConnecting,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'ws://10.0.2.2:8084',
                    prefixIcon: Icon(
                      Icons.electrical_services_rounded,
                      size: 18,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'WebSocket URL is required';
                    if (!v.startsWith('ws://') && !v.startsWith('wss://'))
                      return 'Must start with ws:// or wss://';
                    return null;
                  },
                ),

                const SizedBox(height: 22),
                const Divider(),
                const SizedBox(height: 22),

                // ─── Identity ────────────────────────────
                _sectionTitle('Identity'),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warningSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.warning.withOpacity(0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: AppTheme.warning,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No JWT locally — the chat service reads X-User-Id '
                          'and X-User-Role headers directly (normally set by Nginx).',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF633806),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User ID
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('User ID'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _userIdCtrl,
                            enabled: !isConnecting,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              hintText: '1',
                              prefixIcon: Icon(Icons.person_rounded, size: 18),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Required';
                              if (int.tryParse(v.trim()) == null)
                                return 'Must be a number';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Role
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Role'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.shield_outlined, size: 18),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'USER',
                                child: Text('USER'),
                              ),
                              DropdownMenuItem(
                                value: 'ADMIN',
                                child: Text('ADMIN'),
                              ),
                            ],
                            onChanged: isConnecting
                                ? null
                                : (v) => setState(
                                    () => _selectedRole = v ?? 'USER',
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ─── Error banner ────────────────────────
                if (provider.errorMessage != null) ...[
                  _ErrorBanner(message: provider.errorMessage!),
                  const SizedBox(height: 16),
                ],

                // ─── Connect button ──────────────────────
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isConnecting ? null : _connect,
                    child: isConnecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.rocket_launch_rounded, size: 16),
                              SizedBox(width: 8),
                              Text('Connect'),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 16),
                _StatusHint(status: provider.status),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuthNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgTertiary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.terminal_rounded,
                size: 13,
                color: AppTheme.textTertiary,
              ),
              SizedBox(width: 6),
              Text(
                'Run the service locally',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _CodeLine('docker compose up -d'),
          _CodeLine('./mvnw spring-boot:run'),
          const SizedBox(height: 6),
          const Text(
            'Starts on http://localhost:8084  •  Use 10.0.2.2:8084 on Android emulator',
            style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppTheme.textPrimary,
    ),
  );

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppTheme.textSecondary,
    ),
  );
}

// ─── Sub-widgets ──────────────────────────────────────────────

class _CodeLine extends StatelessWidget {
  final String code;
  const _CodeLine(this.code);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Text(
            '\$ ',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textTertiary,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            code,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickFillChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickFillChip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.error,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusHint extends StatelessWidget {
  final ConnectionStatus status;
  const _StatusHint({required this.status});
  @override
  Widget build(BuildContext context) {
    final (text, color, icon) = switch (status) {
      ConnectionStatus.idle => (
        'Enter server details and tap Connect',
        AppTheme.textTertiary,
        Icons.info_outline_rounded,
      ),
      ConnectionStatus.connecting => (
        'Checking health → connecting WebSocket...',
        AppTheme.primary,
        Icons.sync_rounded,
      ),
      ConnectionStatus.connected => (
        'Connected successfully!',
        AppTheme.success,
        Icons.check_circle_outline_rounded,
      ),
      ConnectionStatus.failed => (
        'Connection failed — see error above',
        AppTheme.error,
        Icons.cancel_outlined,
      ),
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: color),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
