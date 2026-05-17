import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/shared/widgets/runnin_app_bar.dart';

/// Paywall pós-assessment ou ao tentar acessar feature premium.
///
/// Versão atual: UI + flag manual. "ASSINAR" seta `premium=true` via PATCH /users/me
/// (sem cobrança real). Quando integrar Stripe/StoreKit, troca o handler.
///
/// Anônimo cai aqui automaticamente. Pode ir freemium (continuar grátis sem IA).
class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key, this.nextRoute = '/home'});

  /// Pra onde ir depois de assinar (ou continuar grátis).
  final String nextRoute;

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  final _dio = apiClient;
  String _priceLabel = 'R\$ 19,90';
  String _periodLabel = '/mês';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPricing();
  }

  Future<void> _loadPricing() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/admin/pricing');
      final d = res.data ?? {};
      if (mounted) {
        setState(() {
          _priceLabel = (d['priceLabel'] as String?) ?? _priceLabel;
          _periodLabel = (d['periodLabel'] as String?) ?? _periodLabel;
          _loading = false;
        });
      }
    } catch (_) {
      // Endpoint público de pricing pode não existir; usa defaults
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _subscribe() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _dio.patch<void>('/users/me', data: {'premium': true});
      if (!mounted) return;
      context.go(widget.nextRoute);
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Não foi possível assinar agora: $e';
        _saving = false;
      });
    }
  }

  void _continueFree() => context.go(widget.nextRoute);

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: const RunninAppBar(title: 'PREMIUM', fallbackRoute: '/home'),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Libere todo o coach.',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: palette.text,
                        letterSpacing: -0.8,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sem premium você corre, registra e compartilha. Com premium, o coach AI '
                      'cria seu plano, te guia ao vivo e usa seus exames + wearable.',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: palette.muted,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _PricingCard(
                      price: _priceLabel,
                      period: _periodLabel,
                      saving: _saving,
                      onSubscribe: _subscribe,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: palette.error, fontSize: 12)),
                    ],
                    const SizedBox(height: 28),
                    Text(
                      'COMPARAÇÃO',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11, fontWeight: FontWeight.w500,
                        color: palette.muted, letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _ComparisonRow(label: 'Registro de corridas', free: true, premium: true),
                    const _ComparisonRow(label: 'Histórico + estatísticas', free: true, premium: true),
                    const _ComparisonRow(label: 'Compartilhar conquistas', free: true, premium: true),
                    const _ComparisonRow(label: 'Plano de treino personalizado (AI)', free: false, premium: true),
                    const _ComparisonRow(label: 'Coach ao vivo durante corrida', free: false, premium: true),
                    const _ComparisonRow(label: 'Análise pós-corrida + insights', free: false, premium: true),
                    const _ComparisonRow(label: 'Integração com wearable', free: false, premium: true),
                    const _ComparisonRow(label: 'Análise de exames (OCR)', free: false, premium: true),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: _saving ? null : _continueFree,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: palette.border, width: 1.041),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      child: Text(
                        'CONTINUAR GRÁTIS',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: palette.text,
                          letterSpacing: 1.2,
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

class _PricingCard extends StatelessWidget {
  final String price;
  final String period;
  final bool saving;
  final VoidCallback onSubscribe;
  const _PricingCard({required this.price, required this.period, required this.saving, required this.onSubscribe});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.primary, width: 1.041),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: context.runninPalette.primary, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('PREMIUM', style: GoogleFonts.jetBrainsMono(
                fontSize: 11, fontWeight: FontWeight.w500, color: palette.primary, letterSpacing: 1.4,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: GoogleFonts.jetBrainsMono(
                fontSize: 36, fontWeight: FontWeight.w500, color: palette.text, letterSpacing: -1.0, height: 1.0,
              )),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(period, style: GoogleFonts.jetBrainsMono(
                  fontSize: 13, fontWeight: FontWeight.w600, color: palette.muted,
                )),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: saving ? null : onSubscribe,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: palette.primary,
              alignment: Alignment.center,
              child: saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
                      'ASSINAR ↗',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black, letterSpacing: 1.4,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final bool free;
  final bool premium;
  const _ComparisonRow({required this.label, required this.free, required this.premium});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: GoogleFonts.jetBrainsMono(
              fontSize: 12, fontWeight: FontWeight.w500, color: palette.text,
            )),
          ),
          SizedBox(width: 60, child: Center(child: _Mark(active: free))),
          SizedBox(width: 60, child: Center(child: _Mark(active: premium, premiumColor: true))),
        ],
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  final bool active;
  final bool premiumColor;
  const _Mark({required this.active, this.premiumColor = false});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    if (!active) {
      return Icon(Icons.close, size: 16, color: palette.muted.withValues(alpha: 0.5));
    }
    return Icon(Icons.check, size: 18, color: premiumColor ? palette.primary : palette.text);
  }
}
