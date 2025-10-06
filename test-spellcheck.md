# Test Spellcheck Document

This document contains intentional spelling errors to test the spellcheck GitHub Action on **Markdown files**.

## Spelling Errors Section

1. This is a **simpel** example of a spelling mistake.
2. The quickstart should be **publiched** on the redhat website.
3. We need to **recomend** this for **publcation**.
4. The **doccumentation** needs to be **reviewd** by the team.
5. This **occured** during the **seperate** testing phase.
6. The **enviroment** was not configured **corectly**.
7. We need to **acheive** better **performence** metrics.
8. The **recieve** function has a **wierd** implementation.
9. Please **definately** check the **refference** guide.
10. The **acessibility** features are **necesary** for compliance.

## More Common Misspellings

- The **begining** of the process was **sucessful**.
- We need to **accomodate** the new **requirments**.
- This is a **seperete** issue from the **orignal** problem.
- The **committe** will **recieve** the **recomendation**.
- Please **maintian** the **consistancy** across all files.
- The **occurance** was **truely** unexpected.
- We are **greatful** for your **assistence**.
- This **dependancy** causes **performence** issues.

## Correctly Spelled Technical Terms

These should **NOT** be flagged because they're in the wordlist:

- quickstart and quickstarts
- redhat
- OpenShift
- README
- Github and github
- repo and repos
- MIST
- checkboxes and checkbox
- yaml and yml
- metadata
- CODEOWNERS
- AI

## Code Block Test

Code blocks should be ignored by spellcheck:

```yaml
# Even with speling erors here, they should be ignored
name: "Tset Workflow"
descripion: "This has mispellings but is in a code block"
```

## Summary

This file has **approximatley 30+ intentional spelling errors** that should be detected by the spellcheck action. The technical terms listed above should be ignored becuase they are in the custom wordlist at `.wordlist.txt`.

The spellcheck action should parse the **Markdown format** correctly and ignore content inside code blocks while catching all the mispellings in regular text.
