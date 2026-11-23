# Entrega 16c.1 — correção da regra das pastas antigas (storage.rules)

**Base:** entrega 16c já copiada no projeto (ainda sem publicar).

O teste 4 do Playground (`sinistros/teste.jpg`, pasta antiga) deu erro
"Function not found: firestore.get". A regra das pastas antigas consultava o
cadastro do usuário e, a partir dele, a corretora, dentro de funções
encadeadas. Agora ela lê o cadastro uma vez só (`let`) e então a corretora.
Só essa função mudou; as regras de `corretoras/{id}/…` são as mesmas.

## Aplicar

```bash
cd ~/Projects/upgrade_seguros
unzip -o ~/Downloads/entrega-16c.1.zip verificar-entrega.js
node verificar-entrega.js --antes      # storage.rules igual ao da 16c
unzip -o ~/Downloads/entrega-16c.1.zip storage.rules
node verificar-entrega.js --analyze    # ✓ Todos
git diff storage.rules
```

Depois cole o novo `storage.rules` no Playground e refaça os 6 testes da 16c.
Daí em diante, siga o LEIA-ME da 16c a partir do Passo 2. O commit da 16c já inclui este arquivo.
