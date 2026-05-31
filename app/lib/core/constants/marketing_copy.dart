// Centralized marketing copy — all user-visible strings for intro/coach_intro
// onboarding frequency notes and routine time hints live here.
// Edit this file to update copy without touching widget logic.

abstract final class MarketingCopy {
  // ---------------------------------------------------------------------------
  // Intro slides (IntroPage — 3 slides pre-login)
  // ---------------------------------------------------------------------------

  static const introSlide1Eyebrow = '// COACH.AI';
  static const introSlide1Title = 'Um coach que te conhece.';
  static const introSlide1Body =
      'Plano de corrida adaptado ao seu nível, objetivo, rotina e dados de saúde. '
      'Não é template genérico — é seu plano, seu pace, seu progresso.';

  static const introSlide2Eyebrow = '// CORRIDA AO VIVO';
  static const introSlide2Title = 'Guia por voz na sua corrida.';
  static const introSlide2Body =
      'O coach acompanha cada km. Avisa quando segurar o pace, quando soltar, '
      'quando descansar. Como ter um treinador no ouvido.';

  static const introSlide3Eyebrow = '// EVOLUÇÃO';
  static const introSlide3Title = 'Histórico que conta sua jornada.';
  static const introSlide3Body =
      'Todas as corridas, conquistas e relatórios em um lugar. '
      'Compartilhe seus melhores momentos com a comunidade.';

  // ---------------------------------------------------------------------------
  // Coach intro slides (CoachIntroPage — 4 slides post-plan-loading)
  // ---------------------------------------------------------------------------

  static const coachSlide1Label = '// QUEM SOU EU';
  static const coachSlide1Heading = 'Eu sou seu Coach.AI';
  static const coachSlide1Paragraph =
      'Não sou um app de cronômetro. Sou um treinador de inteligência artificial que te conhece, se adapta a você e evolui junto. Cada corrida que você faz me torna mais preciso.';
  static const coachSlide1Bullets = [
    'Analiso seu pace, BPM, splits e padrão de recuperação',
    'Comparo com milhares de corredores do seu nível',
    'Aprendo com cada sessão para refinar seu plano',
  ];

  static const coachSlide2Label = '// DURANTE A CORRIDA';
  static const coachSlide2Heading = 'Corro com você';
  static const coachSlide2Paragraph =
      'Vou te guiar por voz em tempo real. Aviso quando acelerar, quando frear, quando respirar fundo. Você só precisa correr — eu cuido dos números.';
  static const coachSlide2Bullets = [
    'Alertas de pace quando sair da zona alvo',
    'Comentários a cada km sobre seu desempenho',
    'Motivação nos últimos quilômetros mais difíceis',
    'Volume da música abaixa automaticamente quando falo',
  ];

  static const coachSlide3Label = '// PRIMEIRA CORRIDA';
  static const coachSlide3Heading = 'Essa é a calibração';
  static const coachSlide3Paragraph =
      'Na primeira corrida, vou te avaliar. Corra no seu ritmo natural — sem pressão. Preciso entender seu corpo para criar o plano perfeito.';
  static const coachSlide3Bullets = [
    'Vou medir seu pace natural em diferentes intensidades',
    'Identifico suas zonas cardíacas reais',
    'Calibro a progressão semanal pro seu nível',
    'Após essa corrida, refino todo o plano automaticamente',
  ];

  static const coachSlide4Label = '// SEU PLANO';
  static const coachSlide4Heading = 'Planejamento inteligente';
  static const coachSlide4Paragraph =
      'Trabalho com ciclos mensais e ajustes semanais. Você pode pedir revisão do plano quando precisar — eu reorganizo tudo mantendo o foco no seu objetivo.';
  static const coachSlide4Bullets = [
    'Periodização mensal com mesociclos de 4 semanas',
    'Ajuste semanal baseado em como você está respondendo',
    'Se não puder correr num dia, reequilibro a semana',
    '1 revisão de plano por semana disponível',
  ];

  // ---------------------------------------------------------------------------
  // Onboarding — frequency step coach notes
  // ---------------------------------------------------------------------------

  static const freqNote2 =
      'Otimo para comecar com constancia sem pesar a rotina. Vamos priorizar adaptacao e recuperacao.';
  static const freqNote3 =
      'Boa frequencia para criar base com seguranca. Ja da para evoluir volume e ritmo aos poucos.';
  static const freqNote4 =
      'Excelente equilibrio entre progresso e recuperacao. Costuma render planos bem completos.';
  static const freqNote5 =
      'Frequencia forte. O Coach vai distribuir carga com mais precisao para evitar excesso.';
  static const freqNote6 =
      'Rotina de alto compromisso. Vamos controlar intensidade para sustentar consistencia.';

  // ---------------------------------------------------------------------------
  // Onboarding — routine step
  // ---------------------------------------------------------------------------

  static const routineDescription =
      'O Coach usa seu horário para calcular janela metabólica ideal, lembretes de hidratação, preparo nutricional e sugestão de melhor hora para correr.';

  static const routineHintManha = 'Cortisol alto,\nqueima de gordura';
  static const routineHintTarde = 'Pico de temperatura\ncorporal';
  static const routineHintNoite = 'Força muscular\nelevada';
}
