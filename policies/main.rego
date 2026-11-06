package main

import rego.v1

deny contains msg if {
    input.kind == "Deployment"
    some container in input.spec.template.spec.containers
    container.securityContext.runAsNonRoot != true

    msg := sprintf(
        "Container '%s' deve executar como usuario nao root (runAsNonRoot: true).",
        [container.name]
    )
}

deny contains msg if {
    input.kind == "Deployment"
    some container in input.spec.template.spec.containers
    container.securityContext.privileged == true

    msg := sprintf(
        "Container '%s' nao pode executar em modo privilegiado (privileged: false).",
        [container.name]
    )
}

deny contains msg if {
    input.kind == "Deployment"
    some container in input.spec.template.spec.containers
    container.securityContext.allowPrivilegeEscalation != false

    msg := sprintf(
        "Container '%s' deve desabilitar a escalacao de privilegios (allowPrivilegeEscalation: false).",
        [container.name]
    )
}

deny contains msg if {
    input.kind == "Deployment"
    some container in input.spec.template.spec.containers
    container.securityContext.readOnlyRootFilesystem != true

    msg := sprintf(
        "Container '%s' deve utilizar sistema de arquivos raiz somente leitura (readOnlyRootFilesystem: true).",
        [container.name]
    )
}
