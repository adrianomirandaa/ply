# A escada — antes de escrever código novo

Pare no primeiro degrau que segurar:

1. Precisa existir? Necessidade especulativa = não faça; diga em 1 linha. (YAGNI)
2. Já existe neste codebase? Helper/util/padrão a poucos arquivos → reuse. grep antes de escrever.
3. Stdlib resolve? Use.
4. Recurso nativo da plataforma cobre? (constraint de DB > código de app; CSS > JS)
5. Dependência JÁ instalada resolve? Use. Nunca adicione dep nova pro que cabe em poucas linhas.
6. Cabe em 1 linha? 1 linha.
7. Só então: o mínimo que funciona.

Simplificação deliberada com teto conhecido ganha comentário `simplify:` nomeando
o teto e o upgrade path. Ex.: `# simplify: lock global; por-conta se throughput doer`.
A escada encurta a SOLUÇÃO, nunca a leitura do problema: entenda o fluxo inteiro antes de subir.
