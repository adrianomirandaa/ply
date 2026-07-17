# ply — processo (mantenha curto; skills definem técnica, isto define processo)

Estado do trabalho fica em tasks/*.md, lido sob demanda via ./ply.
NUNCA leia o backlog inteiro; puxe só a task da vez.

## Loop
0. export PLY_AS=<seu-nome>   (uma vez por sessão)
1. ./ply next                 → id (NONE = nada desbloqueado)
2. ./ply claim <id>           (falhou a corrida? volte ao 1)
3. ./ply brief <id>           — leia SÓ isto; abra specs/ apenas se o AC não bastar
4. ./ply start <id>
5. TDD: teste do AC (RED) → código mínimo (GREEN) → refatore
6. Decisão não-óbvia? ./ply log <id> "..."
7. ./ply done <id>            — gate reprovou? conserte o código; NUNCA afrouxe teste
8. Pegadinha aprendida? ./ply lesson "causa-raiz + fix"

## Regras duras
- Um doing por agente. Não pule o check. Não invente que fez: o gate prova.
- Task grande (>4 AC, >1 arquivo, título com "e")? Skill ply-flow → decompose.md.
- Início de sessão: tail -20 tasks/LESSONS.md (se existir).
