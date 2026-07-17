# Definition of Done — done = provado

done exige, nesta ordem:
1. Todos os arquivos de files: existem no disco.
2. O teste de test: passa (TEST_CMD do .ply/config).
3. Lógica não-trivial (branch, loop, parser, dinheiro/segurança) deixou um check
   executável mínimo: o menor assert que quebra se a lógica quebrar.
4. Nenhum teste/lint foi afrouxado para passar. Gate vermelho = conserte o código
   ou registre nova task; jamais edite o teste para caber no código.

./ply done prova 1–2 automaticamente. 3–4 são responsabilidade sua — e o journal
registra o que você alegou, então alegue apenas o que o disco confirma.
