// test/arquivos_test.dart — Etapa 16c
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/utils/arquivos.dart';

void main() {
  const b = 'upgrade-seguros.firebasestorage.app';
  const antigo = 'https://storage.googleapis.com/$b/sinistros/SN1/fotos/1700_foto 1.jpg';
  const novo = 'https://firebasestorage.googleapis.com/v0/b/$b/o/'
      'corretoras%2Femp1%2Fsinistros%2FSN1%2Ffotos%2F1700_foto%201.jpg?alt=media&token=abc-123';

  group('caminhoDoArquivo', () {
    test('link antigo', () {
      expect(Arquivos.caminhoDoArquivo(antigo), 'sinistros/SN1/fotos/1700_foto 1.jpg');
    });
    test('link novo (com %2F e token)', () {
      expect(Arquivos.caminhoDoArquivo(novo), 'corretoras/emp1/sinistros/SN1/fotos/1700_foto 1.jpg');
    });
    test('caminho simples e vazio', () {
      expect(Arquivos.caminhoDoArquivo('/videos/sinistros/1/a.mp4'), 'videos/sinistros/1/a.mp4');
      expect(Arquivos.caminhoDoArquivo(''), null);
      expect(Arquivos.caminhoDoArquivo(null), null);
    });
    test('outro site não é arquivo do Storage', () {
      expect(Arquivos.caminhoDoArquivo('https://exemplo.com/a.jpg'), null);
    });
  });

  group('nome e extensão', () {
    test('mesmo nome nos dois formatos', () {
      expect(Arquivos.nomeDoArquivo(antigo), '1700_foto 1.jpg');
      expect(Arquivos.nomeDoArquivo(novo), '1700_foto 1.jpg');
    });
    test('link desconhecido: último pedaço sem ?…', () {
      expect(Arquivos.nomeDoArquivo('https://exemplo.com/pasta/laudo.pdf?x=1'), 'laudo.pdf');
      expect(Arquivos.nomeDoArquivo(''), 'arquivo');
    });
    test('extensão do link novo não leva o token junto', () {
      expect(Arquivos.extensao(novo), 'jpg');
      expect(Arquivos.extensao('https://storage.googleapis.com/$b/a/LAUDO.PDF'), 'pdf');
      expect(Arquivos.extensao('https://storage.googleapis.com/$b/a/sem_extensao'), '');
    });
    test('abreviado não quebra nome curto', () {
      expect(Arquivos.abreviado('https://storage.googleapis.com/$b/a/b.pdf', 10), 'b.pdf');
      expect(Arquivos.abreviado(novo, 10), '1700_foto …');
    });
  });
}
