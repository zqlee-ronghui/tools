#! /bin/bash
function relay()
{
  init_dir=$(cd "$(dirname "$0")"; pwd) 
  repo=$(basename $1 .git)
  if [ ! -d "./$repo" ]; then
    echo "fetching all branches from $1..."
    git clone $1
    cd $repo
  else
    echo "$1 is already exist."
    cd $repo
  fi
  remote_branches=`git branch -r | grep -v '\->'`;
  for remote_branch in ${remote_branches[*]}; do
    if [[ "$remote_branch" =~ ^origin/.* ]]; then
      git branch --track "${remote_branch#origin/}" "$remote_branch"
    fi
  done
  git fetch --all
  git pull --all

  echo "pushing repo to $2..."
  git remote add gitlab $2
  git push -u gitlab --all
  git push -u gitlab --tags
  cd $init_dir
}

list=`cat config.json | jq '.repos'`;
length=`cat config.json | jq '.repos|length'`;
for((i=0; i<$length; i++)); do
  github_addr=`echo $list | jq ".[$i].github" | sed 's/\"//g'`;
  gitlab_addr=`echo $list | jq ".[$i].gitlab" | sed 's/\"//g'`;
  relay $github_addr $gitlab_addr
done
