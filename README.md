# Supply Chain Security — Desafio DevSecOps 02

## 1. Objetivo

Implementar controles de segurança para proteger a cadeia de suprimentos de software (*Software Supply Chain Security*), abrangendo análise de vulnerabilidades, geração de SBOM, aplicação de políticas de segurança, publicação de imagens de containers e assinatura e verificação de integridade com Cosign.

O objetivo é demonstrar como identificar riscos, aplicar controles preventivos e produzir evidências que permitam investigar possíveis incidentes de segurança.

## 2. Ambiente utilizado

- Sistema operacional: macOS, arquitetura ARM64 (Apple Silicon M1).
- Docker Desktop.
- Aplicação: Node.js.
- Gerenciamento de dependências: npm.
- Análise de vulnerabilidades: Trivy.
- Geração de SBOM: Syft.
- Políticas de segurança: Open Policy Agent (OPA) e Conftest.
- Assinatura de imagens: Cosign.
- Registro de imagens: GitHub Container Registry (GHCR).
- Repositório: https://github.com/CaioVRS21/desafio-devsecops02

### Ferramentas utilizadas

| Ferramenta | Versão |
|---|---|
| Docker | 29.9.2 |
| OPA | 1.22.1 |
| Conftest | 0.71.1 |
| Syft | 1.56.0 |
| Trivy | 0.76.1 |
| Cosign | 3.1.4 |

## 3. Etapas executadas

### 3.1. Análise de vulnerabilidades

Foi realizada a análise das imagens Docker com Trivy, identificando vulnerabilidades presentes nas dependências da aplicação e nos componentes da imagem-base.

Durante a análise inicial, foram identificadas vulnerabilidades na versão 4.17.20 do Lodash:

- CVE-2021-23337 — severidade HIGH.
- CVE-2026-4800 — severidade HIGH.

A dependência foi atualizada para a versão 4.18.1.

Após a atualização, as vulnerabilidades identificadas no Lodash deixaram de aparecer na análise. Entretanto, foram encontradas vulnerabilidades em dependências do npm incluídas na imagem-base Node.js, especificamente `brace-expansion` e `undici`.

Essas ocorrências foram identificadas em caminhos internos da instalação do npm na imagem-base e não devem ser consideradas corrigidas apenas pela atualização do Lodash.

### 3.2. Geração de SBOM

Foi utilizada a ferramenta Syft para gerar inventários de componentes de software (*Software Bill of Materials*).

Foram gerados os seguintes arquivos:

- `sbom/desafio-devsecops02-before.json`
- `sbom/desafio-devsecops02-after.json`
- `sbom/desafio-devsecops02-secure.json`

Esses arquivos registram os componentes e suas versões presentes nas respectivas imagens analisadas.

A SBOM permite identificar quais dependências fazem parte da aplicação e facilita investigações futuras sobre componentes vulneráveis.

### 3.3. Policy as Code

Foi implementada uma política de segurança utilizando OPA e Conftest, localizada em:

`policies/main.rego`

A política verifica se os containers definidos nos manifests Kubernetes atendem aos seguintes requisitos:

1. `runAsNonRoot: true` — execução sem privilégios de root.
2. `privileged: false` — proibição de execução em modo privilegiado.
3. `allowPrivilegeEscalation: false` — bloqueio da escalada de privilégios.
4. `readOnlyRootFilesystem: true` — sistema de arquivos raiz somente leitura.

O manifesto analisado foi:

`manifests/deployement.yaml`

Após a implementação das regras e correção do manifesto, foi executado o teste:

`conftest test manifests/deployement.yaml -p policies`

Resultado:

**4 testes aprovados, 0 avisos, 0 falhas e 0 exceções.**

### 3.4. Construção e validação da imagem segura

Foi atualizado o Dockerfile para aplicar boas práticas de segurança.

Principais configurações:

- Utilização da imagem-base Node.js Alpine.
- Instalação das dependências de produção com `npm ci --omit=dev`.
- Cópia dos arquivos da aplicação com proprietário `node`.
- Definição de `NODE_ENV=production`.
- Execução do container com `USER node`.
- Exposição da porta 3000.

A imagem foi construída com:

`docker build -t desafio-devsecops02:secure .`

Em seguida, foi executada com o sistema de arquivos raiz somente leitura:

`docker run -d --read-only -p 3001:3000 --name desafio-api-secure desafio-devsecops02:secure`

Foram realizados dois testes:

**Identificação do usuário do container:**

`docker exec desafio-api-secure id`

Resultado:

