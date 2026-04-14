import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'script_download.dart';

void main() {
  runApp(const NftablesScriptGeneratorApp());
}

class NftablesScriptGeneratorApp extends StatelessWidget {
  const NftablesScriptGeneratorApp({super.key});

  static const _appTitle =
      'Linux nftables \u81ea\u52d5\u5316\u90e8\u7f72\u8173\u672c\u7522\u751f\u5668';

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E847F),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: _appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF3F5F7),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
          ),
        ),
      ),
      home: const ScriptGeneratorPage(),
    );
  }
}

class ScriptGeneratorPage extends StatefulWidget {
  const ScriptGeneratorPage({super.key});

  @override
  State<ScriptGeneratorPage> createState() => _ScriptGeneratorPageState();
}

class _ScriptGeneratorPageState extends State<ScriptGeneratorPage> {
  static const Map<String, String> _countryOptions = {
    'tw': '\u53f0\u7063 (tw)',
    'jp': '\u65e5\u672c (jp)',
    'us': '\u7f8e\u570b (us)',
  };
  static const Map<String, String> _protocolOptions = {
    'tcp': 'TCP',
    'udp': 'UDP',
    'both': 'TCP / UDP',
  };

  final TextEditingController _adminIpController = TextEditingController();
  final TextEditingController _customPortsController = TextEditingController();

  String _selectedCountry = 'tw';
  String _webProtocol = 'tcp';
  String _customPortsProtocol = 'tcp';
  String _allPortsProtocol = 'tcp';
  bool _allowSsh = true;
  bool _allowHttpHttps = false;
  bool _allowAllPorts = false;

  String? get _customPortsError {
    final text = _customPortsController.text.trim();
    if (text.isEmpty) {
      return null;
    }

    final invalidSegments = <String>[];

    for (final segment in text.split(',')) {
      final value = segment.trim();
      if (value.isEmpty) {
        continue;
      }

      final parsed = int.tryParse(value);
      if (parsed == null || parsed < 1 || parsed > 65535) {
        invalidSegments.add(value);
      }
    }

    if (invalidSegments.isEmpty) {
      return null;
    }

    return '\u9019\u4e9b Port \u683c\u5f0f\u932f\u8aa4\u6216\u8d85\u51fa\u7bc4\u570d 1-65535: ${invalidSegments.join(', ')}';
  }

  bool get _showAdminIpWarning => _adminIpController.text.trim().isEmpty;

  @override
  void dispose() {
    _adminIpController.dispose();
    _customPortsController.dispose();
    super.dispose();
  }

  List<String> get _resolvedCustomPorts {
    final ports = <String>{};

    for (final segment in _customPortsController.text.split(',')) {
      final value = segment.trim();
      if (value.isEmpty) {
        continue;
      }

      final parsed = int.tryParse(value);
      if (parsed != null && parsed > 0 && parsed <= 65535) {
        ports.add(parsed.toString());
      }
    }

    final result = ports.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    return result;
  }

  String get _script {
    final adminIp = _adminIpController.text.trim();
    final adminRule =
        adminIp.isNotEmpty ? '        ip saddr { $adminIp } accept' : '';
    final countryPortRules = _buildCountryPortRules().join('\n');
    final countryRuleBlock = countryPortRules.isNotEmpty
        ? countryPortRules
        : '        # \\u5c1a\\u672a\\u9078\\u64c7\\u4efb\\u4f55\\u8981\\u653e\\u884c\\u7684 Port';

    return '''#!/bin/bash
echo "\u958b\u59cb\u90e8\u7f72\u81ea\u52d5\u5316\u9632\u706b\u7246\u8207\u570b\u5bb6 IP \u898f\u5247..."

# 1. \u95dc\u9589\u4e26\u7981\u7528\u885d\u7a81\u7684\u820a\u7248\u9632\u706b\u7246
systemctl disable --now firewalld ufw

# 2. \u751f\u6210\u81ea\u52d5\u66f4\u65b0 IPdeny \u570b\u5bb6 IP \u6e05\u55ae\u7684\u8173\u672c (/usr/local/bin/update_ips.sh)
cat << 'EOF' > /usr/local/bin/update_ips.sh
#!/bin/bash
URL="https://www.ipdeny.com/ipblocks/data/countries/$_selectedCountry.zone"
curl -s -o /tmp/ip.cidr \$URL
if [ -s /tmp/ip.cidr ]; then
    echo "set allow_ips { type ipv4_addr; flags interval; elements = {" > /etc/nftables/country_ips.nft
    sed 's/\$/,/' /tmp/ip.cidr >> /etc/nftables/country_ips.nft
    echo "} }" >> /etc/nftables/country_ips.nft
    nft -f /etc/nftables.conf
fi
EOF
chmod +x /usr/local/bin/update_ips.sh

# 3. \u5efa\u7acb\u4e26\u5beb\u5165 nftables \u4e3b\u8a2d\u5b9a\u6a94 (/etc/nftables.conf)
mkdir -p /etc/nftables
cat << 'EOF' > /etc/nftables.conf
flush ruleset

table inet filter {
    include "/etc/nftables/country_ips.nft"

    chain input {
        type filter hook input priority 0; policy drop;
        iifname "lo" accept
        ct state established,related accept
${adminRule.isEmpty ? '' : '$adminRule\n'}
        $countryRuleBlock
    }
}
EOF

# 4. \u8a3b\u518a\u6bcf\u65e5\u6392\u7a0b (Cron Job) \u6bcf\u5929\u51cc\u66683\u9ede\u66f4\u65b0 IP
(crontab -l 2>/dev/null | grep -v "/usr/local/bin/update_ips.sh"; echo "0 3 * * * /usr/local/bin/update_ips.sh >/dev/null 2>&1") | crontab -

# 5. \u9996\u6b21\u57f7\u884c\u6293\u53d6 IP \u4e26\u555f\u52d5\u670d\u52d9
/usr/local/bin/update_ips.sh
systemctl enable --now nftables

echo "\u90e8\u7f72\u5b8c\u6210\uff01"''';
  }

