import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

/// Página estática de Termos de Uso. Conteúdo placeholder — substituir
/// quando o time legal entregar a versão final.
class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          const FigmaTopNav(breadcrumb: 'TERMOS DE USO', showBackButton: true),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl, 16, AppSpacing.xxl, 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TERMOS DE USO E POLÍTICA DE PRIVACIDADE',
                    style: type.displaySm.copyWith(
                      color: palette.text,
                      fontSize: 18,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Última atualização: 24/05/2026',
                    style: type.bodyXs.copyWith(color: palette.muted),
                  ),
                  const SizedBox(height: 24),
                  _Section(
                    title: '1. ACEITE',
                    body:
                        'Ao usar o Runnin você concorda com estes Termos. '
                        'Se não concorda, não use o app — você pode excluir sua '
                        'conta a qualquer momento em Perfil → Conta & Acesso.',
                  ),
                  _Section(
                    title: '2. USO DO APP',
                    body:
                        'O Runnin é um app de treino que combina GPS, sensores '
                        'do dispositivo, dados de wearables conectados (opcional) '
                        'e inteligência artificial pra montar planos personalizados '
                        'e dar orientação em tempo real. Os planos são sugestões — '
                        'a decisão de executar é sua. Em caso de dúvida médica, '
                        'consulte um profissional antes de seguir.',
                  ),
                  _Section(
                    title: '3. DADOS COLETADOS',
                    body:
                        'Coletamos: perfil (nome, telefone, e-mail, dados '
                        'biométricos que você informa), sessões de corrida '
                        '(GPS, BPM, ritmo, distância), interações com o coach AI, '
                        'estatísticas de uso e, se autorizado, dados de wearables '
                        'conectados (Garmin, Apple Health). Não vendemos '
                        'seus dados pra terceiros.',
                  ),
                  _Section(
                    title: '4. INTELIGÊNCIA ARTIFICIAL',
                    body:
                        'O coach AI usa modelos de linguagem (Google Gemini) '
                        'pra gerar planos, dicas e feedback. As respostas são '
                        'geradas com base no seu perfil e histórico, mas podem '
                        'conter imprecisões. Use o bom senso — se algo parecer '
                        'inadequado pro seu nível ou saúde, ajuste ou consulte '
                        'um treinador humano.',
                  ),
                  _Section(
                    title: '5. ASSINATURA PREMIUM',
                    body:
                        'O plano gratuito tem acesso ao Free Run e métricas '
                        'básicas. Recursos premium (planos personalizados, coach '
                        'AI ao vivo, relatórios enriquecidos) exigem assinatura. '
                        'Você pode cancelar a qualquer momento — o acesso '
                        'continua até o fim do ciclo pago.',
                  ),
                  _Section(
                    title: '6. PROPRIEDADE INTELECTUAL',
                    body:
                        'O código, design e marca Runnin pertencem ao time '
                        'Runnin. Os dados pessoais que você gera (sessões, '
                        'estatísticas, conversas com o coach) pertencem a você '
                        '— pode exportar ou excluir a qualquer momento.',
                  ),
                  _Section(
                    title: '7. RESPONSABILIDADE',
                    body:
                        'Corrida é uma atividade física que envolve risco. O '
                        'Runnin não substitui avaliação médica nem treinador '
                        'humano. Você é responsável por respeitar seus limites, '
                        'usar equipamento adequado e treinar em locais seguros.',
                  ),
                  _Section(
                    title: '8. EXCLUSÃO DE CONTA',
                    body:
                        'A exclusão é definitiva: apaga perfil, histórico de '
                        'corridas, planos e interações com o coach. Não há '
                        'backup. Em Perfil → Conta & Acesso → Excluir Conta.',
                  ),
                  _Section(
                    title: '9. CONTATO',
                    body:
                        'Dúvidas, sugestões, exercício de direitos da LGPD '
                        '(acesso, retificação, portabilidade, exclusão): '
                        'contato@runnin.app',
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Estes Termos podem ser atualizados periodicamente. '
                    'Mudanças relevantes serão notificadas no app antes de '
                    'entrarem em vigor.',
                    style: type.bodyXs.copyWith(
                      color: palette.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: type.labelMd.copyWith(
              color: palette.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: type.bodySm.copyWith(
              color: palette.text,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
