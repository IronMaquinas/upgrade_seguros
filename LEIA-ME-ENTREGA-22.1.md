# Entrega 22.1 — Consulta do CNPJ no navegador + "Nova seguradora" no portal

**Base:** GitHub `5c6882d` (Etapa 22).

## O que estava errado

1. **"A consulta à Receita não respondeu agora (403)"**
   - Na 22, eu levei a consulta à Receita para o servidor, para que o nome não pudesse ser alterado no caminho. Só que a **BrasilAPI recusa (403) as chamadas que saem dos servidores do Google**. Do seu navegador funciona, como na 17.1.
   - **Correção:** a consulta volta para o **navegador**, igual aos Dados da corretora.
   - O servidor ainda **tenta** conferir; se for barrado, usa o que o app consultou e marca a pendente com "dados consultados pelo app — confira o CNPJ" no portal.
   - O nome continua sendo **escolhido** entre o fantasia e a razão social, nunca digitado.
2. **O admin não tinha como cadastrar.** Agora o portal tem, na aba Seguradoras:
   - **Nova seguradora:** CNPJ → **Consultar na Receita** → nome (pode ajustar, porque você cuida da lista) → SUSEP (opcional) → **Criar**. Ela entra **já aprovada** e o servidor barra CNPJ ou nome repetido.
   - **Na edição** de uma seguradora, o ícone 🔎 ao lado do CNPJ consulta a Receita e grava a razão social. Serve para completar as 46 importadas, que vieram sem CNPJ.
3. **Ícones faltando no portal** (Seguradoras no menu e o do botão Importar):
   - provável cache: o navegador guardou a fonte de ícones da 21, que não tinha os ícones novos;
   - de agora em diante o portal é compilado com `--no-tree-shake-icons` (fonte completa), e isso não acontece mais.

## Arquivos (10)

| Arquivo | O que mudou |
|---|---|
| `lib/services/receita_cnpj.dart` | **Novo.** Consulta do CNPJ no navegador (a mesma da 17.1), usada pelo app e pelo portal. |
| `lib/services/catalogo_seguradoras_service.dart` | Se o servidor não consultar, consulta no navegador e manda os dados junto. |
| `lib/widgets/nova_seguradora_dialog.dart` | Envia os dados da Receita junto com a sugestão. |
| `functions/catalogo.js` | Servidor só tenta conferir (com identificação); se barrado, usa os dados do app e marca `dadosReceita: navegador`. |
| `functions/plataforma.js` | Ação `catalogoCriar` (admin cria aprovada); edição grava a razão social. |
| `functions/testes/catalogo.teste.js` | +11 testes (bloqueio 403, criar pelo admin) — 54 no total. |
| `lib/admin/aba_seguradoras_portal.dart` | Botão **Nova seguradora**; 🔎 Consultar na edição; aviso nas pendentes consultadas pelo app. |
| `lib/admin/plataforma_api.dart` · `modelos_plataforma.dart` | Chamadas e dados novos. |
| `README.md` | Catálogo (22.1) + comando do portal + histórico. |

## Aplicar

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-22.1.zip verificar-entrega.js
node verificar-entrega.js --antes        # 9 iguais ao GitHub 5c6882d + 1 novo
unzip -o ~/Downloads/entrega-22.1.zip 'lib/*' 'functions/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
git diff functions/catalogo.js
```

## Publicar

```bash
firebase deploy --only functions:plataforma,functions:catalogoSeguradoras

flutter build web -t lib/main_admin.dart --no-tree-shake-icons
rm -rf build/admin && cp -R build/web build/admin
flutter build web
firebase deploy --only hosting:admin,hosting:app
```

Depois, no portal, recarregue com **Cmd + Shift + R** (limpa o cache dos ícones).

## Testar

1. **App** → Configurações → Seguradoras → **Nova** → `16.825.255/0001-23` → Consultar.
   - Deve aparecer **SUHAI SEGURADORA S.A.** (ela não tem nome fantasia, então só aparece a razão social) → **Adicionar** → "aguardando aprovação".
2. **Portal** → Seguradoras: a SUHAI em "Aguardando aprovação", provavelmente com o aviso "dados da Receita consultados pelo app" → **Aprovar** (pode trocar o nome para "Suhai").
3. **Portal** → **Nova seguradora** → o CNPJ de uma que ainda não está na lista → Consultar → Criar.
4. **Portal** → clique numa importada (ex.: AXA) → digite o CNPJ → 🔎 → aparece "Receita: …" → Salvar. A linha passa a mostrar o CNPJ.

## Commit

```bash
git add -A lib functions README.md
git commit -m "Entrega 22.1: CNPJ consultado no navegador; portal com Nova seguradora e consulta ao editar"
GIT_ASKPASS= git push
```
