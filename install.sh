TARGET_PATH="/usr/local/bin"
SOURCE_PATH=$(dirname "$0")

CMD="cp $SOURCE_PATH/aapk.sh $TARGET_PATH/aapk"
echo -e "Running \e[32m\"$CMD\"\e[0m"

$CMD || exit 1

CMD="chmod +x $TARGET_PATH/aapk"
echo -e "Running \e[32m\"$CMD\"\e[0m"

$CMD && echo "Successfully installed!"
