
#!/bin/sh

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

BLOG_PUB_TEMP="$HOME/tmp/blog"

if [ "`git status -s`" ]
then
    echo "${YELLOW}The working directory is dirty. Please commit any pending changes.${NC}"
    exit 1;
fi

cd src

echo "${GREEN}Creating temp folders${NC}"
rm -rf "$BLOG_PUB_TEMP"
mkdir -p "$BLOG_PUB_TEMP"

echo "${GREEN}Removing existing files in the public folder${NC}"
rm -rf public/*

echo "${GREEN}Generating site${NC}"
hugo

echo "${GREEN}Moving generate site to temp folder${NC}"
# shopt -s dotglob
mv public/* "$BLOG_PUB_TEMP"

cd ..

echo "${GREEN}Moving to gh-pages branch${NC}"
git submodule deinit . && git checkout gh-pages

echo "${GREEN}Removing any non tracked file in the gh-pages branch${NC}"
git clean -fd

echo "${GREEN}Copying newly generated site${NC}"
cp -a "$BLOG_PUB_TEMP/." .

while true; do
    echo "${YELLOW}Do you want to commit the changes (y/n)${NC}"
    read -r yn
    case $yn in
        [Yy]* )
        echo "Enter commit message"
        read cmessage
        git add --all && git commit -m "${cmessage}"
        break;;
        [Nn]* ) echo "${YELLOW}Changes are still pending on the gh-pages branch${NC}"; exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

while true; do
    echo "${YELLOW}Do you want to push the changes (this will publish the site automatically) (y/n)${NC}"
    read -r yn
    case $yn in
        [Yy]* )        
        # git push
        echo "${YELLOW}Going back to 'main' branch (removing untracked changes)${NC}"
        git checkout main && git submodule update --init --recursive
        git clean -fd        
        break;;
        [Nn]* ) echo "${YELLOW}Push the changes later or reset the branch!${NC}"; exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
