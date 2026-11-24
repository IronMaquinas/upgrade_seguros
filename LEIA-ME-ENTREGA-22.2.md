# Entrega 22.2 — "Já está na lista" logo na consulta + edição com os dados da Receita

**Base:** GitHub `59cfdef` (Etapa 22.1).

## O que muda

1. **App** (Nova seguradora pelo CNPJ):
   - Ao clicar em **Consultar**, o app já confere se o CNPJ **ou o nome da Receita** batem com uma seguradora da lista. Exemplo: SUHAI SEGURADORA S.A. bate com SUHAI.
   - Se bater, mostra na hora "Essa seguradora já está na lista como SUHAI", com o botão **Usar esta**. Antes isso só aparecia depois de clicar em Adicionar.
   - Se o servidor der qualquer erro na consulta, o app consulta direto no navegador.
2. **Portal → Nova seguradora:** a mesma conferência acontece logo após **Consultar na Receita**.
   - Se já existe: aviso "Já está na lista como SUHAI (sem CNPJ)" e o botão **Completar "SUHAI"**, que abre a edição dela com o CNPJ e os dados da Receita já preenchidos.
   - Se não existe: o nome vem preenchido e os botões **Usar "…"** trocam entre nome fantasia e razão social sem digitar.
3. **Portal → editar** (o fluxo que você sugeriu: Buscar CNPJ → dados encontrados → Salvar):
   - 🔎 mostra o quadro **"Encontrado na Receita"** (razão social, nome fantasia, situação), com o texto **selecionável** (dá para copiar);
   - o **Nome na lista já é trocado** pelo da Receita (fantasia, se houver; senão razão social);
   - **Manter "SUHAI"** volta ao nome antigo; **Usar "…"** troca entre fantasia e razão;
   - embaixo do nome aparece "Antes: SUHAI (vira apelido e os registros são atualizados)";
   - se o CNPJ já for de **outra** seguradora da lista, avisa e sugere "Juntar com…".

## Arquivos (5)

| Arquivo | O que mudou |
|---|---|
| `lib/services/catalogo_seguradoras_service.dart` | Confere nome parecido logo na consulta; consulta no navegador se o servidor falhar. |
| `functions/catalogo.js` | A consulta do servidor também devolve "existente" por nome parecido. |
| `functions/testes/catalogo.teste.js` | +1 teste (55). |
| `lib/admin/aba_seguradoras_portal.dart` | Nova seguradora: aviso + "Completar"; edição: dados da Receita, nome preenchido, Manter/Usar. |
| `README.md` | Histórico 22.2. |

## Aplicar e publicar

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-22.2.zip verificar-entrega.js
node verificar-entrega.js --antes        # 5 iguais ao GitHub 59cfdef
unzip -o ~/Downloads/entrega-22.2.zip 'lib/*' 'functions/*' README.md
node verificar-entrega.js --analyze      # ✓ Todos
git diff --stat

firebase deploy --only functions:catalogoSeguradoras

flutter build web -t lib/main_admin.dart --no-tree-shake-icons
rm -rf build/admin && cp -R build/web build/admin
flutter build web
firebase deploy --only hosting:admin,hosting:app
```

Para testar antes de publicar o site, depois do deploy da Function:
- portal: `flutter run -d chrome -t lib/main_admin.dart`
- app: `flutter run -d chrome`

## Testar

1. **Portal → Nova seguradora** → `16.825.255/0001-23` → Consultar.
   - Deve aparecer "Já está na lista como SUHAI (sem CNPJ)" → **Completar "SUHAI"**.
   - Na edição: o nome já vem "SUHAI SEGURADORA S.A." e o CNPJ preenchido → **Salvar**.
   - A linha passa a mostrar o CNPJ, e "SUHAI" vira apelido.
2. **Portal → clique em outra importada** (ex.: AXA) → digite o CNPJ → 🔎.
   - Aparece o quadro verde e o nome trocado. Use **Manter "AXA"** se preferir o curto → **Salvar**.
3. **App → Configurações → Seguradoras → Nova** → CNPJ da SUHAI → Consultar → "já está na lista como …" na hora → **Usar esta**.

## Commit

```bash
git add -A lib functions README.md
git commit -m "Entrega 22.2: já está na lista na consulta do CNPJ; portal completa a existente com os dados da Receita"
GIT_ASKPASS= git push
```
