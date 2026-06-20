# 📋 ROTEIRO DE REFATORAÇÃO: MOVER PICKER DE RAMO PARA DASHBOARD

## ⚠️ IMPORTANTE
Este roteiro foi criado para máxima segurança. Você executa cada passo, não eu. Assim nada se perde.

---

## 🎯 OBJETIVO FINAL
```
ANTES:
Dashboard FAB → SpreadsheetClaimScreen → (picker de ramo abre DENTRO)

DEPOIS:
Dashboard FAB → Picker de Ramo (FORA) → SpreadsheetClaimScreen
```

---

## 📋 CHECKLIST DOS PASSOS

- [ ] **PASSO 1**: Copiar função do picker de spreadsheet_claim_screen
- [ ] **PASSO 2**: Criar função global no dashboard
- [ ] **PASSO 3**: Atualizar FAB do dashboard
- [ ] **PASSO 4**: Remover picker de spreadsheet_claim_screen
- [ ] **PASSO 5**: Atualizar claim_list_screen
- [ ] **PASSO 6**: Testes finais

---

# 🔧 COMEÇAR AQUI

## PASSO 1️⃣: COPIAR A FUNÇÃO `_showRamoPicker()` 

### Arquivo: `spreadsheet_claim_screen.dart`

**Local exato**: Linhas 1575-1712 (função `_showRamoPicker` completa)

### O que fazer:
1. Abra `spreadsheet_claim_screen.dart`
2. Pressione `Ctrl+G` (Go to Line)
3. Digite `1575` e pressione Enter
4. Selecione a função COMPLETA até a linha 1712 (inclua `_ramoToLabel`)
5. **COPIE** tudo (`Ctrl+C`)
6. Abra um **arquivo de texto temporário** ou notepad
7. **COLE** lá como backup

### Código que vai copiar (para referência):
```
⬇️ COMECE AQUI (linha 1575):
  Future<void> _showRamoPicker() async {
    const ramos = [
      _RamoOption(label: 'Veículo / Frota',...
      ...
    ];
    
    final ramo = await showDialog<String>(...);
    
    if (ramo != null && mounted) {
      setState(() {
        _ramoSelecionado = ramo;
        ...
      });
    } else if (ramo == null && mounted) {
      Navigator.of(context).pop();
    }
    _initControllers();
  }

  String _ramoToLabel(String ramo) {
    switch (ramo) {
      ...
    }
  }
⬆️ TERMINE AQUI (linha 1712)
```

✅ **Após fazer isso**: Marque ☑️ no checklist acima

---

## PASSO 2️⃣: COPIAR CLASSE `_RamoOption`

### Arquivo: `spreadsheet_claim_screen.dart`

Você precisa também de uma classe chamada `_RamoOption` que está nesse arquivo.

### O que fazer:
1. Em `spreadsheet_claim_screen.dart`, pressione `Ctrl+F` (Find)
2. Procure por: `class _RamoOption`
3. **Copie** essa classe completa (deve estar em torno da linha 2800+)
4. **Salve em seu arquivo de backup temporário**

### Ele deve parecer assim:
```dart
class _RamoOption {
  final String label;
  final IconData icon;
  final String ramo;
  final Color color;

  const _RamoOption({
    required this.label,
    required this.icon,
    required this.ramo,
    required this.color,
  });
}
```

✅ **Após fazer isso**: Marque ☑️ no checklist acima

---

## PASSO 3️⃣: ADICIONAR NO `dashboard_screen.dart`

### Arquivo: `lib/screens/dashboard_screen.dart`

### Importar `OptionPickerDialog`:
1. Abra `dashboard_screen.dart`
2. No topo, procure por todas as importações
3. **Após** a linha: `import '../widgets/dashboard_content.dart';`
4. **Adicione esta linha**:
```dart
import '../widgets/option_picker_dialog.dart';
```

### Adicionar classe `_RamoOption` no final do arquivo:
1. Vá para o **FIM** do arquivo `dashboard_screen.dart`
2. **ANTES** do último `}`
3. **Cole a classe `_RamoOption`** que você copiou no passo 2

### Adicionar função `_showRamoPickerGlobal`:
1. No `_DashboardScreenState`, procure por um método público (ex: `_onItemTapped`)
2. **Após** esse método, **COLE** a função `_showRamoPicker` que você copiou
3. **Renomeie** a função de `_showRamoPicker` para `_showRamoPickerGlobal`

```dart
// ⬇️ COLE AQUI, mudando o nome:
Future<void> _showRamoPickerGlobal() async {
  // ... cola da função inteira ...
}

// ⬇️ COLE AQUI também:
String _ramoToLabel(String ramo) {
  // ... cola do método ...
}
```

