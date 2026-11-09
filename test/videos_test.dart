// Testes das regras de vídeos do sinistro (Etapa 12).
// Rodar no Mac: flutter test test/videos_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/utils/videos.dart';

class _Arq {
  final String nome;
  final int bytes;
  const _Arq(this.nome, this.bytes);
}

const mb = 1024 * 1024;

void main() {
  group('Limites', () {
    test('padrão 20 MB e 5 vídeos', () {
      const l = LimitesVideo();
      expect(l.maxMb, 20);
      expect(l.maxPorSinistro, 5);
      expect(l.maxBytes, 20 * mb);
    });
    test('normaliza valores salvos (nunca acima do teto de 100 MB)', () {
      expect(LimitesVideo.normalizarMb(500), 100);
      expect(LimitesVideo.normalizarMb(0), 20);
      expect(LimitesVideo.normalizarMb(null), 20);
      expect(LimitesVideo.normalizarQuantidade(0), 5);
      expect(LimitesVideo.normalizarQuantidade(8), 8);
    });
  });

  group('Validação da seleção', () {
    ({List<_Arq> aceitos, List<String> recusas}) validar(List<_Arq> arqs, {int existentes = 0}) =>
        Videos.validar<_Arq>(arqs,
            nome: (a) => a.nome, bytes: (a) => a.bytes, jaExistentes: existentes, limites: const LimitesVideo());

    test('aceita vídeo do WhatsApp (16 MB)', () {
      final r = validar([const _Arq('VID-20261108-WA0003.mp4', 16 * mb)]);
      expect(r.aceitos.length, 1);
      expect(r.recusas, isEmpty);
    });

    test('recusa acima de 20 MB, formato errado e o que passa da quantidade', () {
      final r = validar([
        const _Arq('a.mp4', 21 * mb),
        const _Arq('foto.jpg', 1 * mb),
        const _Arq('b.MOV', 5 * mb),
        const _Arq('c.mp4', 5 * mb),
        const _Arq('d.mp4', 5 * mb),
      ], existentes: 3);
      expect(r.aceitos.map((a) => a.nome).toList(), ['b.MOV', 'c.mp4']);
      expect(r.recusas.length, 3);
      expect(r.recusas[0].contains('limite é 20 MB'), true);
      expect(r.recusas[1].contains('formato não aceito'), true);
      expect(r.recusas[2].contains('máximo de 5'), true);
    });
  });

  group('Arquivo', () {
    test('tipo do conteúdo pela extensão', () {
      expect(Videos.contentType('x.mp4'), 'video/mp4');
      expect(Videos.contentType('x.MOV'), 'video/quicktime');
      expect(Videos.contentType('x.webm'), 'video/webm');
    });
    test('caminho com prefixo videos/ e nome sem caracteres estranhos', () {
      final c = Videos.caminho('SN2026/11', 'Vídeo do acidente (1).mp4', DateTime.fromMillisecondsSinceEpoch(1700000000000));
      expect(c, 'videos/sinistros/SN2026_11/1700000000000_V_deo_do_acidente_1_.mp4');
    });
    test('iPhone .mov pode não tocar antes da conversão', () {
      expect(Videos.podeNaoTocarNoNavegador('IMG_1234.MOV'), true);
      expect(Videos.podeNaoTocarNoNavegador('VID-WA.mp4'), false);
    });
    test('tamanho legível', () {
      expect(Videos.tamanho(12 * mb + mb ~/ 2), '12,5 MB');
      expect(Videos.tamanho(850 * 1024), '850 KB');
    });
  });

  test('ida e volta do registro gravado no sinistro', () {
    final v = VideoAnexo(
      url: 'https://x/y.mp4',
      caminho: 'videos/sinistros/S1/1_y.mp4',
      nome: 'y.mp4',
      tamanhoBytes: 1234,
      enviadoEm: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      enviadoPor: 'Ana',
    );
    final lista = VideoAnexo.listaDe([v.toMap(), 'lixo', {'url': ''}]);
    expect(lista.length, 1);
    expect(lista.single.caminho, v.caminho);
    expect(lista.single.enviadoEm, v.enviadoEm);
  });
}
