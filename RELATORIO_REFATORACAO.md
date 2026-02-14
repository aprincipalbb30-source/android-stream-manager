# Relatório de Refatoração - Android Stream Manager

Este documento detalha as principais correções e melhorias realizadas no projeto para garantir sua funcionalidade e estabilidade.

## 1. Correções de Build e Dependências

O projeto apresentava diversos problemas de compilação devido a dependências ausentes e caminhos de inclusão incorretos.

| Problema | Solução |
| :--- | :--- |
| **Dependências do Sistema** | Instaladas bibliotecas essenciais: `libssl-dev`, `liblz4-dev`, `libzip-dev`, `nlohmann-json3-dev`, `libsqlite3-dev`. |
| **uWebSockets/uSockets** | O CMake não conseguia encontrar os alvos. Foram definidos alvos manuais no `CMakeLists.txt` compilando diretamente os fontes do `FetchContent`. |
| **Suporte à Linguagem C** | O uSockets utiliza arquivos `.c`. O projeto foi atualizado para suportar `LANGUAGES C CXX`. |
| **Caminhos de Inclusão** | Corrigidos cabeçalhos que referenciavam diretórios de forma absoluta ou incorreta (ex: `security/apk_signer.h` em vez de `./security/apk_signer.h`). |

## 2. Refatoração de Código C++

### `ApkBuilder` e `builder/main.cpp`
- **Inconsistência de Nomes**: O `main.cpp` tentava usar uma classe inexistente `ApkGenerator`. Foi refatorado para usar a classe correta `ApkBuilder`.
- **Funções Utilitárias**: Funções como `readFile` e `writeFile` estavam declaradas mas não implementadas ou fora de escopo. Foram movidas para dentro do namespace `AndroidStreamManager` como funções estáticas internas.
- **Implementação de Métodos**: O método `signApk` estava apenas declarado. Foi adicionada uma implementação base que simula a assinatura, permitindo que o fluxo de build continue.

### `StreamServer` e `HttpServer`
- **Estabilidade**: Corrigidos problemas de linkagem com as bibliotecas de rede.
- **Protocolo**: Garantida a consistência entre as estruturas `ControlMessage` e `StreamData` em todo o sistema.

## 3. Estrutura do Projeto

A estrutura foi mantida, mas a lógica de build foi centralizada no CMake para facilitar a portabilidade:

- `core/`: Lógica central de gerenciamento de dispositivos e build.
- `server/`: Servidor WebSocket e HTTP para comunicação em tempo real.
- `shared/`: Definições de protocolo e configurações compartilhadas.
- `builder/`: Ferramenta de linha de comando para geração de APKs.

## 4. Como Executar

### Compilação
```bash
mkdir build && cd build
cmake .. -DBUILD_DASHBOARD=OFF
make -j$(nproc)
```

### Iniciar o Servidor
```bash
./bin/stream_server --port 8443
```

### Gerar um APK
```bash
./bin/apk_builder --app-name "Meu App" --pkg-name "com.exemplo.app" --server-url "http://meu-servidor.com"
```

## 5. Próximos Passos Sugeridos
1. **Integração Real do SDK Android**: Configurar o `ANDROID_SDK_ROOT` para que o Gradle possa compilar APKs reais.
2. **Dashboard Qt**: Instalar as dependências completas do Qt6 para habilitar a interface gráfica.
3. **Segurança**: Implementar a validação real de certificados TLS 1.3 no `TlsManager`.