✅ **Após fazer isso**: Marque ☑️ no checklist acima

---

## PASSO 4️⃣: ATUALIZAR O FAB DO DASHBOARD

### Arquivo: `lib/screens/dashboard_screen.dart`

### Localizar o FAB:
1. Abra `dashboard_screen.dart`
2. Procure por: `floatingActionButton` (deve estar no método `build`)
3. Procure pela lógica que abre o modal de "Novo Sinistro"

### Alterar o comportamento:
**ANTES** (como está agora):
```dart
floatingActionButton: FloatingActionButton(
  onPressed: () => _showOpenClaimModal(),
  ...
)
```

**DEPOIS** (o que fazer):
```dart
floatingActionButton: FloatingActionButton(
  onPressed: () => _showNewItemDialog(),
  ...
)
```

### Criar função `_showNewItemDialog`:
Procure onde estão os métodos como `_showOpenSinistroModal` e `_showOpenClaimModal`.

**AFTER** desses métodos, **ADICIONE**:
```dart
// Dialog unificado: Sinistro ou Assistência
Future<void> _showNewItemDialog() async {
  const options = [
    PickerOption(
      label: 'Sinistro',
      value: 'sinistro',
      icon: Icons.assignment_outlined,
      color: Color(0xFF1565C0),
      description: 'Novo registro de sinistro',
    ),
    PickerOption(
      label: 'Assistência',
      value: 'assistencia',
      icon: Icons.emergency_outlined,
      color: Color(0xFF2E7D32),
      description: 'Novo atendimento assistencial',
    ),
  ];

  final tipo = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => OptionPickerDialog(
      title: 'Novo Documento',
      subtitle: 'Selecione o tipo de registro',
      options: options,
    ),
  );

  if (tipo == 'sinistro' && mounted) {
    // Abre picker de ramo
    await _showRamoPickerGlobal();
  } else if (tipo == 'assistencia' && mounted) {
    // Abre picker de tipo de assistência (assist_list_screen)
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AssistListScreen(),
    ));
  }
}
```

✅ **Após fazer isso**: Marque ☑️ no checklist acima

---

## PASSO 5️⃣: ATUALIZAR `_showRamoPickerGlobal` NO DASHBOARD

### Arquivo: `lib/screens/dashboard_screen.dart`

A função que você colou (renomeada para `_showRamoPickerGlobal`) precisa de um pequeno ajuste.

### Encontrar este trecho na função:
```dart
if (ramo != null && mounted) {
  setState(() {
    _ramoSelecionado = ramo;
    // ... resto do código ...
  });
}
```

### Substituir por:
```dart
if (ramo != null && mounted) {
  // Abre SpreadsheetClaimScreen diretamente com o ramo
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => SpreadsheetClaimScreen(ramoSelecionado: ramo),
  ));
} else if (ramo == null && mounted) {
  // Usuário cancelou, volta ao dashboard
  // (já está)
}
```

⚠️ **IMPORTANTE**: `SpreadsheetClaimScreen` precisa aceitar `ramoSelecionado` como parâmetro.

### Verificar `SpreadsheetClaimScreen`:
1. Abra `spreadsheet_claim_screen.dart`
2. Procure pela classe `SpreadsheetClaimScreen extends StatefulWidget`
3. Verifique se o construtor já tem `ramoSelecionado`:
```dart
class SpreadsheetClaimScreen extends StatefulWidget {
  final String? ramoSelecionado;  // ← verificar se tem isso

  const SpreadsheetClaimScreen({
    super.key,
    this.ramoSelecionado,  // ← adicionar se não tiver
  });
```

Se NÃO tiver, você precisa adicionar esse parâmetro. Vou indicar onde na próxima parte.

✅ **Após fazer isso**: Marque ☑️ no checklist acima

---

## PASSO 6️⃣: REMOVER `_showRamoPicker` DE `spreadsheet_claim_screen.dart`

### Arquivo: `lib/screens/spreadsheet_claim_screen.dart`

### O que fazer:
1. Abra `spreadsheet_claim_screen.dart`
2. Procure pela função `_showRamoPicker` (linha ~1575)
3. **SELECIONE** a função COMPLETA (até `_ramoToLabel` inclusive) - linhas 1575-1712
4. **DELETE** (pressione Delete ou Backspace)

### Verificar se `_initControllers()` chama `_showRamoPicker`:
1. Procure pela função `_initControllers()`
2. Se ela tem uma linha tipo: `_showRamoPicker();`
3. **MUDE** para: `_openRamoPickerAndLoadRamo();` (será a nova função que você vai criar)

