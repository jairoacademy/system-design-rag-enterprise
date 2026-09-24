---
name: java-quality-gate
description: Gate de qualidade verificável para o backend Java deste repositório — testes unitários com JUnit + Mockito, 100% de cobertura de linha (JaCoCo) e 100% de mutantes mortos (pitest), tudo por um único `./mvnw verify`. Use sempre que for implementar, alterar, revisar ou testar classes Java em `app/backend`, e quando o usuário disser "quality gate", "rodar os testes", "verificar cobertura", "cobertura de mutação", "pitest" ou "os testes estão fracos". Use mesmo que o pedido seja só "implementa tal serviço" — código novo sem passar pelo gate não está pronto.
compatibility: Requer Maven wrapper em app/backend e acesso ao Maven Central.
---

# Quality gate do backend Java

Esta skill não ensina a escrever teste — isso é papel da skill `java-springboot`.
Ela define **quando o código está pronto** e o que fazer quando não está.

## O gate

```bash
cd app/backend && ./mvnw verify
```

Um comando, uma resposta: passou ou não passou. Os limites vivem no `pom.xml`
(`jacoco-maven-plugin` com regra `LINE COVEREDRATIO 1.00` e `pitest-maven` com
`mutationThreshold 100`), então o build falha sozinho.

Não escreva script bash/python para conferir cobertura. Um script seria uma
segunda fonte de verdade que diverge do `pom.xml` na primeira alteração, e o
número que ele imprime não reprova nada — o que reprova é o build.

## Escopo

Vale 100% em `academy.jairo.ragenterprise.**`, exceto:

- `NotebooklmApplication` (a classe `main`)
- `**/config/**` (classes `@Configuration`)

**Exclusão nova exige aprovação explícita do usuário.** Esse é o ponto em que o
gate normalmente apodrece: basta o agente excluir o pacote que está incomodando
e o número volta a 100% sem que nenhum teste tenha melhorado. Se você acredita
que algo deveria sair do escopo, pare e pergunte, com o motivo.

## O fluxo

1. Escreva a classe.
2. Escreva os testes unitários (JUnit + Mockito, conforme `java-springboot`).
3. Rode o gate.
4. Se falhar, leia o relatório certo e corrija **o teste**, não o limite.

Cobertura de linha é o piso, não a meta. O pitest é que diz se o teste
verifica alguma coisa: um teste que executa a linha mas não afirma nada sobre o
resultado dá 100% no JaCoCo e 0% no pitest.

## Lendo as falhas

| Sintoma | Relatório | O que significa |
|---|---|---|
| `Rule violated ... lines covered ratio` | `target/site/jacoco/index.html` | Existe linha que nenhum teste executa. |
| `Mutation score of N is below threshold` | `target/pitest-reports/index.html` | O teste executa a linha mas não detecta quando ela muda. |

No relatório do pitest, o status do mutante diz o que fazer:

- `NO_COVERAGE` — nenhum teste chega ali. Escreva o teste.
- `SURVIVED` — o teste chega e não percebe a mudança. Falta assertion sobre o efeito.
- `TIMED_OUT` / `MEMORY_ERROR` — conta como morto, pode seguir.

Heurísticas que matam a maior parte dos sobreviventes:

- **Teste na fronteira.** O mutador `CONDITIONALS_BOUNDARY` troca `>` por `>=`.
  Só um caso exatamente no limite e outro logo ao lado distinguem os dois.
- **Afirme o valor de retorno**, não só que não lançou exceção — os mutadores
  `FALSE_RETURNS`, `NULL_RETURNS` e `EMPTY_RETURNS` vivem desse descuido.
- **Método `void`**: verifique o efeito colateral (`verify` do Mockito no
  colaborador), senão `VOID_METHOD_CALLS` remove a chamada impunemente.

## Regras que não se negociam

Existem porque todas têm o mesmo atalho: fazer o número subir sem que a suíte
fique melhor. Um gate contornado é pior que gate nenhum — dá a impressão de
proteção que não existe.

- Teste sem assertion não conta. Nada de `assertTrue(true)` nem de teste que só
  verifica que não estourou exceção.
- Não enfraqueça nem apague o teste que está falhando para o build passar.
- Não baixe `mutationThreshold` nem a regra do JaCoCo.
- Não adicione exclusão por conta própria (ver **Escopo**).

## Quando parar

Se depois de 3 tentativas o gate ainda não passar, pare e reporte: quais
mutantes sobreviveram, em que linha, e o que você já tentou. Um mutante
verdadeiramente equivalente — uma mudança que nenhum teste pode detectar porque
não altera comportamento observável — existe, é raro, e a decisão de conviver
com ele é do usuário, não sua.
