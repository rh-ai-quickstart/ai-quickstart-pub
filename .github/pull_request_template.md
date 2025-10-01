name: "Pull Request Template"
description: "Checklist for contributors when submitting quickstart publication requests"
assignees:
  - @publication-admin
body:
  - type: markdown
    id: summary
    attributes:
      value: |
        ## Publication request summary

        Thank you for suggesting a quickstart for publication on redhat(dot)com!

        Please complete the fields below and leave checkboxes unchecked.
  - type: textarea
    id: details
    attributes:
      label: Publication suggestion details
      description: Briefly describe why this quickstart should be prioritized for publication
      placeholder: "Explain the quickstart's purpose, industry, target audience, impact and why it's needed."
    validations:
      required: true
  - type: checkboxes
    id: readiness
    attributes:
      label: Publication readiness checklist
      options:
        - label: README is clear, concise, and free of typos
        - label: README is accurate and includes vertical use case
        - label: README is complete and follows template structure
        - label: Quickstart runs end-to-end without errors and is reproducible
        - label: Titles, descriptions, and tags adhere to MIST guidelines
        - label: Insert redhat(dot)com requirements here
        - label: Technical review complete
        - label: Peer review complete
        - label: Known issues and requests are documented (or resolved)
