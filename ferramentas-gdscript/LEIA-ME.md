# Ferramentas do 3º passe (GDScript)

**Não publicar esta pasta.** Só os 6 arquivos da raiz vão para o Netlify.

Esta máquina não tem Python nem Node, então `validar.py` e `equilibra2.py` não
rodam aqui. Estes scripts fazem o mesmo trabalho pelo Godot em modo headless.

Godot usado: `C:\dev\tools\godot\Godot_v4.7-stable_win64_console.exe`

```bash
G="C:/dev/tools/godot/Godot_v4.7-stable_win64_console.exe"
cd ferramentas-gdscript

# medir o viés e listar as questões acima de 20 chars de folga
"$G" --headless --path . -s banco.gd -- medir ../index.html

# validação completa (campos, fonte, duplicatas, embaralhaOrdem, VERSAO do sw)
"$G" --headless --path . -s banco.gd -- validar ../index.html ../sw.js

# extrair o banco para JSON
"$G" --headless --path . -s banco.gd -- extrair ../index.html /tmp/banco.json

# aplicar um patch e regravar o array BANCO no index.html
"$G" --headless --path . -s banco.gd -- aplicar ../index.html patches/patch01.json

# conferir a folga só das questões citadas num patch
"$G" --headless --path . -s banco.gd -- folgas ../index.html patches/patch01.json
```

Formato do patch — mesmo espírito do dicionário do `equilibra2.py`:

```json
{ "27": { "o": ["...", "...", "...", "...", "..."], "c": 1 } }
```

A chave é o índice da questão no array `BANCO`; `o` precisa ter 5 alternativas e
`c` é o índice da correta. `aplicar` recusa o patch inteiro se algo estiver errado.

## Auditoria

- `conferir.gd <original.json> <final.json>` — garante que nenhuma resposta
  correta, enunciado, explicação ou fonte foi alterada; só distratores.
- `explorar.gd <banco.json> [limiar]` — simula o candidato que chuta na
  alternativa visivelmente mais longa e mostra quanto ele acertaria.
- `rank.gd`, `perfil.gd` — distribuição de comprimentos das alternativas.

## Round-trip

`extrair` → `aplicar` com patch vazio devolve o `index.html` byte a byte
idêntico. Foi assim que se garantiu que o CSS/JS do app não é tocado: só as
852 linhas entre `const BANCO = [` e `];` mudam.

## Patches deste passe

`patch01`–`patch12` = as 299 questões com folga acima de 20 caracteres.
`p2_01`–`p2_05` = as 115 questões da faixa 11–20.