`uid=1000(node) gid=1000(node) groups=1000(node)`

**Teste de funcionamento da API:**

`curl http://localhost:3001/`

A aplicação respondeu:

`{"application":"Supply chain security lab","version":"before","status":"running"}`

Os testes demonstraram que a aplicação funciona utilizando um usuário não-root e com o sistema de arquivos raiz em modo somente leitura.

### 3.5. Publicação no GHCR

A imagem segura foi publicada no GitHub Container Registry.

Identificação:

`ghcr.io/caiovrs21/desafio-devsecops02:secure`

Digest publicado:

`sha256:c83ef8ca302172c98345357cebdd070825b0e2e9a98ca86ded8ad16ee8191169`

O uso do digest permite identificar precisamente o conteúdo da imagem, independentemente da tag utilizada.

### 3.6. Assinatura com Cosign

Foi utilizada a assinatura keyless do Cosign, baseada na identidade OIDC do GitHub e na infraestrutura Sigstore.

Comando utilizado:

`cosign sign "$IMAGE"`

A assinatura foi realizada sem a necessidade de armazenar uma chave privada de assinatura localmente.

A identidade identificada no certificado foi:

- Identidade: `91073227+CaioVRS21@users.noreply.github.com`
- Emissor OIDC: `https://github.com/login/oauth`

A assinatura foi registrada no log de transparência Rekor.

### 3.7. Verificação da assinatura

Foi realizada a verificação da imagem utilizando a identidade e o emissor OIDC específicos:

`cosign verify --certificate-identity "91073227+CaioVRS21@users.noreply.github.com" --certificate-oidc-issuer "https://github.com/login/oauth" "$IMAGE"`

Resultado:

**Verification successful.**

A verificação confirmou:

- Validade das claims da assinatura.
- Existência das informações correspondentes no log de transparência.
- Validade do certificado de assinatura perante as autoridades certificadoras confiáveis.
- Correspondência entre a identidade do certificado e a identidade esperada.

### 3.8. Teste de adulteração da imagem

Para demonstrar a importância da assinatura digital, foi realizado um teste controlado de adulteração.

A imagem original permaneceu intacta e assinada.

Foi alterado o campo `version` da resposta da API de `before` para `tampered`, em uma branch separada:

`test/tampered-image`

A alteração foi registrada em um commit:

`Alteração para teste de imagem adulterada`

Foi construída uma nova imagem:

`docker build -t desafio-devsecops02:tampered .`

A imagem foi publicada no GHCR com uma tag diferente:

`ghcr.io/caiovrs21/desafio-devsecops02:tampered`

Digest da imagem alterada:

`sha256:f3bddc29afa663738f19176e955cb0ae21e00d6f0cfe101de8bdceabc4c7080e`

Foi executado o Cosign verify sobre o novo digest, utilizando a mesma identidade e o mesmo emissor da imagem original.

Resultado:

`Error: no signatures found`

O resultado foi esperado: a imagem alterada possui um digest diferente e não possui uma assinatura correspondente.

O teste demonstrou que a assinatura da imagem original não pode ser reutilizada para validar uma imagem com conteúdo diferente.

## 4. Se o sistema fosse atacado amanhã, que evidências eu teria para provar o que aconteceu?

A implementação fornece diferentes fontes de evidência para uma investigação de incidente.

| Evidência | O que permite demonstrar |
|---|---|
| Histórico do Git | Quais alterações foram realizadas, em quais commits e branches. |
| Digest da imagem | Identificação exata do conteúdo de uma imagem publicada. |
| Assinatura Cosign | Se uma imagem possui assinatura criptográfica correspondente. |
| Certificado Sigstore | Identidade e emissor OIDC utilizados na assinatura. |
| Log de transparência Rekor | Registro público da assinatura e seus dados de inclusão. |
| SBOM do Syft | Quais componentes e versões estavam presentes na imagem. |
| Relatórios Trivy | Vulnerabilidades identificadas durante as análises. |
| Resultado do Conftest | Se os manifests atendiam às políticas de segurança no momento do teste. |
| Logs do Docker e da aplicação | Informações sobre execução, erros e comportamento observado, quando os logs são preservados. |
| Histórico do GHCR | Informações disponíveis sobre publicação e versões das imagens. |

### Exemplo de investigação

Imagine que amanhã alguém publique uma imagem modificada no GHCR.

A investigação poderia seguir esta sequência:

1. Identificar o digest da imagem suspeita.
2. Consultar o histórico do repositório para localizar alterações recentes.
3. Verificar a assinatura da imagem suspeita com Cosign.
4. Comparar seu digest com o digest da versão aprovada.
5. Consultar o registro Rekor para verificar as assinaturas e seus respectivos registros.
6. Comparar a SBOM da imagem suspeita com a SBOM da versão original.
7. Consultar os relatórios Trivy para identificar vulnerabilidades conhecidas.
8. Analisar os logs de execução e de publicação disponíveis.

Com essas informações seria possível construir uma linha do tempo do incidente e identificar diferenças entre a versão aprovada e a versão suspeita.

**Limitação importante:** essas evidências ajudam a demonstrar o que foi assinado, publicado, analisado ou registrado. Entretanto, não garantem, isoladamente, a identificação de quem realizou um ataque ou de todos os acontecimentos. Para isso, é necessário preservar logs de auditoria, registros de acesso, timestamps e informações do ambiente.

## 5. Onde um atacante entraria e qual controle do curso bloqueia ou evidencia isso?

Os principais pontos de exposição de uma aplicação como esta estão relacionados às dependências, ao processo de construção, à configuração dos containers e à distribuição das imagens.

**1. Dependências vulneráveis**

Um atacante poderia tentar explorar uma vulnerabilidade presente em uma biblioteca utilizada pela aplicação.

Controle: Trivy e Syft.

O Trivy identifica vulnerabilidades conhecidas nas dependências, enquanto o Syft gera a SBOM para documentar os componentes utilizados. Esses controles ajudam a identificar e investigar riscos, mas não bloqueiam automaticamente toda exploração.

**2. Processo de construção da imagem**

Uma imagem poderia ser construída com dependências inadequadas, configurações inseguras ou componentes não aprovados.

Controle: análise de vulnerabilidades, Dockerfile seguro e SBOM.

Esses mecanismos ajudam a identificar os componentes utilizados e os riscos presentes na imagem.

**3. Configuração insegura do container**

Um invasor que consiga explorar a aplicação poderá tentar utilizar os privilégios do processo ou acessar o sistema de arquivos do container.

Controle: Policy as Code com Conftest e configurações de segurança do Docker/Kubernetes.

A política exige execução sem root, proíbe modo privilegiado, desabilita a escalada de privilégios e exige sistema de arquivos raiz somente leitura.

**4. Publicação de uma imagem adulterada**

Alguém poderia tentar substituir a imagem legítima por outra contendo código modificado.

Controle: assinatura e verificação com Cosign.

O Cosign permite verificar se existe uma assinatura correspondente ao digest da imagem e se ela foi emitida pela identidade esperada. Uma imagem sem assinatura correspondente é rejeitada pela verificação.

**5. Alterações não autorizadas no código**

Um atacante poderia tentar inserir alterações maliciosas no repositório.

Controle: Git e histórico de commits.

O histórico permite identificar alterações registradas, seus autores declarados e a evolução do código. Para fortalecer esse controle, podem ser adicionadas regras de proteção de branches, revisão obrigatória de código e auditoria de acesso.

Em conjunto, esses controles ajudam a reduzir a superfície de ataque, identificar alterações suspeitas e preservar evidências para uma investigação.

## 6. Conclusão

O laboratório demonstrou a aplicação prática de controles de segurança ao longo da cadeia de suprimentos de software.

Foram implementados mecanismos de análise de vulnerabilidades, geração de SBOM, validação de políticas de segurança, execução de containers com privilégios reduzidos, publicação de imagens e assinatura digital.

O teste final de adulteração demonstrou que uma imagem com conteúdo diferente não pode utilizar a assinatura da imagem original para passar na verificação do Cosign.

Dessa forma, o projeto apresenta mecanismos complementares de prevenção, detecção, verificação de integridade e produção de evidências.

**Pendência identificada:** as vulnerabilidades encontradas em dependências herdadas da imagem-base Node.js devem continuar sendo acompanhadas e tratadas em uma atualização posterior da imagem-base, seguida de nova construção e análise.

## 7. Principais artefatos do projeto

| Caminho | Finalidade |
|---|---|
| `Dockerfile` | Definição da construção segura da imagem. |
| `policies/main.rego` | Regras de segurança para os manifests. |
| `manifests/deployement.yaml` | Manifesto Kubernetes validado. |
| `sbom/` | Inventários de componentes gerados pelo Syft. |
| `reports/` | Relatórios de vulnerabilidades do Trivy. |
| `app/src/server.js` | Código-fonte da aplicação. |

Repositório: https://github.com/CaioVRS21/desafio-devsecops02
