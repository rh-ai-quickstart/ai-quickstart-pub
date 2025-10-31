# ai-quickstart-pub

:loudspeaker: This repository **is not** a quickstart! 

This repository is used for quickstart publication and staging. 


## How to stage a quickstart for publication 

Minimal instructions (to be expanded on as needed): 
1. **Gitflow workflow:** branch from main, something like 
```bash 
git checkout -b init-my-quickstart  
```

2. git submodule add (points to latest commit on main branch)
```bash
git submodule add https://github.com/rh-ai-quickstart/my-quickstart.git quickstart/my-quickstart
```

3. commit changes 
4. push changes 
```bash 
git push -u origin init-my-quickstart
```

5. open pull request to main 
6. PRs will be reviewed and merged by the `publication-admin` team

## How to update a published quickstart

*best practices coming soon*