### Criar nova função `_openRamoPickerAndLoadRamo`:
Procure no código onde o método `initState` está.

**ADICIONE** esta função:
```dart
Future<void> _openRamoPickerAndLoadRamo() async {
  // Se o ramo já foi passado como parâmetro, use-o
  if (widget.ramoSelecionado != null) {
    _loadRamo(widget.ramoSelecionado!);
    return;
  }
  
  // Caso contrário, volta para tela anterior
  // (o picker já foi aberto no dashboard)
  if (mounted) {
    Navigator.of(context).pop();
  }
}

void _loadRamo(String ramo) {
  setState(() {
    _ramoSelecionado = ramo;
    _ramoSelecionadoLabel = _ramoToLabel(ramo);
    
    if (ramo == 'Transporte') {
      _groups = [
        _buildGroups()[0],
        ..._buildTransporteGroups(),
        _buildGroups()[2],
        _buildGroups()[3],
      ];
    } else if (ramo == 'Máquinas') {
      _groups = [
        _buildGroups()[0],
        ..._buildMaquinasGroups(),
        _buildGroups()[3],
      ];
    } else if (ramo == 'Residencial') {
      _groups = [
        _buildGroups()[0],
        ..._buildResidencialGroups(),
        _buildGroups()[3],
      ];
    } else if (ramo == 'Vidas') {
      _groups = [
        _buildGroups()[0],
        ..._buildVidaGroups(),
        _buildGroups()[3],
      ];
    } else {
      _groups = _buildGroups();
    }
  });
  _initControllers();
}
```

✅ **Após fazer isso**: Marque ☑️ no checklist acima

---

## PASSO 7️⃣: ATUALIZAR `claim_list_screen.dart`

### Arquivo: `lib/screens/claim_list_screen.dart`

### Adicionar botão "Novo Sinistro" com picker:
1. Procure pelo botão "Novo Sinistro" em claim_list_screen
2. **Atualize** para chamar `_showRamoPickerGlobal` (que agora está no dashboard)

**MAIS SIMPLES**: Apenas mude o comportamento do botão para:
```dart
onPressed: () => Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => SpreadsheetClaimScreen()),
),
```

Assim ele vai direto para SpreadsheetClaimScreen, que vai checar se tem `ramoSelecionado` passado.

✅ **Após fazer isso**: Marque ☑️ no checklist acima

---

## 🧪 TESTES FINAIS

### Teste 1: Dashboard FAB
1. Abra o app
2. Clique no FAB "Novo"
3. Verifique se abre picker com "Sinistro" e "Assistência"
4. Clique em "Sinistro"
5. Verifique se abre picker de Ramo
6. Clique em um ramo (ex: "Veículo / Frota")
7. Verifique se abre SpreadsheetClaimScreen

### Teste 2: Assistência
1. Na tela de Picker "Novo"
2. Clique em "Assistência"
3. Verifique se abre AssistListScreen com picker de Veicular/Residencial

### Teste 3: Claim List Screen
1. Abra Sinistros na NavigationRail
2. Clique em "Novo Sinistro"
3. Verifique se abre SpreadsheetClaimScreen (pode pedir ramo ou abrir direto)

✅ **Se todos os testes passarem**: Parabéns! Refatoração concluída!

---

## 🆘 SE DER ERRO

Se aparecer erro do tipo:
- `The method '_showRamoPickerGlobal' isn't defined`
  → Verifique se você colou a função no dashboard_screen.dart
  
- `_RamoOption is not defined`
  → Verifique se você colou a classe `_RamoOption` no final do dashboard_screen.dart

- `Unexpected non-null assertion operator used`
  → Alguma variável que não existe. Volte ao passo anterior e verifique.

**Se tiver erro**, **NÃO tente consertar sozinho**. Me mande:
- O erro completo (copy-paste)
- O arquivo onde o erro aparece
- A linha exata do erro

---

## 📌 RESUMO DO QUE FOI FEITO

✅ Picker de Ramo saiu de SpreadsheetClaimScreen
✅ Picker de Ramo agora está no Dashboard
✅ Dashboard tem picker unificado: Sinistro | Assistência
✅ Sinistro → Picker Ramo → SpreadsheetClaimScreen
✅ Assistência → Picker Tipo → SpreadsheetAssistScreen
✅ QuickClaimScreen fica como atalho em claim_list_screen
✅ Interface profissional e consistente!

---

**Boa sorte! 🚀**