  Future<void> _copyScript() async {
    await Clipboard.setData(ClipboardData(text: _script));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Bash \u8173\u672c\u5df2\u8907\u88fd\u5230\u526a\u8cbc\u7c3f',
          ),
        ),
      );
  }

  Future<void> _downloadScript() async {
    final result = await downloadScriptFile(
      filename: 'deploy_nftables_$_selectedCountry.sh',
      content: _script,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(result.message),
        ),
      );
  }

  void _resetForm() {
    setState(() {
      _selectedCountry = 'tw';
      _webProtocol = 'tcp';
      _customPortsProtocol = 'tcp';
      _allPortsProtocol = 'tcp';
      _allowSsh = true;
      _allowHttpHttps = false;
      _allowAllPorts = false;
      _adminIpController.clear();
      _customPortsController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Linux nftables \u81ea\u52d5\u5316\u90e8\u7f72\u8173\u672c\u7522\u751f\u5668',
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 980;
            final previewHeight = compact ? 460.0 : 760.0;

            final content = compact
                ? Column(
                    children: [
                      _buildSettingsPanel(theme),
                      const SizedBox(height: 20),
                      _buildPreviewPanel(theme, height: previewHeight),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildSettingsPanel(theme),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 6,
                        child: _buildPreviewPanel(theme, height: previewHeight),
                      ),
                    ],
                  );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: content,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettingsPanel(ThemeData theme) {
    return Card(
      elevation: 10,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '\u898f\u5247\u8a2d\u5b9a',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\u5728\u5de6\u5074\u914d\u7f6e\u653e\u884c\u689d\u4ef6\uff0c'
              '\u53f3\u5074\u6703\u5373\u6642\u7522\u751f\u53ef\u76f4\u63a5\u90e8\u7f72\u5230 Linux \u7684 Bash \u8173\u672c\u3002',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _selectedCountry,
              decoration: const InputDecoration(
                labelText: '\u76ee\u6a19\u570b\u5bb6 IP \u767d\u540d\u55ae',
              ),
              items: _countryOptions.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _selectedCountry = value;
                });
              },
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _adminIpController,
              decoration: const InputDecoration(
                labelText:
                    '\u7ba1\u7406\u54e1\u56fa\u5b9a IP (\u5168\u57df\u767d\u540d\u55ae)',
                hintText:
                    '\u4f8b\u5982\uff1a1.2.3.4 (\u9078\u586b\uff0c\u9632\u6b62\u81ea\u5df1\u88ab\u9396)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_showAdminIpWarning) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFF0B44C)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFA45A00),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '\u672a\u8a2d\u5b9a\u7ba1\u7406\u54e1\u56fa\u5b9a IP\uff0c'
                        '\u82e5\u570b\u5bb6\u767d\u540d\u55ae\u672a\u6db5\u84cb\u4f60\u76ee\u524d\u7684\u4f86\u6e90\u4f4d\u5740\uff0c'
                        '\u90e8\u7f72\u5f8c\u53ef\u80fd\u9023 SSH \u90fd\u6703\u88ab\u9396\u4f4f\u3002',
                        style: TextStyle(
                          color: Color(0xFF7A4300),
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            Text(
              '\u57fa\u790e\u670d\u52d9\u653e\u884c',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _buildCheckboxCard(
              title: '\u5141\u8a31 SSH (Port 22)',
              value: _allowSsh,
              onChanged: (value) {
                setState(() {
                  _allowSsh = value ?? false;
                });
              },
            ),
            const SizedBox(height: 10),
            _buildCheckboxCard(
              title: '\u5141\u8a31 HTTP/HTTPS (Port 80, 443)',
              value: _allowHttpHttps,
              onChanged: (value) {
                setState(() {
                  _allowHttpHttps = value ?? false;
                });
              },
            ),
            const SizedBox(height: 10),
            _buildCheckboxCard(
              title:
                  '\u5141\u8a31\u767d\u540d\u55ae\u570b\u5bb6\u5b58\u53d6\u6240\u6709 Port',
              value: _allowAllPorts,
              onChanged: (value) {
                setState(() {
                  _allowAllPorts = value ?? false;
                });
              },
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _webProtocol,
              decoration: const InputDecoration(
                labelText: 'HTTP/HTTPS \u5354\u5b9a',
              ),
              items: _protocolOptions.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _webProtocol = value;
                });
              },
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _customPortsProtocol,
              decoration: const InputDecoration(
                labelText: '\u81ea\u8a02 Port \u5354\u5b9a',
              ),
              items: _protocolOptions.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _customPortsProtocol = value;
                });
              },
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _allPortsProtocol,
              decoration: const InputDecoration(
                labelText: '\u5168\u958b Port \u5354\u5b9a',
              ),
              items: _protocolOptions.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _allPortsProtocol = value;
                });
              },
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _customPortsController,
              decoration: const InputDecoration(
                labelText: '\u81ea\u8a02\u958b\u653e\u901a\u8a0a\u57e0',
                hintText:
                    '\u4f8b\u5982\uff1a8000, 11434 (\u7528\u9017\u865f\u5206\u9694\uff0c\u9078\u586b)',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,\s]')),
              ],
              keyboardType: TextInputType.number,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
            ),
            if (_customPortsError != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _customPortsError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoChip(
                  label: '\u570b\u5bb6\u4ee3\u78bc: $_selectedCountry',
                  icon: Icons.public,
                ),
                const _InfoChip(
                  label: 'SSH: TCP',
                  icon: Icons.terminal_rounded,
                ),
                _InfoChip(
                  label:
                      'HTTP/HTTPS: ${_protocolOptions[_webProtocol]!}',
                  icon: Icons.language_rounded,
                ),
                _InfoChip(
                  label: _resolvedCustomPorts.isEmpty
                      ? _allowAllPorts
                          ? 'Port: \u5168\u958b'
                          : '\u76ee\u524d\u7121\u958b\u653e Port'
                      : _allowAllPorts
                          ? 'Port: \u5168\u958b'
                          : 'Port: ${_resolvedCustomPorts.join(', ')}',
                  icon: Icons.hub_outlined,
                ),
                _InfoChip(
                  label:
                      '\u81ea\u8a02 Port: ${_protocolOptions[_customPortsProtocol]!}',
                  icon: Icons.tune_rounded,
                ),
                _InfoChip(
                  label:
                      '\u5168\u958b Port: ${_protocolOptions[_allPortsProtocol]!}',
                  icon: Icons.all_inclusive_rounded,
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetForm,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('\u4e00\u9375\u91cd\u8a2d'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewPanel(
    ThemeData theme, {
    required double height,
  }) {
    return SizedBox(
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0E1621),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 28,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bash \u8173\u672c\u9810\u89bd',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\u4f9d\u7167\u76ee\u524d\u8868\u55ae\u8a2d\u5b9a\u5373\u6642\u751f\u6210',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _copyScript,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('\u4e00\u9375\u8907\u88fd'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _downloadScript,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF3B4F65)),
                    ),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('\u4e0b\u8f09 .sh'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF213041)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: SelectableText(
                  _script,
                  style: const TextStyle(
                    color: Color(0xFFD7E1EA),
                    fontSize: 14,
                    height: 1.6,
                    fontFamilyFallback: [
                      'Consolas',
                      'Menlo',
                      'Monaco',
                      'Courier New',
                      'monospace',
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxCard({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Material(
      color: const Color(0xFFF7FAFC),
      borderRadius: BorderRadius.circular(20),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.leading,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(title),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
      ),
    );
  }

  List<String> _buildCountryPortRules() {
    if (_allowAllPorts) {
      return _buildProtocolRules(
        destination: '0-65535',
        protocol: _allPortsProtocol,
      );
    }

    final rules = <String>{};

    if (_allowSsh) {
      rules.add('        ip saddr @allow_ips tcp dport { 22 } accept');
    }

    if (_allowHttpHttps) {
      rules.addAll(
        _buildProtocolRules(
          destination: '{ 80, 443 }',
          protocol: _webProtocol,
        ),
      );
    }

    final customPorts = _resolvedCustomPorts;
    if (customPorts.isNotEmpty) {
      rules.addAll(
        _buildProtocolRules(
          destination: '{ ${customPorts.join(', ')} }',
          protocol: _customPortsProtocol,
        ),
      );
    }

    return rules.toList();
  }

  List<String> _buildProtocolRules({
    required String destination,
    required String protocol,
  }) {
    switch (protocol) {
      case 'udp':
        return [
          '        ip saddr @allow_ips udp dport $destination accept',
        ];
      case 'both':
        return [
          '        ip saddr @allow_ips tcp dport $destination accept',
          '        ip saddr @allow_ips udp dport $destination accept',
        ];
      case 'tcp':
      default:
        return [
          '        ip saddr @allow_ips tcp dport $destination accept',
        ];
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F2F1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF14635F)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF14635F),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
