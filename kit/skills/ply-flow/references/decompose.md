# Decompor uma task grande

Sinais: >4 AC, mais de 1 arquivo em files:, título com "e", estimativa >2h.

Como:
1. Cada AC vira candidata a task própria; agrupe só o que compartilha arquivo E teste.
2. Ordene por dependência real: o que roda/compila sem o quê?
3. Para cada pedaço: ./ply new "..." --spec <a mesma> --dep "<ids>"
4. A task original vira a última (integração) ou é apagada — nunca fica de "guarda-chuva".

Corpo curto: AC + pointers. Contexto longo pertence à spec, não à task.
Tasks paralelizáveis não devem compartilhar files: — é o veto do ply next.
